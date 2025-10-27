local M = {}

---@param callback fun(port: number)
local function get_port(callback)
  require("opencode.cli.server").get_port(function(ok, result)
    if ok then
      callback(result)
    else
      vim.notify(result, vim.log.levels.ERROR, { title = "opencode" })
    end
  end)
end

---@class opencode.prompt.Opts
---@field clear? boolean Clear the TUI input before.
---@field submit? boolean Submit the TUI input after.
---@field context? opencode.Context The context the prompt was written or selected in, if any.

---Prompt `opencode`.
---
---1. Clears the TUI input if `opts.clear`.
---2. Appends `prompt` to the TUI input.
---  - Injects `opts.contexts` into `prompt`.
---3. Submits the TUI input if `opts.submit`.
---  - Listens for Server-Sent-Events to forward as `OpencodeEvent` autocmd.
---  - Calls `opts.on_send`.
---4. Calls `callback` if provided.
---
---@param prompt string The prompt to send to `opencode`, with optional `opts.contexts` placeholders.
---@param opts? opencode.prompt.Opts
---@param callback? fun()
function M.prompt(prompt, opts, callback)
  opts = {
    clear = opts and opts.clear or false,
    submit = opts and opts.submit or false,
    context = opts and opts.context or require("opencode.context").new(),
  }

  get_port(function(port)
    require("opencode.provider").show()

    require("opencode.util").chain({
      function(next)
        if opts.clear then
          require("opencode.cli.client").tui_clear_prompt(port, next)
        else
          next()
        end
      end,
      function(next)
        local rendered = opts.context:render(prompt)
        local plaintext = opts.context.plaintext(rendered.output)
        require("opencode.cli.client").tui_append_prompt(plaintext, port, next)
      end,
      function(next)
        if opts.submit then
          -- WARNING: If user never prompts opencode via the plugin, we'll never receive SSEs.
          -- Could register in `/plugin` and even periodically check, but is it worth the complexity and performance hit?
          require("opencode.cli.client").listen_to_sse(port, function(response)
            vim.api.nvim_exec_autocmds("User", {
              pattern = "OpencodeEvent",
              data = {
                event = response,
                port = port,
              },
            })
          end)

          require("opencode.cli.client").tui_submit_prompt(port, next)
        else
          next()
        end
      end,
      function()
        if callback then
          callback()
        end
      end,
    })
  end)
end

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
---@param command opencode.Command|string|nil The command to send to `opencode`. If `nil`, opens `vim.ui.select` to choose a command.
---@param callback fun(response: table)|nil
function M.command(command, callback)
  require("opencode.util").chain({
    function(next)
      if not command then
        vim.ui.select({
          { name = "New session", command = "session_new" },
          { name = "Share session", command = "session_share" },
          { name = "Interrupt", command = "session_interrupt" },
          { name = "Compact messages", command = "session_compact" },
          { name = "Messages page up", command = "messages_page_up" },
          { name = "Messages page down", command = "messages_page_down" },
          { name = "Messages half page up", command = "messages_half_page_up" },
          { name = "Messages half page down", command = "messages_half_page_down" },
          { name = "Messages first", command = "messages_first" },
          { name = "Messages last", command = "messages_last" },
          { name = "Copy last message", command = "messages_copy" },
          { name = "Undo last message", command = "messages_undo" },
          { name = "Redo last message", command = "messages_redo" },
          { name = "Clear input", command = "input_clear" },
          { name = "Cycle agent", command = "agent_cycle" },
        }, {
          prompt = "Command opencode: ",
          format_item = function(item)
            return item.name
          end,
        }, function(choice)
          if choice then
            command = choice.command
            next()
          end
        end)
      else
        next()
      end
    end,
    function()
      get_port(function(port)
        -- No need to register SSE here - commands don't trigger any.
        -- (except maybe the `input_*` commands? but no reason for user to use those).

        require("opencode.provider").show()

        ---@cast command opencode.Command|string
        require("opencode.cli.client").tui_execute_command(command, port, callback)
      end)
    end,
  })
end

---Input a prompt to send to `opencode`.
---Press the up arrow to browse recent prompts.
---
--- - Highlights `opts.contexts` placeholders.
--- - Completes `opts.contexts` placeholders.
---   - Press `<Tab>` to trigger built-in completion.
---   - When using `blink.cmp` and `snacks.input`, registers `opts.auto_register_cmp_sources`.
---
---@param default? string Text to prefill the input with.
---@param opts? opencode.prompt.Opts Options for `prompt()`.
function M.ask(default, opts)
  opts = opts or {}
  opts.context = opts.context or require("opencode.context").new()

  vim.print(opts.context)
  require("opencode.ui.ask").input(default, opts.context, function(value)
    if value and value ~= "" then
      M.prompt(value, opts)
    end
  end)
end

---Select a prompt from `opts.prompts` to send to `opencode`.
---Includes preview when using `snacks.picker`.
function M.select()
  local context = require("opencode.context").new()

  require("opencode.ui.select").select(context, function(prompt)
    if prompt then
      prompt.context = context
      if prompt.ask then
        require("opencode").ask(prompt.prompt, prompt)
      else
        require("opencode").prompt(prompt.prompt, prompt)
      end
    end
  end)
end

---Toggle `opencode` via `opts.provider`.
function M.toggle()
  require("opencode.provider").toggle()
end

return M
