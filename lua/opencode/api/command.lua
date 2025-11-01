local M = {}

---See available commands [here](https://github.com/sst/opencode/blob/dev/packages/opencode/src/cli/cmd/tui/event.ts).
---@alias opencode.Command
---| 'session.list'
---| 'session.new'
---| 'session.share'
---| 'session.interrupt'
---| 'session.compact'
---| 'session.page.up'
---| 'session.page.down'
---| 'session.half.page.up'
---| 'session.half.page.down'
---| 'session.first'
---| 'session.last'
---| 'session.undo'
---| 'session.redo'
---| 'prompt.submit'
---| 'prompt.clear'
---| 'agent.cycle'

---Send a command to `opencode`.
---
---@param command opencode.Command|string The command to send. Can be built-in or reference your custom commands.
---@param callback fun(response: table)|nil
function M.command(command, callback)
  require("opencode.cli.server").get_port(function(ok, port)
    if not ok then
      vim.notify(port, vim.log.levels.ERROR, { title = "opencode" })
      return
    end

    -- No need to register SSE here - commands don't trigger any.
    -- (except maybe the `input_*` commands? but no reason for user to use those).

    -- Swallow errors - more of a preference than a requirement here
    pcall(require("opencode.provider").show)

    require("opencode.cli.client").tui_execute_command(command, port, callback)
  end)
end

return M
