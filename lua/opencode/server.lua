local M = {}

---@return table<number>
local function get_all_pids()
  -- Regex also allows flags like --port
  local handle = io.popen("ps aux | grep -E 'opencode(\\s+--.*)?$' | grep -v grep | awk '{print $2}'")
  if not handle then
    return {}
  end
  local output = handle:read("*a")
  handle:close()

  local pids = {}
  for pid_str in output:gmatch("[^\r\n]+") do
    local pid = tonumber(pid_str:match("^%s*(.-)%s*$"))
    if pid then
      table.insert(pids, pid)
    end
  end
  return pids
end

---@param pid number
---@return number|nil
local function get_port(pid)
  -- WARNING: Returns special values for some ports, e.g. 6969 = "acmsoda"
  local command = "lsof -p " .. pid .. " | grep LISTEN | grep TCP | awk '{print $9}' | cut -d: -f2"
  local handle = io.popen(command)
  if not handle then
    return nil
  end
  local port = handle:read("*a")
  handle:close()
  port = port:match("^%s*(.-)%s*$") -- trim whitespace
  if port == "" then
    return nil
  end
  return tonumber(port)
end

---@param pid number
---@return string|nil
local function get_cwd(pid)
  local command = "lsof -a -p " .. pid .. " -d cwd | tail -1 | awk '{print $NF}'"
  local handle = io.popen(command)
  if not handle then
    return nil
  end
  local cwd = handle:read("*a")
  handle:close()
  cwd = cwd:match("^%s*(.-)%s*$") -- trim whitespace
  if cwd == "" then
    return nil
  end
  return cwd
end


---@return number|nil
function M.find_port()
  local server_pid
  for _, pid in ipairs(get_all_pids()) do
    local opencode_cwd = get_cwd(pid)
    -- CWDs match exactly, or opencode's CWD is under neovim's CWD.

    if opencode_cwd and opencode_cwd:find(vim.fn.getcwd(), 1, true) == 1 then

      server_pid = pid
      break
    end
  end

  if not server_pid then
    vim.notify("Couldn't find an opencode server process running in or under Neovim's CWD", vim.log.levels.ERROR)
    return nil
  end

  local server_port = get_port(server_pid)
  if not server_port then
    vim.notify("Couldn't determine opencode server port", vim.log.levels.ERROR)
    return nil
  end

  return server_port
end

return M
