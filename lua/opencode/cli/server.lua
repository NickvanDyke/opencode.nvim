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

-- check if a cmdline of a PID contains a string
---@param pid number
---@param string string
---@return boolean
local function check_proc_cmdline_for_string(pid, needle)
  local output = exec("ps -p " .. pid .. " -ww -o args=")
  if vim.v.shell_error ~= 0 then
    return false
  end
  local result = string.find(output, needle, 1, true)
  return result ~= nil
end

-- derive the CWD from a PID
---@param pid number
local function read_proc_cwd(pid)
  return exec("lsof -w -a -p " .. pid .. " -d cwd"):match("%s+(/.*)$")
end

---@return Server[]
local function find_servers()
  if vim.fn.executable("lsof") == 0 then
    -- lsof is a common utility to list open files and ports, but not always available by default.
    error(
      "`lsof` executable not found in `PATH` to auto-find `opencode` — please install it or set `vim.g.opencode_opts.port`",
      0
    )
  end
  -- Going straight to `lsof` relieves us of parsing `ps` and all the non-portable 'opencode'-containing processes it might return.
  -- With these flags, we'll only get processes that are listening on TCP ports and have 'opencode' in their command name.
  -- i.e. pretty much guaranteed to be just opencode server processes.
  -- `-w` flag suppresses warnings about inaccessible filesystems (e.g. Docker FUSE).
  -- NOTE: some versions of opencode will name themselves opencode, while others will be named bun, we will disambiguate these below.
  local output = exec("lsof -w -iTCP -sTCP:LISTEN -P -n | grep -e opencode -e bun")
  if output == "" then
    error("No `opencode` processes", 0)
  end

  local servers = {}
  for line in output:gmatch("[^\r\n]+") do
    -- lsof output: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
    local parts = vim.split(line, "%s+")

    local pid = tonumber(parts[2])
    local comm = parts[1]
    local port = tonumber(parts[9]:match(":(%d+)$")) -- Extract port from NAME field (which is e.g. "127.0.0.1:12345")
    if not pid or not port then
      error("Couldn't parse `opencode` PID and port from `lsof` entry: " .. line, 0)
    end

    -- skip any processes that do not contain opencode string in the command line
    if check_proc_cmdline_for_string(pid, 'opencode') then
      local cwd = read_proc_cwd(pid)
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
    error("No `opencode` process inside Neovim's CWD", 0)
  end

  return found_server
end

---@param fn fun(): number Function that checks for the port.
---@param callback fun(ok: boolean, result: any) Called with eventually found port or error if not found after some time.
local function poll_for_port(fn, callback)
  local retries = 0
  local timer = vim.uv.new_timer()
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
