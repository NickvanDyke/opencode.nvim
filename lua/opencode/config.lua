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
---Launch `opencode` with `--port <port>` when this is set (the embedded terminal will automatically do so).
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
---Provide methods for `opencode.nvim` to toggle, start, and show `opencode` at appropriate times.
---Only for convenience — you can ignore this field and manually manage your own `opencode`.
---By default, uses an embedded terminal via [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md) if available.
---@field provider? opencode.Provider|opencode.Provider.Opts|opencode.Provider.snacks|nil
---
---Terminal options, if using the default `snacks` provider.
---DEPRECATED: Please use `opts.provider = { name = "snacks", opts = { ... } }` instead.
---@field terminal? { cmd: string } : snacks.terminal.Opts

local function is_snacks_terminal_available()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks.config.get("terminal", {}).enabled ~= false
end

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
    buffer = { prompt = "@buffer" },
    this = { prompt = "@this" },
  },
  input = {
    prompt = "Ask opencode: ",
    -- `snacks.input`-only options
    icon = "󱚣 ",
    win = {
      title_pos = "left",
      relative = "cursor",
      row = -3, -- Row above the cursor
      col = 0, -- Align with the cursor
    },
  },
  select = {
    prompt = "Prompt opencode: ",
    snacks = {
      preview = "preview",
      layout = {
        -- preview is hidden by default in `vim.ui.select`
        hidden = {},
      },
    },
  },
  permissions = {
    enabled = true,
    idle_delay_ms = 1000,
  },
  provider = is_snacks_terminal_available()
      and {
        name = "snacks",
        opts = {
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
      }
    or nil,
  terminal = nil,
}

---Plugin options, lazily merged from `defaults` and `vim.g.opencode_opts`.
---@type opencode.Opts
M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), vim.g.opencode_opts or {})

-- Allow removing default `prompts` and `contexts` by setting them to `false` in your user config.
-- Example:
--   prompts = { ask = false } -- removes the default 'ask' prompt
--   contexts = { ['@buffer'] = false } -- removes the default '@buffer' context
-- TODO: Add to type definition
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

-- Migrate deprecated `opts.terminal` to `opts.provider`.
-- TODO: Remove later.
if M.opts.terminal and M.opts.provider and M.opts.provider.name == "snacks" then
  M.opts.provider = {
    name = "snacks",
    opts = vim.tbl_deep_extend("force", M.opts.provider.opts, M.opts.terminal),
  }
  vim.notify(
    '`opts.terminal` is deprecated; please use `opts.provider = { name = "snacks", opts = { ... } }` instead.',
    vim.log.levels.WARN,
    { title = "opencode" }
  )
end

return M
