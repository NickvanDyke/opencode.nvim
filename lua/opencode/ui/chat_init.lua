---Main entry point for custom chat frontend
local M = {}

---Start a new chat session with custom UI
---@param opts? { width?: number, height?: number }
function M.start_chat(opts)
  -- Get or start opencode server
  require("opencode.cli.server")
    .get_port(true)
    :next(function(port)
      -- Open chat window
      local chat = require("opencode.ui.chat")
      local state = chat.open(opts)

      -- Store port
      state.port = port

      -- Subscribe to events first
      require("opencode.ui.chat_events").subscribe(port)

      -- Create new session via TUI command
      local client = require("opencode.cli.client")
      client.tui_execute_command("session.new", port, function()
        -- Session will be set via SSE event
      end)

      -- Show welcome message
      vim.schedule(function()
        if chat.get_state() then
          chat.add_message({
            role = "assistant",
            text = "Chat session starting... Type 'i' or 'a' to send a message.\n\nKeybindings:\n  i/a - Send message\n  n - New session\n  q/<Esc> - Close\n  yy - Yank message\n  <C-c> - Interrupt",
            streaming = false,
            complete = true,
          })
        end
      end)
    end)
    :catch(function(err)
      vim.notify("Failed to start opencode: " .. err, vim.log.levels.ERROR, { title = "opencode" })
    end)
end

return M
