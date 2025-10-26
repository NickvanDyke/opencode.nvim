local IS_WINDOWS = vim.fn.has("win32") == 1

local M = {}

---@param command string|string[]
---@param cb fun(string?)
local function exec_async(command, cb)
  if type(command) == "string" then
    command = vim.split(command, " ")
  end

  local executable = command[1]
  if vim.fn.executable(executable) == 0 then
    error("`" .. executable .. "` command is not available", 0)
  end

  vim.system(command, { text = true }, function(handle)
    if handle.code ~= 0 then
      error("Couldn't execute command: " .. table.concat(command, " "))
      cb(nil)
      return
    end
    cb(handle.stdout)
  end)
end

---@class Server
---@field pid number
---@field port number
---@field cwd string

---@param cb fun(servers: Server[])
local function find_servers(cb)
  if IS_WINDOWS then
    exec_async({
      "powershell",
      "-NoProfile",
      "-Command",
      [[Get-NetTCPConnection -State Listen | ForEach-Object {
      $p=Get-Process -Id $_.OwningProcess -ea 0;
      if($p -and ($p.ProcessName -ieq 'opencode' -or $p.ProcessName -ieq 'opencode.exe')) {
        '{0} {1}' -f $_.OwningProcess, $_.LocalPort
      }
    }]],
    }, function(output)
      local servers = {}
      for line in output:gmatch("[^\r\n]+") do
        local parts = vim.split(line, "%s+")
        local pid = tonumber(parts[1])
        local port = tonumber(parts[2])

        if not pid or not port then
          error("Couldn't parse `opencode` PID and port from entry: " .. line, 0)
        end

        -- have to skip CWD on Windows as it's non-trivial to get
        servers[#servers + 1] = {
          pid = pid,
          port = port,
          -- cwd = vim.fn.getcwd(),
        }
      end
      cb(servers)
    end)
    return
  end

  if vim.fn.executable("lsof") == 0 then
    -- lsof is a common utility to list open files and ports, but not always available by default.
    error(
      "`lsof` executable not found in `PATH` to auto-find `opencode` — please install it or set `vim.g.opencode_opts.port`",
      0
    )
  end

  exec_async("lsof -w -iTCP -sTCP:LISTEN -P -n | grep opencode", function(output)
    if output == "" then
      error("Couldn't find any `opencode` processes", 0)
    end

    local servers = {}
    local pending_cwds = 0
    local lines = {}

    -- Collect all lines first
    for line in output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end

    if #lines == 0 then
      cb(servers)
      return
    end

    pending_cwds = #lines

    for _, line in ipairs(lines) do
      -- lsof output: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
      local parts = vim.split(line, "%s+")

      local pid = tonumber(parts[2])
      local port = tonumber(parts[9]:match(":(%d+)$")) -- Extract port from NAME field (which is e.g. "127.0.0.1:12345")
      if not pid or not port then
        error("Couldn't parse `opencode` PID and port from `lsof` entry: " .. line, 0)
      end

      exec_async("lsof -w -a -p " .. pid .. " -d cwd", function(cwd_result)
        local cwd = cwd_result:match("%s+(/.*)$")

        if not cwd then
          error("Couldn't determine CWD for PID: " .. pid, 0)
        else
          servers[#servers + 1] = {
            pid = pid,
            port = port,
            cwd = cwd,
          }
        end

        pending_cwds = pending_cwds - 1
        if pending_cwds == 0 then
          cb(servers)
        end
      end)
    end
  end)
end

---@param cb fun(result: boolean)
local function is_descendant_of_neovim(pid, cb)
  local neovim_pid = vim.fn.getpid()
  local current_pid = pid
  local cmd = vim.fn.has("win32") and "wmic process where ProcessId=%d get ParentProcessId /value"
    or "ps -o ppid= -p %d"

  -- Walk up because the way some shells launch processes,
  -- Neovim will not be the direct parent.
  local steps = {}

  for _ = 1, 4 do -- limit to 4 steps to avoid infinite loop
    table.insert(steps, function(next)
      exec_async(cmd:format(current_pid), function(output)
        local parent_pid = tonumber(output:match("(%d+)"))
        if not parent_pid or parent_pid == 1 then
          cb(false)
        elseif parent_pid == neovim_pid then
          cb(true)
        else
          current_pid = parent_pid
          next()
        end
      end)
    end)
  end

  table.insert(steps, function()
    cb(false)
  end)

  require("opencode.util").chain(steps)
end

---@param cb fun(server: Server|nil)
local function find_server_inside_nvim_cwd(cb)
  local found_server
  local nvim_cwd = vim.fn.getcwd()

  find_servers(function(servers)
    local steps = {}

    for i, server in ipairs(servers) do
      -- CWDs match exactly, or opencode's CWD is under neovim's CWD.
      if IS_WINDOWS or server.cwd:find(nvim_cwd, 1, true) == 1 then
        table.insert(steps, function(next)
          is_descendant_of_neovim(server.pid, function(is_descendant)
            if is_descendant then
              found_server = server
            else
              next()
            end
          end)
        end)
      end
    end

    table.insert(steps, function()
      cb(found_server)
    end)

    require("opencode.util").chain(steps)
  end)
end

---Test if a process is responding on `port`.
---@param port number
---@return number port
local function test_port(port)
  -- TODO: `curl` "/app" endpoint to verify it's actually an opencode server.
  local chan = vim.fn.sockconnect("tcp", ("localhost:%d"):format(port), { rpc = false, timeout = 200 })
  if chan == 0 then
    error(("Couldn't find a process listening on port: %d"):format(port), 0)
  else
    pcall(vim.fn.chanclose, chan)
    return port
  end
end

local PORT_RANGE = { 4096, 5096 }
---@return number
local function find_free_port()
  for port = PORT_RANGE[1], PORT_RANGE[2] do
    local ok = pcall(test_port, port)
    if not ok then
      return port
    end
  end
  error("Couldn't find a free port in range: " .. PORT_RANGE[1] .. "-" .. PORT_RANGE[2], 0)
end

---Attempt to get the `opencode` server's port. Tries, in order:
---1. A process responding on `opts.port`.
---2. Any `opencode` process running inside Neovim's CWD. Prioritizes embedded.
---3. Calling `opts.on_opencode_not_found` with random free port in range.
---@param callback fun(ok: boolean, result: any) Called with eventually found port or error if not found after some time.
function M.get_port(callback)
  local step = {
    function(next)
      local configured_port = require("opencode.config").opts.port
      vim.schedule(function()
        if configured_port and test_port(configured_port) then
          callback(true, configured_port)
        else
          next()
        end
      end)
    end,
    function(next)
      find_server_inside_nvim_cwd(function(server)
        if server then
          vim.schedule(function()
            callback(true, server.port)
          end)
        else
          next()
        end
      end)
    end,
    function()
      vim.schedule(function()
        local port_ok, port_result = pcall(find_free_port)
        if not port_ok then
          callback(false, "Error finding free port: " .. port_result)
          return
        end
        local ok, result = pcall(require("opencode.config").opts.on_opencode_not_found, port_result)
        if not ok then
          callback(false, "Error in `vim.g.opencode_opts.on_opencode_not_found`: " .. result)
        else
          callback(true, port_result)
        end
      end)
    end,
  }

  require("opencode.util").chain(step)
end

return M
