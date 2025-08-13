local M = {}

---Show diagnostic information about opencode detection
function M.show_diagnostics()
  local detection = require("opencode.server_detection")
  local utils = require("opencode.utils")
  local diagnostics = detection.get_diagnostics()
  
  local lines = {
    "=== Opencode Detection Diagnostics ===",
    "",
    "System Information:",
    "  Operating System: " .. diagnostics.os,
    "  Neovim CWD: " .. utils.sanitize_path(vim.fn.getcwd()),
    "",
    "Environment Variables:",
    "  OPENCODE_PORT: " .. (os.getenv("OPENCODE_PORT") or "not set"),
    "  OPENCODE_DEBUG: " .. (os.getenv("OPENCODE_DEBUG") or "not set"),
    "",
    "Cache Status:",
    "  Cached Port: " .. (diagnostics.cached_port or "none"),
    "  Cache Valid: " .. tostring(diagnostics.cache_valid),
    "",
    "Available Commands:",
  }
  
  for cmd, available in pairs(diagnostics.available_commands) do
    table.insert(lines, "  " .. cmd .. ": " .. (available and "✓" or "✗"))
  end
  
  if diagnostics.proc_available ~= nil then
    table.insert(lines, "")
    table.insert(lines, "Linux-specific:")
    table.insert(lines, "  /proc filesystem: " .. (diagnostics.proc_available and "✓" or "✗"))
  end
  
  table.insert(lines, "")
  table.insert(lines, "═══════════════════════════════════════")
  table.insert(lines, "Attempting port detection...")
  table.insert(lines, "")
  
  -- Track detection attempts
  local attempts = {}
  local found_processes = {}
  
  -- Try actual detection with verbose logging
  local port, error_msg = M.detect_with_logging(attempts, found_processes)
  
  -- Show detection attempts
  if #attempts > 0 then
    table.insert(lines, "Detection Methods Tried:")
    for _, attempt in ipairs(attempts) do
      table.insert(lines, "  " .. attempt)
    end
    table.insert(lines, "")
  end
  
  -- Show found processes
  if #found_processes > 0 then
    table.insert(lines, "Opencode Processes Found:")
    for _, proc in ipairs(found_processes) do
      table.insert(lines, "  " .. proc)
    end
    table.insert(lines, "")
  end
  
  -- Show result
  if port then
    table.insert(lines, "✓ SUCCESS: Found opencode on port " .. port)
    
    -- Try to verify it's actually opencode
    local handle = io.popen("curl -s -m 0.5 http://localhost:" .. port .. "/session 2>/dev/null | head -c 50")
    if handle then
      local response = handle:read("*a")
      handle:close()
      if response and response:match("ses_") then
        table.insert(lines, "✓ Verified: Opencode API is responding")
      else
        table.insert(lines, "⚠ Warning: Port is open but API verification failed")
      end
    end
  else
    table.insert(lines, "✗ FAILED: " .. (error_msg or "Could not find opencode server"))
    table.insert(lines, "")
    table.insert(lines, "═══════════════════════════════════════")
    table.insert(lines, "Troubleshooting Options:")
    table.insert(lines, "")
    table.insert(lines, "1. Set environment variable:")
    table.insert(lines, "   export OPENCODE_PORT=<port>")
    table.insert(lines, "   # Then restart Neovim")
    table.insert(lines, "")
    table.insert(lines, "2. Configure in Neovim setup:")
    table.insert(lines, "   require('opencode').setup({")
    table.insert(lines, "     port = <port>")
    table.insert(lines, "   })")
    table.insert(lines, "")
    table.insert(lines, "3. Find opencode manually:")
    table.insert(lines, "   # List opencode processes:")
    table.insert(lines, "   ps aux | grep opencode")
    table.insert(lines, "   ")
    table.insert(lines, "   # Find listening ports:")
    if diagnostics.os == "Linux" then
      table.insert(lines, "   ss -tlnp | grep opencode")
      table.insert(lines, "   # or")
      table.insert(lines, "   lsof -i -P | grep LISTEN | grep opencode")
    else
      table.insert(lines, "   lsof -i -P | grep LISTEN | grep opencode")
    end
    table.insert(lines, "")
    table.insert(lines, "4. Enable debug logging:")
    table.insert(lines, "   export OPENCODE_DEBUG=1")
    table.insert(lines, "   # Then restart Neovim and try again")
  end
  
  table.insert(lines, "")
  table.insert(lines, "═══════════════════════════════════════")
  table.insert(lines, "Press any key to close...")
  
  -- Create a floating window to display diagnostics
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  
  local width = 70
  local height = math.min(#lines, vim.o.lines - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
    title = ' Opencode Detection ',
    title_pos = 'center',
  })
  
  -- Close on any key press
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':close<CR>', { noremap = true, silent = true })
end

