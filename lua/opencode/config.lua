---@module 'snacks'

local M = {}

---Your `opencode.nvim` configuration.
---Passed via global variable for [simpler UX and faster startup](https://mrcjkb.dev/posts/2023-08-22-setup.html).
---@type opencode.Opts|nil
vim.g.opencode_opts = vim.g.opencode_opts

---@class opencode.Opts
---
---The port `opencode` is running on.
---If `nil`, searches for an `opencode` process inside Neovim's CWD (requires `lsof` to be installed on your system).
---Recommend launching `opencode` with `--port <port>` when setting this.
---@field port? number
---
---Automatically reload buffers edited by `opencode` in real-time.
---Requires `vim.opt.autoread = true`.
---@field auto_reload? boolean
---
---Completion sources to automatically register in the `ask` input with [blink.cmp](https://github.com/Saghen/blink.cmp) (if available).
---The `"opencode"` source offers completions and previews for contexts.
---Only possible when using [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md).
---@field auto_register_cmp_sources? string[]
---
---Contexts to inject into prompts, keyed by their placeholder.
---@field contexts? table<string, opencode.Context>
---
---Prompts to select from.
---@field prompts? table<string, opencode.Prompt>
---
---Input options for `ask()` — see also [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md) (if enabled).
---@field input? snacks.input.Opts
---
---Select options for `select()` — see also [snacks.picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md) (if enabled).
---@field select? snacks.picker.ui_select.Opts
---
---Embedded terminal options for `toggle()` — see also [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@field terminal? opencode.Opts.terminal
---
---Called when no `opencode` process is found.
---After calling this function, `opencode.nvim` will poll for a couple seconds to see if a process appears.
---By default, opens an embedded terminal using [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md) (if available).
---But you could also e.g. call your own terminal plugin, launch an external `opencode`, or no-op.
---@field on_opencode_not_found? fun()
---
---Called when a prompt or command is sent to `opencode`.
---By default, shows the embedded terminal if it exists.
---@field on_send? fun()

---@type opencode.Opts
local defaults = {
  port = nil,
  auto_reload = true,
  auto_register_cmp_sources = { "opencode", "buffer" },
  contexts = {
    ["@buffer"] = { description = "Current buffer", value = require("opencode.context").buffer },
    ["@buffers"] = { description = "Open buffers", value = require("opencode.context").buffers },
    ["@cursor"] = { description = "Cursor position", value = require("opencode.context").cursor_position },
    ["@selection"] = { description = "Visual selection", value = require("opencode.context").visual_selection },
    ["@this"] = {
      description = "Visual selection if any, else cursor position",
      value = require("opencode.context").this,
    },
    ["@visible"] = { description = "Visible text", value = require("opencode.context").visible_text },
    ["@diagnostics"] = { description = "Current buffer diagnostics", value = require("opencode.context").diagnostics },
    ["@quickfix"] = { description = "Quickfix list", value = require("opencode.context").quickfix },
    ["@diff"] = { description = "Git diff", value = require("opencode.context").git_diff },
    ["@grapple"] = { description = "Grapple tags", value = require("opencode.context").grapple_tags },
  },
  prompts = {
    -- With an "Ask" item, the select menu can serve as the only entrypoint to all plugin-exclusive functionality, without numerous keymaps.
    ask = { prompt = "", ask = true, submit = true },
    explain = { prompt = "Explain @this and its context", submit = true },
    optimize = { prompt = "Optimize @this for performance and readability", submit = true },
    document = { prompt = "Add comments documenting @this", submit = true },
    test = { prompt = "Add tests for @this", submit = true },
    review = { prompt = "Review @this for correctness and readability", submit = true },
    diagnostics = { prompt = "Explain @diagnostics", submit = true },
    fix = { prompt = "Fix @diagnostics", submit = true },
    diff = { prompt = "Review the following git diff for correctness and readability: @diff", submit = true },
    add_buffer = { prompt = "@buffer" },
    add_this = { prompt = "@this" },
  },
  input = {
    prompt = "Ask opencode: ",
    -- `snacks.input`-only options
    icon = "󱚣",
    win = {
      title_pos = "left",
      relative = "cursor",
      row = -3, -- Row above the cursor
      col = 0, -- Align with the cursor
    },
  },
  select = {
    prompt = "Prompt opencode: ",
    -- `snacks.picker`-only options
    picker = {
      preview = "preview",
      layout = {
        ---@diagnostic disable-next-line: assign-type-mismatch
        preview = true,
      },
    },
  },
  ---@class opencode.Opts.terminal : snacks.terminal.Opts
  ---@field cmd string The command to run in the embedded terminal. See [here](https://opencode.ai/docs/cli) for options.
  terminal = {
    cmd = "opencode",
    -- Close the terminal when `opencode` exits
    auto_close = true,
    win = {
      position = "right",
      -- Stay in the editor after opening the terminal
      enter = false,
      wo = {
        -- Title is unnecessary - `opencode` TUI has its own footer
        winbar = "",
      },
      bo = {
        -- Make it easier to target for customization, and prevent possibly unintended `"snacks_terminal"` targeting.
        -- e.g. the recommended edgy.nvim integration puts all `"snacks_terminal"` windows at the bottom.
        filetype = "opencode_terminal",
      },
    },
    env = {
      -- Other themes have visual bugs in embedded terminals: https://github.com/sst/opencode/issues/445
      OPENCODE_THEME = "system",
    },
  },
  on_opencode_not_found = function()
    -- Ignore error so users can safely exclude `snacks.nvim` dependency without overriding this function.
    -- Could incidentally hide an unexpected error in `snacks.terminal`, but seems unlikely.
    pcall(require("opencode.terminal").open)
  end,
  on_send = function()
    -- "if exists" because user may alternate between embedded and external `opencode`.
    -- `opts.on_opencode_not_found` comments also apply here.
    pcall(require("opencode.terminal").show_if_exists)
  end,
}

---Plugin options, lazily merged from `defaults` and `vim.g.opencode_opts`.
---@type opencode.Opts
M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), vim.g.opencode_opts or {})

-- Allow removing default `prompts` and `contexts` by setting them to `false` in your user config.
-- Example:
--   prompts = { ask = false } -- removes the default 'ask' prompt
--   contexts = { ['@buffer'] = false } -- removes the default '@buffer' context
local user_opts = vim.g.opencode_opts or {}
for _, field in ipairs({ "prompts", "contexts" }) do
  if user_opts[field] and M.opts[field] then
    for k, v in pairs(user_opts[field]) do
      if not v then
        M.opts[field][k] = nil
      end
    end
  end
end

return M
