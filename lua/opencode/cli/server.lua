local M = {}

---@class Server
---@field pid number
---@field port number
---@field cwd string

---Check if running on Windows
---@return boolean
local function is_windows()
  return vim.fn.has("win32") == 1
end

---@param command string
---@return string
local function exec(command)
  -- TODO: Use vim.fn.jobstart for async, and so I can capture stderr (to throw error instead of it writing to the buffer).
  -- (or even the newer `vim.system`? Could update client.lua too? Or maybe not because SSE is long-running.)
  local executable = vim.split(command, " ")[1]
  if vim.fn.executable(executable) == 0 then
    error("`" .. executable .. "` command is not available", 0)
  end

  local handle = io.popen(command)
  if not handle then
    error("Couldn't execute command: " .. command, 0)
  end

  local output = handle:read("*a")
  handle:close()
  return output
end

local function retrieveOpencodeProcessesUnix()
  -- On Unix, use lsof to find cwd of processes
  if vim.fn.executable("lsof") == 0 then
    -- lsof is a common utility to list open files and ports, but not always available by default.
    error(
      "`lsof` executable not found in `PATH` to auto-find `opencode` — please install it or set `vim.g.opencode_opts.port`",
      0
    )
  end

  -- Find PIDs by command line pattern (handles process names like 'bun', 'node', etc.)
  local pgrep_output = exec("pgrep -f 'opencode' 2>/dev/null || true")
  if pgrep_output == "" then
    error("No `opencode` processes", 0)
  end

  local servers = {}
  for pid_str in pgrep_output:gmatch("[^\r\n]+") do
    local pid = tonumber(pid_str)
    if pid then
      -- Get CWD once per PID
      local cwd = exec("lsof -w -a -p " .. pid .. " -d cwd 2>/dev/null || true"):match("%s+(/.*)$")

      if cwd then
        -- `-w` suppresses filesystem warnings (e.g. Docker FUSE)
        local lsof_output = exec("lsof -w -iTCP -sTCP:LISTEN -P -n -a -p " .. pid .. " 2>/dev/null || true")

        if lsof_output ~= "" then
          for line in lsof_output:gmatch("[^\r\n]+") do
            local parts = vim.split(line, "%s+")

            if parts[1] ~= "COMMAND" then -- Skip header
              local port = parts[9] and parts[9]:match(":(%d+)$") -- e.g. "127.0.0.1:12345" -> "12345"
              if port then
                port = tonumber(port)

                table.insert(servers, {
                  pid = pid,
                  port = port,
                  cwd = cwd,
                })
              end
            end
          end
        end
      end
    end
  end

  if #servers == 0 then
    error("No `opencode` processes with valid working directories found", 0)
  end

  return servers
end

---Find opencode servers running on Windows using PowerShell
---@return Server[]
local function retrieveOpencodeProcessesWin()
  local ps_script = [[
Get-Process -Name '*opencode*' -ErrorAction SilentlyContinue |
ForEach-Object {
  $ports = Get-NetTCPConnection -State Listen -OwningProcess $_.Id -ErrorAction SilentlyContinue
  if ($ports) {
    foreach ($port in $ports) {
      [PSCustomObject]@{pid=$_.Id; port=$port.LocalPort}
    }
  }
} | ConvertTo-Json -Compress
]]

  -- Execute PowerShell synchronously, but this doesn't hold up the UI since
  -- this gets called from a function that returns a promise.
  local ps_result = vim.system({ "powershell", "-NoProfile", "-Command", ps_script }):wait()

  if ps_result.code ~= 0 then
    error("PowerShell command failed with code: " .. ps_result.code, 0)
  end

  if not ps_result.stdout or ps_result.stdout == "" then
    error("No `opencode` processes found", 0)
  end

  -- The Powershell script should return the response as JSON to ease parsing.
  local ok, processes = pcall(vim.fn.json_decode, ps_result.stdout)
  if not ok then
    error("Failed to parse PowerShell output: " .. tostring(processes), 0)
  end

  if processes.pid then
    -- A single process was found, so wrap it in a table.
    processes = { processes }
  end

  if #processes == 0 then
    error("No `opencode` processes found", 0)
  end

  return processes
end

-- Find the working directories of running instances of opencode.
---@param processes {pid: number, port: number}[]
---@return Server table
local function populateWorkingDirectories(processes)
  local servers = {}

  if vim.fn.executable("curl") == 0 then
    error("`curl` executable not found in `PATH` to query `opencode` working directories", 0)
  end

  -- Query each port synchronously for working directory
  for _, proc in ipairs(processes) do
    local curl_result = vim
      .system({
        "curl",
        "-s",
        "--connect-timeout",
        "1",
        "http://localhost:" .. proc.port .. "/path",
      })
      :wait()

    local cwd = nil
    if curl_result.code == 0 and curl_result.stdout and curl_result.stdout ~= "" then
      local path_ok, path_data = pcall(vim.fn.json_decode, curl_result.stdout)
      if path_ok and (path_data.directory or path_data.worktree) then
        cwd = path_data.directory or path_data.worktree
      end
    end

    if cwd then
      table.insert(servers, {
        pid = proc.pid,
        port = proc.port,
        cwd = cwd,
      })
    end
  end

  if #servers == 0 then
    error("No `opencode` processes with valid working directories found", 0)
  end

  return servers
