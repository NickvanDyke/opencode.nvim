local M = {}

---@alias opencode.Command
---| 'session_new'
---| 'session_share'
---| 'session_interrupt'
---| 'session_compact'
---| 'messages_page_up'
---| 'messages_page_down'
---| 'messages_half_page_up'
---| 'messages_half_page_down'
---| 'messages_first'
---| 'messages_last'
---| 'messages_copy'
---| 'messages_undo'
---| 'messages_redo'
---| 'input_clear'
---| 'agent_cycle'

---Send a [command](https://opencode.ai/docs/keybinds) to `opencode`.
---
---@param command opencode.Command|string The command to send to `opencode`.
---@param callback fun(response: table)|nil
function M.command(command, callback)
  require("opencode.cli.server").get_port(function(ok, port)
    if not ok then
      vim.notify(port, vim.log.levels.ERROR, { title = "opencode" })
      return
    end

    -- No need to register SSE here - commands don't trigger any.
    -- (except maybe the `input_*` commands? but no reason for user to use those).

    require("opencode.provider").show()

    require("opencode.cli.client").tui_execute_command(command, port, callback)
  end)
end

return M
