---@module 'snacks'

local M = {}

---Your `opencode.nvim` configuration.
---Passed via global variable for [simpler UX and faster startup](https://mrcjkb.dev/posts/2023-08-22-setup.html).
---
---Note that Neovim does not yet support metatables or mixed integer and string keys in `vim.g`, affecting some `snacks.nvim` options.
---In that case you may modify `require("opencode.config").opts` directly.
---See [opencode.nvim #36](https://github.com/NickvanDyke/opencode.nvim/issues/36) and [neovim #12544](https://github.com/neovim/neovim/issues/12544#issuecomment-1116794687).
---@type opencode.Opts|nil
vim.g.opencode_opts = vim.g.opencode_opts

---@class opencode.Opts
---
---The port `opencode` is running on.
---If `nil`, searches for an `opencode` process inside Neovim's CWD (requires `lsof` to be installed on your system).
---If set, `opencode.nvim` will append `--port <port>` to `provider.cmd` if not already present.
---@field port? number
---
---Reload buffers edited by `opencode` in real-time.
---Requires `vim.o.autoread = true`.
---@field auto_reload? boolean
---
---Completion sources to automatically register in the `ask` input with [blink.cmp](https://github.com/Saghen/blink.cmp) and [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md).
---The `"opencode"` source offers completions and previews for contexts.
---@field auto_register_cmp_sources? string[]
---
---Contexts to inject into prompts, keyed by their placeholder.
---@field contexts? table<string, fun(context: opencode.Context): string|nil>
---
---Prompts to select from.
---@field prompts? table<string, opencode.Prompt>
---
---Commands to select from.
---@field commands? table<string, opencode.Command|string>
---
---Input options for `ask()`.
---Supports [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md).
---@field input? snacks.input.Opts
---
---Select options for `select()`.
---Supports [snacks.picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md).
---@field select? snacks.picker.ui_select.Opts
---
---Options for `opencode` permission requests.
---@field permissions? opencode.permissions.Opts
---
---Provide methods for `opencode.nvim` to toggle, start, and show `opencode`.
---Only for convenience/integration — you can ignore this field and manually manage your own `opencode`.
---@field provider? opencode.Provider|opencode.provider.Opts
---
---DEPRECATED: Please use `opts.provider = { name = "snacks", ... }` instead.
---@field terminal? { cmd: string }|snacks.terminal.Opts
---
---DEPRECATED: Please use `opts.provider.start` instead.
---@field on_opencode_not_found? fun()
---
---DEPRECATED: Please use `opts.provider.show` instead.
---@field on_send? fun()

---@class opencode.Prompt : opencode.prompt.Opts
---@field prompt string The prompt to send to `opencode`, with placeholders for context like `@cursor`, `@buffer`, etc.
---@field ask? boolean Call `ask(prompt)` instead of `prompt(prompt)`. Useful for prompts that expect additional user input.

---@type opencode.Opts
local defaults = {
  port = nil,
  auto_reload = true,
  auto_register_cmp_sources = { "opencode", "buffer" },
  -- stylua: ignore
  contexts = {
    ["@buffer"] = function(context) return context:buffer() end,
    ["@buffers"] = function(context) return context:buffers() end,
    ["@cursor"] = function(context) return context:cursor_position() end,
    ["@selection"] = function(context) return context:visual_selection() end,
    ["@this"] = function(context) return context:this() end,
    ["@visible"] = function(context) return context:visible_text() end,
    ["@diagnostics"] = function(context) return context:diagnostics() end,
    ["@quickfix"] = function(context) return context:quickfix() end,
    ["@diff"] = function(context) return context:git_diff() end,
    ["@grapple"] = function(context) return context:grapple_tags() end,
  },
  prompts = {
    ask = { prompt = "", ask = true, submit = true },
    explain = { prompt = "Explain @this and its context", submit = true },
    optimize = { prompt = "Optimize @this for performance and readability", submit = true },
    document = { prompt = "Add comments documenting @this", submit = true },
    test = { prompt = "Add tests for @this", submit = true },
    review = { prompt = "Review @this for correctness and readability", submit = true },
    diagnostics = { prompt = "Explain @diagnostics", submit = true },
    fix = { prompt = "Fix @diagnostics", submit = true },
    diff = { prompt = "Review the following git diff for correctness and readability: @diff", submit = true },
    buffer = { prompt = "@buffer" },
    this = { prompt = "@this" },
  },
  commands = {
    session_new = "Start a new session",
    session_share = "Share the current session",
    session_interrupt = "Interrupt the current session",
    session_compact = "Compact the current session (reduce context size)",
    messages_copy = "Copy the last message in the session",
    messages_undo = "Undo the last message in the session",
    messages_redo = "Redo the last message in the session",
    agent_cycle = "Cycle the selected agent",
  },
  input = {
    prompt = "Ask opencode: ",
    -- `snacks.input`-only options
    icon = "󰚩 ",
    win = {
      title_pos = "left",
      relative = "cursor",
      row = -3, -- Row above the cursor
      col = 0, -- Align with the cursor
    },
  },
  select = {
    prompt = "opencode: ",
    snacks = {
      preview = "preview",
      layout = {
        preset = "vscode",
        hidden = {}, -- preview is hidden by default in `vim.ui.select`
      },
    },
  },
  permissions = {
    enabled = true,
    idle_delay_ms = 1000,
  },
  provider = {
    cmd = "opencode",
    enabled = (function()
      local snacks_ok, snacks = pcall(require, "snacks")
      if snacks_ok and snacks.config.get("terminal", {}).enabled then
        return "snacks"
      end

      return false
    end)(),
    snacks = {
      auto_close = true, -- Close the terminal when `opencode` exits
      win = {
        position = "right",
        enter = false, -- Stay in the editor after opening the terminal
        wo = {
          winbar = "", -- Title is unnecessary - `opencode` TUI has its own footer
        },
        bo = {
          -- Make it easier to target for customization, and prevent possibly unintended `"snacks_terminal"` targeting.
          -- e.g. the recommended edgy.nvim integration puts all `"snacks_terminal"` windows at the bottom.
          filetype = "opencode_terminal",
        },
      },
      env = {
        OPENCODE_THEME = "system", -- HACK: Other themes have visual bugs in embedded terminals: https://github.com/sst/opencode/issues/445
      },
      ---@param self opencode.provider.Snacks
      toggle = function(self)
        require("snacks.terminal").toggle(self.cmd, self)
      end,
      ---@param self opencode.provider.Snacks
      start = function(self)
        require("snacks.terminal").open(self.cmd, self)
      end,
      ---@param self opencode.provider.Snacks
      show = function(self)
        local win = require("snacks.terminal").get(self.cmd, self)
        if win then
          win:show()
        end
      end,
    },
  },
}

---Plugin options, lazily merged from `defaults` and `vim.g.opencode_opts`.
---@type opencode.Opts
M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), vim.g.opencode_opts or {})

-- TODO: Remove later
if M.opts.terminal then
  M.opts.provider.snacks = vim.tbl_deep_extend("force", M.opts.provider.snacks, M.opts.terminal)
  vim.notify(
    '`opts.terminal` has been deprecated; please use `opts.provider = { name = "snacks", snacks = { ... } }` instead.',
    vim.log.levels.WARN,
    { title = "opencode" }
  )
end
if M.opts.on_opencode_not_found then
  M.opts.provider.start = M.opts.on_opencode_not_found
  vim.notify(
    "`opts.on_opencode_not_found` has been deprecated; please use `opts.provider.start` instead.",
    vim.log.levels.WARN,
    { title = "opencode" }
  )
end
if M.opts.on_send then
  M.opts.provider.show = M.opts.on_send
  vim.notify(
    "`opts.on_send` has been deprecated; please use `opts.provider.show` instead.",
    vim.log.levels.WARN,
    { title = "opencode" }
  )
end

-- Allow removing default `contexts`, `prompts`, and `commands` by setting them to `false` in your user config.
-- Example:
--   contexts = { ['@buffer'] = false }
--   prompts = { ask = false }
--   commands = { session_new = false }
-- TODO: Add to type definition
local user_opts = vim.g.opencode_opts or {}
for _, field in ipairs({ "contexts", "prompts", "commands" }) do
  if user_opts[field] and M.opts[field] then
    for k, v in pairs(user_opts[field]) do
      if not v then
        M.opts[field][k] = nil
      end
    end
  end
end

return M
