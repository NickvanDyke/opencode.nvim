local M = {}

---@param callback fun(port: number)
local function get_port(callback)
  require("opencode.server").get_port(function(ok, result)
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

---Prompt `opencode`.
---
---1. Clears the TUI input if `opts.clear`.
---2. Appends `prompt` to the TUI input.
---  - Injects `opts.contexts` into `prompt`.
---3. Submits the TUI input if `opts.submit`.
---  - Sets up `opts.auto_reload` if enabled.
---  - Listens for Server-Sent-Events to forward as `OpencodeEvent` autocmd.
---  - Calls `opts.on_submit`.
---4. Calls `callback` if provided.
---
---@param prompt string The prompt to send to `opencode`, with optional `opts.contexts` placeholders.
---@param opts? opencode.prompt.Opts
---@param callback? fun()
function M.prompt(prompt, opts, callback)
  opts = {
    clear = opts and opts.clear or false,
    submit = opts and opts.submit or false,
  }

  get_port(function(port)
    require("opencode.async").chain_async({
      function(next)
        if opts.clear then
          require("opencode.client").tui_clear_prompt(port, next)
        else
          next()
        end
      end,
      function(next)
        prompt = require("opencode.context").inject(prompt)
        require("opencode.client").tui_append_prompt(prompt, port, next)
      end,
      function(next)
        if opts.submit then
          -- WARNING: If user never prompts opencode via the plugin, we'll never receive SSEs or register auto_reload autocmds.
          -- Could register in `/plugin` and even periodically check, but is it worth the complexity?
          if require("opencode.config").opts.auto_reload then
            require("opencode.reload").setup()
          end

          require("opencode.client").listen_to_sse(port, function(response)
            vim.api.nvim_exec_autocmds("User", {
              pattern = "OpencodeEvent",
              data = response,
            })
          end)

          local on_submit_ok, on_submit_err = pcall(require("opencode.config").opts.on_submit)
          if not on_submit_ok then
            vim.notify(
              "Error in `vim.g.opencode_opts.on_submit`: " .. on_submit_err,
              vim.log.levels.WARN,
              { title = "opencode" }
            )
          end

          require("opencode.client").tui_submit_prompt(port, next)
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
---| 'agent_cycle'

---Send a [command](https://opencode.ai/docs/keybinds) to `opencode`.
---
---@param command opencode.Command|string
---@param callback fun(response: table)|nil
function M.command(command, callback)
  get_port(function(port)
    -- No need to register SSE or auto_reload here - commands trigger neither
    -- (except maybe the `input_*` commands? but no reason for user to use those).

    local on_submit_ok, on_submit_err = pcall(require("opencode.config").opts.on_submit)
    if not on_submit_ok then
      vim.notify(
        "Error in `vim.g.opencode_opts.on_submit`: " .. on_submit_err,
        vim.log.levels.WARN,
        { title = "opencode" }
      )
    end

    require("opencode.client").tui_execute_command(command, port, callback)
  end)
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
  require("opencode.ui.ask").input(default, function(value, callback)
    if value and value ~= "" then
      M.prompt(value, opts, callback)
    else
      callback()
    end
  end)
end

---Select a prompt from `opts.prompts` to send to `opencode`.
---Includes preview when using `snacks.nvim`.
function M.select()
  require("opencode.ui.select").select(function(prompt, callback)
    if prompt then
      if prompt.ask then
        require("opencode").ask(prompt.prompt, prompt)
      else
        require("opencode").prompt(prompt.prompt, prompt, callback)
      end
    else
      callback()
    end
  end)
end

---Toggle an embedded `opencode`.
---Requires `snacks.terminal`.
function M.toggle()
  local ok, err = pcall(require("opencode.terminal").toggle)
  if not ok then
    ---@cast err string
    vim.notify(err, vim.log.levels.ERROR, { title = "opencode" })
  end
end

return M
