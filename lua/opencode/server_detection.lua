local M = {}

-- Cache for successful port discovery
local cached_port = nil
local cache_timestamp = nil
local CACHE_TIMEOUT = 60 -- seconds

---Get OS name
---@return string
local function get_os()
  return vim.loop.os_uname().sysname
end

---Execute command and return output
---@param command string
---@return string|nil
local function exec(command)
  local handle = io.popen(command .. " 2>/dev/null")
  if not handle then
    return nil
  end
  local output = handle:read("*a")
  handle:close()
  return output
end

---Check if cached port is still valid
---@return boolean
local function is_cache_valid()
  if not cached_port or not cache_timestamp then
    return false
  end
  return (os.time() - cache_timestamp) < CACHE_TIMEOUT
end

-- =============================================================================
-- Linux-specific detection methods
-- =============================================================================

---Find opencode processes using /proc filesystem (Linux only)
---@return table<number> Array of PIDs
local function linux_find_pids_via_proc()
  local pids = {}
  local proc_dir = io.popen("ls -1 /proc 2>/dev/null | grep -E '^[0-9]+$'")
  if not proc_dir then
    return pids
  end
  
  for pid_str in proc_dir:lines() do
    local pid = tonumber(pid_str)
    if pid then
      local cmdline_file = io.open("/proc/" .. pid .. "/cmdline", "r")
      if cmdline_file then
        local cmdline = cmdline_file:read("*a")
        cmdline_file:close()
        -- Check if this is an opencode process
        if cmdline and cmdline:match("opencode") then
          table.insert(pids, pid)
        end
      end
    end
  end
  proc_dir:close()
  return pids
end

---Get port from PID using /proc/net/tcp (Linux only)
---@param pid number
---@return number|nil
local function linux_get_port_from_proc(pid)
  -- First, find socket inodes for this process
  local fd_dir = io.popen("ls -l /proc/" .. pid .. "/fd/ 2>/dev/null | grep socket")
  if not fd_dir then
    return nil
  end
  
  local inodes = {}
  for line in fd_dir:lines() do
    local inode = line:match("socket:%[(%d+)%]")
    if inode then
      table.insert(inodes, inode)
    end
  end
  fd_dir:close()
  
  if #inodes == 0 then
    return nil
  end
  
  -- Read /proc/net/tcp to find listening ports
  local tcp_file = io.open("/proc/net/tcp", "r")
  if not tcp_file then
    return nil
  end
  
  for line in tcp_file:lines() do
    -- Check if this line contains one of our inodes
    for _, inode in ipairs(inodes) do
      if line:match("%s" .. inode .. "%s") then
        -- Extract local address and port (in hex)
        local local_addr = line:match("%s+%d+:%s+(%x+:%x+)%s+%x+:%x+%s+(%x+)")
        if local_addr then
          local port_hex = local_addr:match(":(%x+)$")
          if port_hex then
            local port = tonumber(port_hex, 16)
            -- Check if it's a listening socket (state 0A = LISTEN)
            if line:match("%s+0A%s") and port then
              tcp_file:close()
              return port
            end
          end
        end
      end
    end
  end
  tcp_file:close()
  return nil
end

---Get CWD from PID using /proc (Linux only)
---@param pid number
---@return string|nil
local function linux_get_cwd_from_proc(pid)
  local cwd_link = "/proc/" .. pid .. "/cwd"
  local output = exec("readlink " .. cwd_link)
  if output then
    return output:match("^%s*(.-)%s*$") -- trim
  end
  return nil
end

---Find port using ss command (Linux)
---@return number|nil
local function linux_find_port_via_ss()
  local output = exec("ss -tlnp 2>/dev/null | grep opencode")
  if not output or output == "" then
    return nil
  end
  
  -- Parse output like: LISTEN 0 512 127.0.0.1:37669 0.0.0.0:*
  local port = output:match(":(%d+)%s")
  return tonumber(port)
end

---Find port using netstat (Linux version)
---@return number|nil
local function linux_find_port_via_netstat()
  local output = exec("netstat -tlnp 2>/dev/null | grep opencode")
  if not output or output == "" then
    return nil
  end
  
  -- Parse output like: tcp 0 0 127.0.0.1:37669 0.0.0.0:* LISTEN 832064/opencode
  local port = output:match(":(%d+)%s")
  return tonumber(port)
end

-- =============================================================================
-- macOS-specific detection methods
-- =============================================================================

