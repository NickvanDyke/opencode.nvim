local M = {}

-- Use the new server_detection module
local detection = require("opencode.server_detection")

---Find the port of an opencode server process running inside Neovim's CWD.
---@return number
function M.find_port()
  local port, error_msg = detection.find_port()
  if not port then
    error(error_msg or "Couldn't find opencode server", 0)
  end
  return port
end

---@param callback fun(ok: boolean, result: any) Called with eventually found port or error if not found after some time.
function M.poll_for_port(callback)
  local retries = 0
  local timer = vim.uv.new_timer()
  timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      local ok, port_result = pcall(M.find_port)
      if ok then
        timer:stop()
        callback(true, port_result)
      elseif retries >= 20 then
        timer:stop()
        callback(false, port_result)
      else
        retries = retries + 1
      end
    end)
  )
end

return M
