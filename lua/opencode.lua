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

---Send a prompt to `opencode`.
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
    require("opencode.async").chain_async({
      function(next)
        if opts.clear == true then
          require("opencode.client").tui_clear_prompt(port, next)
        else
          next()
        end
      end,
      function(next)
        if opts.append == true and prompt ~= nil then
          prompt = require("opencode.context").inject(prompt)
          require("opencode.client").tui_append_prompt(prompt, port, next)
        else
          next()
        end
      end,
      function(_)
        if opts.submit == true then
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

          require("opencode.client").tui_submit_prompt(port)
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
--- - Completes `opts.contexts` placeholders when using `snacks.input`.
---   - Press `<Tab>` or `<C-x><C-o>` to trigger built-in completion.
---   - Registers `opts.auto_register_cmp_sources` with `blink.cmp`.
---
---@param default? string Text to prefill the input with.
---@param opts? opencode.prompt.Opts
function M.ask(default, opts)
  require("opencode.ask").input(default, function(value)
    if value and value ~= "" then
      M.prompt(value, opts)
    end
  end)
end

---Select a prompt from `opts.prompts` to send to `opencode`.
---Filters prompts according to the current mode and whether they use the selection context.
function M.select()
  local is_visual = vim.fn.mode():match("[vV\22]")
  ---@type opencode.Context[]
  local selection_placeholders = vim.tbl_filter(function(placeholder)
    -- Rarely relevant, but we check the value rather than the key to allow
    -- users to rename the selection context in their config.
    return require("opencode.config").opts.contexts[placeholder].value == require("opencode.context").visual_selection
  end, vim.tbl_keys(require("opencode.config").opts.contexts))

  ---@type opencode.Prompt[]
  local prompts = vim.tbl_filter(function(prompt)
    local uses_selection = false

    for _, placeholder in ipairs(selection_placeholders) do
      if prompt.prompt:find(placeholder, 1, true) then
        uses_selection = true
        break
      end
    end

    return (is_visual and uses_selection) or (not is_visual and not uses_selection)
  end, vim.tbl_values(require("opencode.config").opts.prompts))

  -- Sort keyed `opts.prompts` table for consistency, and prioritize ones that trigger `ask()`.
  table.sort(prompts, function(a, b)
    if a.ask and not b.ask then
      return true
    elseif not a.ask and b.ask then
      return false
    else
      return a.description < b.description
    end
  end)

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
