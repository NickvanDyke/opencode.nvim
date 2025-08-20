local M = {}

---@param command string
---@return string
function M.exec(command)
  local executable = vim.split(command, " ")[1]
  if vim.fn.executable(executable) == 0 then
    error("'" .. executable .. "' command is not available", 0)
  end

  local handle = io.popen(command)
  if not handle then
    error("Couldn't execute command: " .. command, 0)
  end

  local output = handle:read("*a")
  handle:close()
  return output
end

return M