---Detect port with verbose logging
---@param attempts table Array to store attempt descriptions
---@param found_processes table Array to store found process info
---@return number|nil port
---@return string|nil error_msg
function M.detect_with_logging(attempts, found_processes)
  local utils = require("opencode.utils")
  
  -- Check environment variable first
  local env_port = utils.get_env_port()
  if env_port then
    table.insert(attempts, "✓ Environment variable OPENCODE_PORT=" .. env_port)
    local handle = io.popen("curl -s -m 0.2 http://localhost:" .. env_port .. "/session 2>/dev/null | head -c 10")
    if handle then
      local response = handle:read("*a")
      handle:close()
      if response and response:match("ses_") then
        return env_port
      else
        table.insert(attempts, "✗ Port " .. env_port .. " not responding as opencode")
      end
    end
  end
  
  -- Try to find opencode processes
  local ps_handle = io.popen("ps aux 2>/dev/null | grep -E '[o]pencode'")
  if ps_handle then
    for line in ps_handle:lines() do
      local pid = line:match("^%S+%s+(%d+)")
      if pid then
        -- Try to get more info about this process
        local cwd_handle = io.popen("lsof -a -p " .. pid .. " -d cwd 2>/dev/null | tail -1 | awk '{print $NF}'")
        local cwd = nil
        if cwd_handle then
          cwd = cwd_handle:read("*a"):match("^%s*(.-)%s*$")
          cwd_handle:close()
        end
        
        local port_handle = io.popen("lsof -P -p " .. pid .. " 2>/dev/null | grep LISTEN | grep TCP | awk '{print $9}' | cut -d: -f2")
        local port = nil
        if port_handle then
          local port_str = port_handle:read("*a"):match("^%s*(.-)%s*$")
          port = tonumber(port_str)
          port_handle:close()
        end
        
        table.insert(found_processes, utils.format_process_info(tonumber(pid), port, cwd))
      end
    end
    ps_handle:close()
  end
  
  -- Try standard detection
  local detection = require("opencode.server_detection")
  return detection.find_port()
end

---Interactive detection wizard
function M.detection_wizard()
  local utils = require("opencode.utils")
  
  -- Step 1: Show current status
  vim.notify("Starting Opencode Detection Wizard...", vim.log.levels.INFO)
  
  -- Check for running opencode processes
  local processes = {}
  local ps_handle = io.popen("ps aux 2>/dev/null | grep -E '[o]pencode'")
  if ps_handle then
    for line in ps_handle:lines() do
      local pid = line:match("^%S+%s+(%d+)")
      if pid then
        table.insert(processes, {pid = tonumber(pid), line = line})
      end
    end
    ps_handle:close()
  end
  
  if #processes == 0 then
    vim.notify("No opencode processes found. Please start opencode first.", vim.log.levels.WARN)
    return
  end
  
  -- Step 2: Let user select a process if multiple found
  if #processes == 1 then
    local pid = processes[1].pid
    M.try_process(pid)
  else
    local choices = {}
    for i, proc in ipairs(processes) do
      table.insert(choices, i .. ". PID " .. proc.pid .. ": " .. proc.line:sub(1, 60))
    end
    
    vim.ui.select(choices, {
      prompt = "Multiple opencode processes found. Select one:",
    }, function(choice, idx)
      if choice then
        M.try_process(processes[idx].pid)
      end
    end)
  end
end

---Try to use a specific process
---@param pid number
function M.try_process(pid)
  local utils = require("opencode.utils")
  
  -- Try to get port for this PID
  local port_handle = io.popen("lsof -P -p " .. pid .. " 2>/dev/null | grep LISTEN | grep TCP | awk '{print $9}' | cut -d: -f2")
  local port = nil
  if port_handle then
    local port_str = port_handle:read("*a"):match("^%s*(.-)%s*$")
    port = tonumber(port_str)
    port_handle:close()
  end
  
  if not port then
    vim.notify("Could not find port for PID " .. pid, vim.log.levels.ERROR)
    vim.notify("Try running: lsof -P -p " .. pid .. " | grep LISTEN", vim.log.levels.INFO)
    return
  end
  
  -- Verify it's opencode
  local handle = io.popen("curl -s -m 0.5 http://localhost:" .. port .. "/session 2>/dev/null | head -c 50")
  if handle then
    local response = handle:read("*a")
    handle:close()
    if response and response:match("ses_") then
      vim.notify("✓ Found opencode on port " .. port, vim.log.levels.INFO)
      vim.notify("To make this permanent, add to your shell config:", vim.log.levels.INFO)
      vim.notify("export OPENCODE_PORT=" .. port, vim.log.levels.INFO)
    else
      vim.notify("Port " .. port .. " is not responding as opencode", vim.log.levels.ERROR)
    end
  end
end

return M