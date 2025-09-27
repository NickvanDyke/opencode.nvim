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

---@deprecated Pass options via `vim.g.opencode_opts` instead. See [README](https://github.com/NickvanDyke/opencode.nvim) for example.
---@param opts opencode.Opts
function M.setup(opts)
  vim.g.opencode_opts = opts
  vim.notify(
    "`opencode.setup()` is deprecated — pass options via `vim.g.opencode_opts` instead. See [README](https://github.com/NickvanDyke/opencode.nvim) for example.",
    vim.log.levels.WARN,
    { title = "opencode" }
  )
end

---Send a prompt to `opencode`'s TUI.
---@param prompt string
function M.prompt(prompt)
  -- This does duplicate the `get_port` work, but seems negligible atm.
  M.clear_prompt(function()
    M.append_prompt(prompt, function()
      M.submit_prompt()
    end)
  end)
end

---Append a prompt to `opencode`'s TUI.
---Injects `opts.contexts` into the prompt.
---@param prompt string
---@param callback fun()|nil
function M.append_prompt(prompt, callback)
  get_port(function(port)
    prompt = require("opencode.context").inject(prompt)
    require("opencode.client").tui_append_prompt(prompt, port, callback)
  end)
end

---Submit the current prompt in `opencode`'s TUI.
---
---Additionally:
---1. Sets up `opts.auto_reload` if enabled.
---2. Calls `opts.on_send`.
---3. Listens for SSEs from `opencode` to forward as `OpencodeEvent` autocmd.
---@param callback fun()|nil
function M.submit_prompt(callback)
  get_port(function(port)
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

    local on_send_ok, on_send_err = pcall(require("opencode.config").opts.on_send)
    if not on_send_ok then
      vim.notify("Error in `opts.on_send`: " .. on_send_err, vim.log.levels.WARN, { title = "opencode" })
    end

    require("opencode.client").tui_submit_prompt(port, callback)
  end)
end

---Clear the current prompt in `opencode`'s TUI.
---@param callback fun()|nil
function M.clear_prompt(callback)
  get_port(function(port)
    require("opencode.client").tui_clear_prompt(port, callback)
  end)
end

---Send a command to `opencode`.
---See https://opencode.ai/docs/keybinds/ for available commands.
---@param command string
---@param callback fun(response: table)|nil
function M.command(command, callback)
  get_port(function(port)
    -- No need to register SSE or auto_reload here - commands trigger neither
    -- (except maybe the `input_*` commands? but no reason for user to use those).

    local on_send_ok, on_send_err = pcall(require("opencode.config").opts.on_send)
    if not on_send_ok then
      vim.notify("Error in `opts.on_send`: " .. on_send_err, vim.log.levels.WARN, { title = "opencode" })
    end

    require("opencode.client").tui_execute_command(command, port, callback)
  end)
end

---Input a prompt to send to `opencode`.
---
--- - Highlights `opts.contexts` in the input.
--- - Offers completions for `opts.contexts` when using `snacks.input`.
---   - Press `<Tab>` or `<C-x><C-o>` to trigger built-in completion.
---   - When using `blink.cmp`, registers `opts.auto_register_cmp_sources`.
---@param default? string Text to prefill the input with.
function M.ask(default)
  require("opencode.input").input(default, function(value)
    if value and value ~= "" then
      M.prompt(value)
    end
  end)
end

---Select a prompt from `opts.prompts` to send to `opencode`.
---Filters prompts according to whether they use `@selection` and whether we're in visual mode.
function M.select()
  ---@type opencode.Prompt[]
  local prompts = vim.tbl_filter(function(prompt)
    local is_visual = vim.fn.mode():match("[vV\22]")
    -- WARNING: Technically depends on user using built-in `@selection` context by name...
    -- Could compare function references? Or add `visual = true/false` to contexts objects.
    -- Probably more trouble than it's worth.
    local does_prompt_use_visual = prompt.prompt:match("@selection")
    if is_visual then
      return does_prompt_use_visual
    else
      return not does_prompt_use_visual
    end
  end, vim.tbl_values(require("opencode.config").opts.prompts))

  vim.ui.select(
    prompts,
    {
      prompt = "Prompt opencode: ",
      ---@param item opencode.Prompt
      format_item = function(item)
        return item.description
      end,
    },
    ---@param choice opencode.Prompt
    function(choice)
      if choice then
        M.prompt(choice.prompt)
      end
    end
  )
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