---Find opencode PIDs on macOS
---@return table<number>
local function macos_find_pids()
  local output = exec("ps -ax -o pid,comm | grep -E '[o]pencode' | awk '{print $1}'")
  if not output then
    return {}
  end
  
  local pids = {}
  for pid_str in output:gmatch("[^\r\n]+") do
    local pid = tonumber(pid_str:match("^%s*(.-)%s*$"))
    if pid then
      table.insert(pids, pid)
    end
  end
  return pids
end

---Get port using lsof on macOS
---@param pid number
---@return number|nil
local function macos_get_port_via_lsof(pid)
  local output = exec("lsof -P -p " .. pid .. " | grep LISTEN | grep TCP | awk '{print $9}' | cut -d: -f2")
  if output then
    local port = output:match("^%s*(.-)%s*$")
    return tonumber(port)
  end
  return nil
end

---Get CWD using lsof on macOS
---@param pid number
---@return string|nil
local function macos_get_cwd_via_lsof(pid)
  local output = exec("lsof -a -p " .. pid .. " -d cwd | tail -1 | awk '{print $NF}'")
  if output then
    return output:match("^%s*(.-)%s*$")
  end
  return nil
end

---Find port using netstat on macOS
---@return number|nil
local function macos_find_port_via_netstat()
  -- Note: macOS netstat doesn't show process names without sudo
  -- This is a fallback that finds listening ports and then tries to match with opencode
  local output = exec("netstat -anp tcp | grep LISTEN")
  if not output then
    return nil
  end
  
  -- We'd need to cross-reference with process list
  -- This is less reliable, so we primarily use lsof on macOS
  return nil
end

-- =============================================================================
-- Universal detection methods (work on all platforms)
-- =============================================================================

---Check if process is descendant of Neovim
---@param pid number
---@return boolean
local function is_descendant_of_neovim(pid)
  local neovim_pid = vim.fn.getpid()
  local current_pid = pid
  
  for _ = 1, 10 do -- limit iterations
    local output = exec("ps -o ppid= -p " .. current_pid)
    if not output then
      return false
    end
    local parent_pid = tonumber(output:match("^%s*(.-)%s*$"))
    if not parent_pid or parent_pid <= 1 then
      return false
    end
    if parent_pid == neovim_pid then
      return true
    end
    current_pid = parent_pid
  end
  
  return false
end

---Try to find port via HTTP probing
---@return number|nil
local function universal_http_probe()
  local utils = require("opencode.utils")
  local is_debug = utils.is_debug_mode()
  local common_ports = { 5173, 3000, 3001, 3002, 3003, 8080, 8081, 8082 }
  
  for _, port in ipairs(common_ports) do
    -- Try to connect to the /session endpoint
    if is_debug then
      vim.notify("[opencode]   Probing port " .. port .. "...", vim.log.levels.DEBUG)
    end
    local output = exec("curl -s -m 0.5 http://localhost:" .. port .. "/session 2>/dev/null | head -c 50")
    if output and output:match("ses_") then
      -- Looks like an opencode session response
      if is_debug then
        vim.notify("[opencode]   ✓ Port " .. port .. " is opencode", vim.log.levels.DEBUG)
      end
      return port
    end
  end
  
  return nil
end

