---Process utilities for provider implementations.
local M = {}

---Get all descendant PIDs of a process (children, grandchildren, etc.)
---@param pid number The parent process ID
---@param max_depth? number Maximum recursion depth (default 3)
---@return number[] pids List of descendant PIDs
function M.get_descendants(pid, max_depth)
  max_depth = max_depth or 3

  local function recurse(current_pid, depth)
    if depth > max_depth then
      return {}
    end

    local children = {}
    local output = vim.fn.system("pgrep -P " .. current_pid .. " 2>/dev/null")
    for child_pid in output:gmatch("%d+") do
      local child = tonumber(child_pid)
      table.insert(children, child)
      for _, descendant in ipairs(recurse(child, depth + 1)) do
        table.insert(children, descendant)
      end
    end
    return children
  end

  return recurse(pid, 1)
end

---Find the TCP port a process is listening on.
---@param pid number The process ID
---@return number|nil port The listening port, or nil if not found
function M.get_listening_port(pid)
  local lsof_output = vim.fn.system("lsof -w -iTCP -sTCP:LISTEN -P -n -a -p " .. pid .. " 2>/dev/null")
  for line in lsof_output:gmatch("[^\r\n]+") do
    local port = line:match(":(%d+)%s+%(LISTEN%)")
    if port then
      return tonumber(port)
    end
  end
  return nil
end

---Find the listening port of any descendant of a process.
---@param pid number The ancestor process ID
---@param max_depth? number Maximum recursion depth (default 3)
---@return number|nil port The listening port, or nil if not found
function M.get_descendant_listening_port(pid, max_depth)
  local descendants = M.get_descendants(pid, max_depth)
  for _, desc_pid in ipairs(descendants) do
    local port = M.get_listening_port(desc_pid)
    if port then
      return port
    end
  end
  return nil
end

return M
