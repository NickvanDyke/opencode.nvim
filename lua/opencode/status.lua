local M = {}

---@alias opencode.status.Status
---| "idle"
---| "error"
---| "responding"
---| "requesting_permission"

---@alias opencode.status.Icon
---| "󰚩"
---| "󱜙"
---| "󱚟"
---| "󱚡"
---| "󱚧"

---@type opencode.status.Status|nil
M.status = nil

---@return opencode.status.Icon
function M.statusline()
  if M.status == "idle" then
    return "󰚩"
  elseif M.status == "responding" then
    return "󱜙"
  elseif M.status == "requesting_permission" then
    return "󱚟"
  elseif M.status == "error" then
    return "󱚡"
  else
    return "󱚧"
  end
end

-- TODO: Still seem to not get `session.idle` events reliably... So fallback to a timer.
local idle_timer = vim.uv.new_timer()

---@param event opencode.cli.client.Event
function M.update(event)
  if event.type == "server.connected" or event.type == "session.idle" then
    M.status = "idle"
  elseif
    event.type == "message.updated"
    or event.type == "message.part.updated"
    or event.type == "permission.replied"
  then
    M.status = "responding"
  elseif event.type == "permission.updated" then
    M.status = "requesting_permission"
  elseif event.type == "session.error" then
    M.status = "error"
  end

  idle_timer:stop()
  idle_timer:start(
    1000,
    0,
    vim.schedule_wrap(function()
      if M.status == "responding" then
        M.status = "idle"
      end
    end)
  )
end

return M