---Generic lsof method (works on Linux and macOS)
---@return number|nil
local function universal_lsof_method()
  local utils = require("opencode.utils")
  local is_debug = utils.is_debug_mode()
  
  if vim.fn.executable("lsof") == 0 then
    if is_debug then
      vim.notify("[opencode]   lsof command not available", vim.log.levels.DEBUG)
    end
    return nil
  end
  
  -- Find all opencode processes
  local output = exec("ps -ax -o pid,comm 2>/dev/null | grep -E '[o]pencode' | awk '{print $1}'")
  if not output then
    if is_debug then
      vim.notify("[opencode]   No opencode processes found via ps", vim.log.levels.DEBUG)
    end
    return nil
  end
  
  local neovim_cwd = vim.fn.getcwd()
  local pids_found = 0
  
  for pid_str in output:gmatch("[^\r\n]+") do
    local pid = tonumber(pid_str:match("^%s*(.-)%s*$"))
    if pid then
      pids_found = pids_found + 1
      -- Get CWD of this process
      local cwd_output = exec("lsof -a -p " .. pid .. " -d cwd 2>/dev/null | tail -1 | awk '{print $NF}'")
      if cwd_output then
        local cwd = cwd_output:match("^%s*(.-)%s*$")
        if is_debug then
          vim.notify("[opencode]   PID " .. pid .. " CWD: " .. utils.sanitize_path(cwd or "unknown"), vim.log.levels.DEBUG)
        end
        -- Check if CWD matches or is under Neovim's CWD
        if cwd and cwd:find(neovim_cwd, 1, true) == 1 then
          if is_debug then
            vim.notify("[opencode]   PID " .. pid .. " matches Neovim CWD, checking port...", vim.log.levels.DEBUG)
          end
          -- Get port
          local port_output = exec("lsof -P -p " .. pid .. " 2>/dev/null | grep LISTEN | grep TCP | awk '{print $9}' | cut -d: -f2")
          if port_output then
            local port = tonumber(port_output:match("^%s*(.-)%s*$"))
            if port then
              if is_debug then
                vim.notify("[opencode]   ✓ Found port " .. port .. " for PID " .. pid, vim.log.levels.DEBUG)
              end
              return port
            end
          end
        end
      end
    end
  end
  
  if is_debug and pids_found > 0 then
    vim.notify("[opencode]   Checked " .. pids_found .. " opencode process(es), none matched criteria", vim.log.levels.DEBUG)
  end
  
  return nil
end

-- =============================================================================
-- Main detection logic with OS branching
-- =============================================================================

