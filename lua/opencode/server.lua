local M = {}

---@return Server[]
local function find_servers()
  if vim.fn.executable("lsof") == 0 then
    -- lsof is a common utility to list open files and ports, but not always available by default.
    error("'lsof' command is not available — please install it to auto-find opencode, or set opts.port", 0)
  end
  -- Going straight to `lsof` relieves us of parsing `ps` and all the non-portable 'opencode'-containing processes it might return.
  -- With these flags, we'll only get processes that are listening on TCP ports and have 'opencode' in their command name.
  -- i.e. pretty much guaranteed to be just opencode server processes.
  local output = require("opencode.util").exec("lsof -iTCP -sTCP:LISTEN -P -n | grep opencode")
  if output == "" then
    error("Couldn't find any opencode processes", 0)
  end

  local servers = {}
  for line in output:gmatch("[^\r\n]+") do
    -- lsof output: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
    local parts = vim.split(line, "%s+")

    local pid = tonumber(parts[2])
    local port = tonumber(parts[9]:match(":(%d+)$")) -- Extract port from NAME field (which is e.g. "127.0.0.1:12345")
    if not pid or not port then
      error("Couldn't parse opencode PID and port from 'lsof' entry: " .. line, 0)
    end

    local cwd = require("opencode.util").exec("lsof -a -p " .. pid .. " -d cwd | tail -1 | awk '{print $NF}'")
    if cwd == "" then
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
    local parent_pid = tonumber(require("opencode.util").exec("ps -o ppid= -p " .. current_pid))
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
    error("Couldn't find an opencode process running inside Neovim's CWD", 0)
  end

  return found_server
end

---@param callback fun(ok: boolean, result: any) Called with eventually found port or error if not found after some time.
local function poll_for_port(callback)
  local retries = 0
  local timer = vim.uv.new_timer()
  timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      local ok, find_server_result = pcall(find_server_inside_nvim_cwd)
      if ok then
        timer:stop()
        callback(true, find_server_result.port)
      elseif retries >= 20 then
        timer:stop()
        callback(false, find_server_result)
      else
        retries = retries + 1
      end
    end)
  )
end

---Get the opencode server port. Checks, in order:
---1. `opts.port`.
---2. The port of any opencode server running inside Neovim's CWD, prioritizing embedded terminals.
---3. Calls `opts.on_opencode_not_found` and polls for the port if it returns `true`.
---@param callback fun(ok: boolean, result: any) Called with eventually found port or error if not found after some time.
function M.get_port(callback)
  local configured_port = require("opencode.config").options.port
  if configured_port then
    -- TODO: Should still call `opts.on_opencode_not_found` if necessary.
    -- But idk how to check that without `lsof`, which `opts.port` is a workaround for...
    -- Confusingly, this will proceed to curl giving exit code 7, instead of the more helpful "opencode not found" error.
    callback(true, configured_port)
    return
  end

  local found_server, find_server_result = pcall(find_server_inside_nvim_cwd)
  if found_server then
    callback(true, find_server_result.port)
    return
  end

  local ok, should_poll = pcall(require("opencode.config").options.on_opencode_not_found)
  if ok and should_poll then
    poll_for_port(callback)
    return
  end

  callback(false, find_server_result)
end

return M
