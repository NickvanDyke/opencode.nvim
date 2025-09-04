local M = {}

-- Lazily perform setup the first time this module is `require`d, i.e. actually using its API.
-- This way, users don't have to `require` it (impacting startup time) just to call `setup()`.
-- See https://mrcjkb.dev/posts/2023-08-22-setup.html for more reasoning.
-- WARNING: This is meant to be the only public module - using an internal module directly will bypass this setup.
-- TODO: Is there a way to enforce or indicate that?
if not vim.g.opencode_is_setup then
  vim.g.opencode_is_setup = true
  require("opencode.config").setup(vim.g.opencode_opts)
end

---@deprecated Pass options via `vim.g.opencode_opts` instead. See [README](https://github.com/NickvanDyke/opencode.nvim) for example.
---@param opts opencode.Opts
function M.setup(opts)
  require("opencode.config").setup(opts)
  vim.notify(
    "`opencode.setup()` is deprecated — pass options via `vim.g.opencode_opts` instead. See [README](https://github.com/NickvanDyke/opencode.nvim) for example.",
    vim.log.levels.WARN,
    { title = "opencode" }
  )
end

---Send a prompt to opencode.
---
---As the entry point to prompting, this function also:
---1. Calls `opts.on_opencode_not_found` if no opencode process is found.
---2. Injects `opts.contexts` into the prompt.
---3. Sets up `opts.auto_reload` if enabled.
---4. Calls `opts.on_send`.
---5. Listens for SSEs from opencode to forward as `OpencodeEvent` autocmd.
---@param prompt string
function M.prompt(prompt)
  require("opencode.server").get_port(function(ok, result)
    if not ok then
      vim.notify(result, vim.log.levels.ERROR, { title = "opencode" })
      return
    end

    prompt = require("opencode.context").inject(prompt, require("opencode.config").opts.contexts)

    -- WARNING: If user never prompts opencode via the plugin, we'll never receive SSEs or register auto_reload autocmds.
    -- Could register in `/plugin` and even periodically check, but is it worth the complexity?
    if require("opencode.config").opts.auto_reload then
      require("opencode.reload").setup()
    end

    require("opencode.client").listen_to_sse(result, function(response)
      vim.api.nvim_exec_autocmds("User", {
        pattern = "OpencodeEvent",
        data = response,
      })
    end)

    local on_send_ok, on_send_err = pcall(require("opencode.config").opts.on_send)
    if not on_send_ok then
      vim.notify("Error in `opts.on_send`: " .. on_send_err, vim.log.levels.WARN, { title = "opencode" })
    end

    require("opencode.client").tui_clear_prompt(result, function()
      require("opencode.client").tui_append_prompt(prompt, result, function()
        require("opencode.client").tui_submit_prompt(result, function()
          --
        end)
      end)
    end)
  end)
end

---Send a command to opencode.
---See https://opencode.ai/docs/keybinds/ for available commands.
---@param command string
function M.command(command)
  require("opencode.server").get_port(function(ok, result)
    if not ok then
      vim.notify(result, vim.log.levels.ERROR, { title = "opencode" })
      return
    end

    -- No need to register SSE or auto_reload here - commands trigger neither
    -- (except maybe the `input_*` commands? but no reason for user to use those).

    local on_send_ok, on_send_err = pcall(require("opencode.config").opts.on_send)
    if not on_send_ok then
      vim.notify("Error in `opts.on_send`: " .. on_send_err, vim.log.levels.WARN, { title = "opencode" })
    end

    require("opencode.client").tui_execute_command(command, result)
  end)
end

---Input a prompt to send to opencode.
---
--- - Highlights `opts.contexts` placeholders in the input.
--- - Offers completions for `opts.contexts` placeholders.
---   - Press `<Tab>` or `<C-x><C-o>` to trigger built-in completion (requires `snacks.input`).
---   - Registers `opts.auto_register_cmp_sources` when using `snacks.input` and `blink.cmp`.
---@param default? string Text to prefill the input with.
function M.ask(default)
  require("opencode.input").input(default, function(value)
    if value and value ~= "" then
      M.prompt(value)
    end
  end)
end

---Select a prompt from `opts.prompts` to send to opencode.
---
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

---Toggle embedded opencode.
---Requires `snacks.terminal`.
function M.toggle()
  local ok, err = pcall(require("opencode.terminal").toggle)
  if not ok then
    ---@cast err string
    vim.notify(err, vim.log.levels.ERROR, { title = "opencode" })
  end
end

return M
