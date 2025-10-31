local M = {}

---@alias opencode.Status
---| "idle"
---| "error"
---| "responding"
---| "requesting_permission"

---@type nil|opencode.Status
local status = nil

-- TODO: Still seem to not get `session.idle` events reliably... So fallback to a timer.
-- I wonder if it's because of the SSE `on_stdout` edge case? We silently miss events, and it errors completely for some?
local idle_timer = vim.uv.new_timer()

function M.update(event)
  if event.type == "server.connected" or event.type == "session.idle" then
    status = "idle"
  elseif
    event.type == "message.updated"
    or event.type == "message.part.updated"
    or event.type == "permission.replied"
  then
    status = "responding"
  elseif event.type == "permission.updated" then
    status = "requesting_permission"
  elseif event.type == "session.error" then
    status = "error"
  end

  idle_timer:stop()
  idle_timer:start(
    1000,
    0,
    vim.schedule_wrap(function()
      if status == "responding" then
        status = "idle"
      end
    end)
  )
end

function M.statusline()
  -- Kinda hard to distinguish these icons, but they're fun... :D
  -- And a nice one-char solution.
  if status == "idle" then
    return "󰚩"
  elseif status == "responding" then
    return "󱜙"
  elseif status == "requesting_permission" then
    return "󱚟"
  elseif status == "error" then
    return "󱚡"
  else
    return "󱚧"
  end
end

return M