---Find opencode port with OS-specific branching
---@return number|nil port
---@return string|nil error_message
function M.find_port()
  local utils = require("opencode.utils")
  local is_debug = utils.is_debug_mode()
  
  local function debug_log(msg)
    if is_debug then
      vim.notify("[opencode] " .. msg, vim.log.levels.DEBUG)
    end
  end
  
  debug_log("Starting port detection...")
  
  -- Check for manual override via environment variable
  local env_port = utils.get_env_port()
  if env_port then
    debug_log("Found OPENCODE_PORT=" .. env_port .. ", verifying...")
    -- Verify it's actually opencode
    local output = exec("curl -s -m 0.2 http://localhost:" .. env_port .. "/session 2>/dev/null | head -c 10")
    if output and output:match("ses_") then
      debug_log("✓ Environment port " .. env_port .. " verified as opencode")
      return env_port
    else
      debug_log("✗ Environment port " .. env_port .. " not responding as opencode")
      return nil, "OPENCODE_PORT=" .. env_port .. " specified but opencode not responding on that port"
    end
  end
  
  -- Check cache first
  if is_cache_valid() then
    debug_log("Checking cached port " .. cached_port .. "...")
    -- Verify the cached port is still valid
    local output = exec("curl -s -m 0.2 http://localhost:" .. cached_port .. "/session 2>/dev/null | head -c 10")
    if output and output ~= "" then
      debug_log("✓ Cached port " .. cached_port .. " still valid")
      return cached_port
    else
      debug_log("✗ Cached port " .. cached_port .. " no longer valid")
      -- Cache is stale
      cached_port = nil
      cache_timestamp = nil
    end
  end
  
  local os_name = get_os()
  debug_log("Operating system: " .. os_name)
  local port = nil
  local methods_tried = {}
  
  if os_name == "Linux" then
    debug_log("Using Linux-specific detection methods")
    -- Linux detection chain
    -- Try /proc filesystem first (no external deps)
    debug_log("Trying /proc filesystem...")
    local pids = linux_find_pids_via_proc()
    debug_log("Found " .. #pids .. " opencode process(es) via /proc")
    table.insert(methods_tried, "/proc filesystem")
    
    local neovim_cwd = vim.fn.getcwd()
    for _, pid in ipairs(pids) do
      local cwd = linux_get_cwd_from_proc(pid)
      debug_log("  PID " .. pid .. " CWD: " .. utils.sanitize_path(cwd or "unknown"))
      if cwd and cwd:find(neovim_cwd, 1, true) == 1 then
        debug_log("  PID " .. pid .. " matches Neovim CWD, checking port...")
        port = linux_get_port_from_proc(pid)
        if port then 
          debug_log("  ✓ Found port " .. port .. " for PID " .. pid)
          break 
        else
          debug_log("  ✗ Could not find port for PID " .. pid)
        end
      end
    end
    
    -- Try ss command
    if not port then
      debug_log("Trying ss command...")
      table.insert(methods_tried, "ss")
      port = linux_find_port_via_ss()
      if port then
        debug_log("✓ Found port " .. port .. " via ss")
      else
        debug_log("✗ ss command did not find opencode")
      end
    end
    
    -- Try netstat
    if not port then
      debug_log("Trying netstat command...")
      table.insert(methods_tried, "netstat")
      port = linux_find_port_via_netstat()
      if port then
        debug_log("✓ Found port " .. port .. " via netstat")
      else
        debug_log("✗ netstat command did not find opencode")
      end
    end
    
    -- Try lsof as fallback
    if not port then
      debug_log("Trying lsof command...")
      table.insert(methods_tried, "lsof")
      port = universal_lsof_method()
      if port then
        debug_log("✓ Found port " .. port .. " via lsof")
      else
        debug_log("✗ lsof command did not find opencode")
      end
    end
    
  elseif os_name == "Darwin" then
    debug_log("Using macOS-specific detection methods")
    -- macOS detection chain
    -- Try lsof first (most reliable on macOS)
    debug_log("Trying lsof command...")
    table.insert(methods_tried, "lsof")
    port = universal_lsof_method()
    if port then
      debug_log("✓ Found port " .. port .. " via lsof")
    else
      debug_log("✗ lsof command did not find opencode")
    end
    
    -- Try process-specific detection
    if not port then
      debug_log("Trying ps + lsof combination...")
      table.insert(methods_tried, "ps + lsof")
      local pids = macos_find_pids()
      debug_log("Found " .. #pids .. " opencode process(es) via ps")
      local neovim_cwd = vim.fn.getcwd()
      
      for _, pid in ipairs(pids) do
        local cwd = macos_get_cwd_via_lsof(pid)
        debug_log("  PID " .. pid .. " CWD: " .. utils.sanitize_path(cwd or "unknown"))
        if cwd and cwd:find(neovim_cwd, 1, true) == 1 then
          debug_log("  PID " .. pid .. " matches Neovim CWD, checking port...")
          port = macos_get_port_via_lsof(pid)
          if port then 
            debug_log("  ✓ Found port " .. port .. " for PID " .. pid)
            break 
          else
            debug_log("  ✗ Could not find port for PID " .. pid)
          end
        end
      end
    end
    
  elseif os_name:match("^Windows") or os_name:match("^MINGW") or os_name:match("^MSYS") then
    -- Windows detection
    debug_log("Windows detected - limited support available")
    table.insert(methods_tried, "Windows not fully supported")
    -- Could add Windows-specific methods here
    -- For now, fall through to HTTP probing
    
  else
    -- Unknown OS
    debug_log("Unknown operating system: " .. os_name)
    table.insert(methods_tried, "unknown OS: " .. os_name)
  end
  
  -- Universal fallback: HTTP probing
  if not port then
    debug_log("Trying HTTP probing on common ports...")
    table.insert(methods_tried, "HTTP probing")
    port = universal_http_probe()
    if port then
      debug_log("✓ Found opencode on port " .. port .. " via HTTP probing")
    else
      debug_log("✗ HTTP probing did not find opencode")
    end
  end
  
  if port then
    -- Cache the successful result
    cached_port = port
    cache_timestamp = os.time()
    debug_log("✓ SUCCESS: Port detection complete, found port " .. port)
    return port
  else
    local error_msg = string.format(
      "Could not find opencode server (OS: %s, tried: %s)",
      os_name,
      table.concat(methods_tried, ", ")
    )
    debug_log("✗ FAILED: " .. error_msg)
    return nil, error_msg
  end
end

---Clear the port cache
function M.clear_cache()
  cached_port = nil
  cache_timestamp = nil
end

---Get diagnostic information for debugging
---@return table
function M.get_diagnostics()
  local os_name = get_os()
  local diagnostics = {
    os = os_name,
    cached_port = cached_port,
    cache_valid = is_cache_valid(),
    available_commands = {},
  }
  
  -- Check which commands are available
  local commands = { "lsof", "ss", "netstat", "curl", "ps", "awk" }
  for _, cmd in ipairs(commands) do
    diagnostics.available_commands[cmd] = vim.fn.executable(cmd) == 1
  end
  
  -- Check /proc availability (Linux)
  if os_name == "Linux" then
    diagnostics.proc_available = vim.fn.isdirectory("/proc") == 1
  end
  
  return diagnostics
end

return M