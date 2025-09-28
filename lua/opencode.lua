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

---@param steps { cond: boolean, fn: fun(cb: fun()) }[]
---@param i? number
local function chain_conditional_async(steps, i)
  i = i or 1
  local step = steps[i]
  if not step then
    return
  end
  if step.cond then
    step.fn(function()
      chain_conditional_async(steps, i + 1)
    end)
  else
    chain_conditional_async(steps, i + 1)
  end
end

---@deprecated Pass options via `vim.g.opencode_opts` instead. See [README](https://github.com/NickvanDyke/opencode.nvim) for example.
---
---@param opts opencode.Opts
function M.setup(opts)
  vim.g.opencode_opts = opts
  vim.notify(
    "`opencode.setup()` is deprecated — pass options via `vim.g.opencode_opts` instead. See [README](https://github.com/NickvanDyke/opencode.nvim) for example.",
    vim.log.levels.WARN,
    { title = "opencode" }
  )
end

---@class opencode.prompt.Opts
---@field clear? boolean Clear the TUI input.
---@field append? boolean Append to the TUI input.
---@field submit? boolean Submit the TUI input.

---Prompt `opencode`.
---
---By default, clears the TUI's prompt input, appends `prompt`, and submits it — use `opts` to execute only specific steps.
---
---Before appending:
---1. Injects `opts.contexts` into `prompt`.
---
---Before submitting:
---1. Sets up `opts.auto_reload` if enabled.
---2. Calls `opts.on_submit`.
---3. Listens for SSEs from `opencode` to forward as `OpencodeEvent` autocmd.
---
---@param prompt? string
---@param opts? opencode.prompt.Opts
function M.prompt(prompt, opts)
  -- When *any* `opts` are passed, we don't default the rest so the
  -- user can intuitively pass positives rather than negatives.
  opts = opts or {
    clear = true,
    append = true,
    submit = true,
  }

  get_port(function(port)
    chain_conditional_async({
      {
        cond = opts.clear == true,
        fn = function(cb)
          require("opencode.client").tui_clear_prompt(port, cb)
        end,
      },
      {
        cond = opts.append == true and prompt ~= nil,
        fn = function(cb)
          ---@cast prompt string
          prompt = require("opencode.context").inject(prompt)
          require("opencode.client").tui_append_prompt(prompt, port, cb)
        end,
      },
      {
        cond = opts.submit == true,
        fn = function(cb)
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
            vim.notify("Error in `opts.on_submit`: " .. on_submit_err, vim.log.levels.WARN, { title = "opencode" })
          end

          require("opencode.client").tui_submit_prompt(port, cb)
        end,
      },
    })
  end)
end

---Send a command to `opencode`.
---See https://opencode.ai/docs/keybinds/ for available commands.
---
---@param command string
---@param callback fun(response: table)|nil
function M.command(command, callback)
  get_port(function(port)
    -- No need to register SSE or auto_reload here - commands trigger neither
    -- (except maybe the `input_*` commands? but no reason for user to use those).

    local on_submit_ok, on_submit_err = pcall(require("opencode.config").opts.on_submit)
    if not on_submit_ok then
      vim.notify("Error in `opts.on_submit`: " .. on_submit_err, vim.log.levels.WARN, { title = "opencode" })
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
---
---@param default? string Text to prefill the input with.
---@param opts? opencode.prompt.Opts
function M.ask(default, opts)
  require("opencode.input").input(default, function(value)
    if value and value ~= "" then
      M.prompt(value, opts)
    end
  end)
end

---Select a prompt from `opts.prompts` to send to `opencode`.
---Filters prompts according to whether they use `@selection` and whether we're in visual mode.
function M.select()
  ---@type opencode.Prompt[]
  local prompts = vim.tbl_filter(function(prompt)
    -- WARNING: Technically depends on user using built-in `@selection` context by name...
    -- Could compare function references? Or add `visual = true/false` to contexts objects.
    -- Probably more trouble than it's worth.
    local is_visual = vim.fn.mode():match("[vV\22]")
    local does_prompt_use_visual = prompt.prompt:match("@selection")
    if is_visual then
      return does_prompt_use_visual
    else
      return not does_prompt_use_visual
    end
  end, vim.tbl_values(require("opencode.config").opts.prompts))

  -- TODO: Ideally order should be stable. Seems to change on every nvim start.
  vim.ui.select(
    prompts,
    {
      prompt = "Prompt opencode: ",
      format_item = function(item)
        return item.description
      end,
    },
    ---@param choice opencode.Prompt|nil
    function(choice)
      if choice then
        if choice.ask then
          M.ask(choice.prompt, choice.opts)
        else
          M.prompt(choice.prompt, choice.opts)
        end
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
