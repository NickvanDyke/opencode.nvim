local M = {}

---@param command string
---@return string
function M.exec(command)
  -- TODO: Use vim.fn.jobstart for async, and so I can capture stderr (to throw error instead of it writing to the buffer).
  -- (or even the newer `vim.system`? Could update client.lua too? Or maybe not because SSE is long-running.)
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
