local M = {}

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

---@return Server[]
local function find_servers()
  if vim.fn.executable("lsof") == 0 then
    -- lsof is a common utility to list open files and ports, but not always available by default.
    error(
      "`lsof` command is not available — please install it to auto-find `opencode`, or set `vim.g.opencode_opts.port`",
      0
    )
  end
  -- Going straight to `lsof` relieves us of parsing `ps` and all the non-portable 'opencode'-containing processes it might return.
  -- With these flags, we'll only get processes that are listening on TCP ports and have 'opencode' in their command name.
  -- i.e. pretty much guaranteed to be just opencode server processes.
  -- `-w` flag suppresses warnings about inaccessible filesystems (e.g. Docker FUSE).
  local output = exec("lsof -w -iTCP -sTCP:LISTEN -P -n | grep opencode")
  if output == "" then
    error("Couldn't find any `opencode` processes", 0)
  end

  local servers = {}
  for line in output:gmatch("[^\r\n]+") do
    -- lsof output: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
    local parts = vim.split(line, "%s+")

    local pid = tonumber(parts[2])
    local port = tonumber(parts[9]:match(":(%d+)$")) -- Extract port from NAME field (which is e.g. "127.0.0.1:12345")
    if not pid or not port then
      error("Couldn't parse `opencode` PID and port from `lsof` entry: " .. line, 0)
    end

    local cwd = exec("lsof -w -a -p " .. pid .. " -d cwd"):match("%s+(/.*)$")
    if not cwd then
      error("Couldn't determine CWD for PID: " .. pid, 0)
    end

    table.insert(
      servers,
      ---@class Server
      ---@field pid number
      ---@field port number
      ---@field cwd string
      {
        pid = pid,
        port = port,
        cwd = cwd,
      }
    )
  end
  return servers
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
    -- CWDs match exactly, or opencode's CWD is under neovim's CWD.
    if server.cwd:find(nvim_cwd, 1, true) == 1 then
      found_server = server
      if is_descendant_of_neovim(server.pid) then
        -- Stop searching to prioritize embedded
        break
      end
    end
  end

  if not found_server then
    error("Couldn't find an `opencode` process running inside Neovim's CWD", 0)
  end

  return found_server
end

---@param fn fun(): number Function that checks for the port.
---@param callback fun(ok: boolean, result: any) Called with eventually found port or error if not found after some time.
local function poll_for_port(fn, callback)
  local retries = 0
  local timer = vim.uv.new_timer()
  timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      local ok, find_port_result = pcall(fn)
      if ok then
        timer:stop()
        timer:close()
        callback(true, find_port_result)
      elseif retries >= 20 then
        timer:stop()
        timer:close()
        callback(false, find_port_result)
      else
        retries = retries + 1
      end
    end)
  )
end

---Test if an opencode process is responding on the given port.
---Uses `curl` for better availability than `lsof`.
---@param port number
---@return number
local function test_port(port)
  vim.cmd("silent !curl -s http://localhost:" .. port)
  return vim.v.shell_error == 0 and port or error("Couldn't find an `opencode` process on port: " .. port, 0)
end

---Attempt to get the opencode server port. Tries, in order:
---1. A process responding on `opts.port`.
---2. Any opencode process running inside Neovim's CWD. Prioritizes embedded.
---3. Calling `opts.on_opencode_not_found` and polling for the port if it returns `true`.
---@param callback fun(ok: boolean, result: any) Called with eventually found port or error if not found after some time.
function M.get_port(callback)
  local configured_port = require("opencode.config").opts.port
  local find_port_fn = configured_port and function()
    return test_port(configured_port)
  end or function()
    return find_server_inside_nvim_cwd().port
  end

  require("opencode.async").chain_async({
    function(next)
      local ok, result = pcall(find_port_fn)
      if ok then
        callback(true, result)
      else
        next()
      end
    end,
    function(next)
      local ok, result = pcall(require("opencode.config").opts.on_opencode_not_found)
      if not ok then
        callback(false, "Error in `vim.g.opencode_opts.on_opencode_not_found`: " .. result)
      else
        -- Always proceed - even if `opencode` wasn't started, failing to find it will give a more helpful error message.
        next()
      end
    end,
    function(_)
      poll_for_port(find_port_fn, callback)
    end,
  })
end

return M