end

---@return Server[]
local function find_servers()
  if is_windows() then
    local processes = retrieveOpencodeProcessesWin()
    return populateWorkingDirectories(processes)
  else
    return retrieveOpencodeProcessesUnix()
  end
end

local function is_descendant_of_neovim(pid)
  local neovim_pid = vim.fn.getpid()
  local current_pid = pid

  -- Walk up because the way some shells launch processes,
  -- Neovim will not be the direct parent.
  for _ = 1, 10 do -- limit to 10 steps to avoid infinite loop
    local parent_pid = tonumber(exec("ps -o ppid= -p " .. current_pid))
    if not parent_pid then
      error("Couldn't determine parent PID for: " .. current_pid, 0)
    end

    if parent_pid == 1 then
      return false
    elseif parent_pid == neovim_pid then
      return true
    end

    current_pid = parent_pid
  end

  return false
end

---@return Server
local function find_server_inside_nvim_cwd()
  local found_server
  local nvim_cwd = vim.fn.getcwd()
  for _, server in ipairs(find_servers()) do
    local normalized_server_cwd = server.cwd
    local normalized_nvim_cwd = nvim_cwd

    if is_windows() then
      -- On Windows, normalize to backslashes for consistent comparison
      normalized_server_cwd = server.cwd:gsub("/", "\\")
      normalized_nvim_cwd = nvim_cwd:gsub("/", "\\")
    end

    -- CWDs match exactly, or opencode's CWD is under neovim's CWD.
    if normalized_server_cwd:find(normalized_nvim_cwd, 1, true) == 1 then
      found_server = server
      -- On Unix, check if it's a descendant of neovim (prioritize embedded)
      if not is_windows() and is_descendant_of_neovim(server.pid) then
        break
      end
    end
  end

  if not found_server then
    error("No `opencode` process inside Neovim's CWD", 0)
  end

  return found_server
end

---@param fn fun(): number Function that checks for the port.
---@param callback fun(ok: boolean, result: any) Called with eventually found port or error if not found after some time.
local function poll_for_port(fn, callback)
  local retries = 0
  local timer = vim.uv.new_timer()

  if not timer then
    callback(false, "Failed to create timer for polling `opencode` port")
    return
  end

  local timer_closed = false
  -- TODO: Suddenly with opentui release,
  -- on startup it seems the port can be available but too quickly calling it will no-op?
  -- Increasing delay for now to mitigate. But more reliable fix may be needed.
  timer:start(
    500,
    500,
    vim.schedule_wrap(function()
      if timer_closed then
        return
      end
      local ok, find_port_result = pcall(fn)
      if ok or retries >= 5 then
        timer_closed = true
        timer:stop()
        timer:close()
        callback(ok, find_port_result)
      else
        retries = retries + 1
      end
    end)
  )
end

---Test if a process is responding on `port`.
---@param port number
---@return number port
local function test_port(port)
  -- TODO: `curl` "/app" endpoint to verify it's actually an opencode server.
  local ok, chan = pcall(vim.fn.sockconnect, "tcp", ("localhost:%d"):format(port), { rpc = false, timeout = 200 })
  if not ok or chan == 0 then
    error(("No `opencode` process listening on port: %d"):format(port), 0)
  else
    pcall(vim.fn.chanclose, chan)
    return port
  end
end

---Attempt to get the `opencode` server's port. Tries, in order:
---1. A process responding on `opts.port`.
---2. Any `opencode` process running inside Neovim's CWD. Prioritizes embedded.
---3. Calling `opts.provider.start` and polling for the port.
---@param launch boolean? Whether to launch a new server if none found. Defaults to true.
function M.get_port(launch)
  if launch == nil then
    launch = true
  end

  local Promise = require("opencode.promise")

  return Promise.new(function(resolve, reject)
    local configured_port = require("opencode.config").opts.port
    local find_port_fn = configured_port and function()
      return test_port(configured_port)
    end or function()
      return find_server_inside_nvim_cwd().port
    end

    local initial_ok, initial_result = pcall(find_port_fn)
    if initial_ok then
      resolve(initial_result)
      return
    end

    if launch then
      vim.notify(initial_result .. " — starting `opencode`…", vim.log.levels.INFO, { title = "opencode" })

      local start_ok, start_result = pcall(require("opencode.provider").start)
      if not start_ok then
        reject("Error starting `opencode`: " .. start_result)
        return
      end
    end

    poll_for_port(find_port_fn, function(ok, result)
      if ok then
        resolve(result)
      else
        reject(result)
      end
    end)
  end)
end

return M
