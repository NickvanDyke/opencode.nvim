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
---Embedded terminal options for `toggle()`.
---Supports [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@field terminal? opencode.terminal.Opts
---
---Called when no `opencode` process is found so you can start it.
---After calling this function, `opencode.nvim` will poll for a couple seconds to see if an `opencode` process appears.
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
  ---@class opencode.permissions.Opts
  ---@field enabled boolean Whether to show permission requests.
  ---@field idle_delay_ms number Amount of user idle time before showing permission requests.
  permissions = {
    enabled = true,
    idle_delay_ms = 1000,
  },
  ---@class opencode.terminal.Opts : snacks.terminal.Opts
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
  ---@param port? number Free port number that `opencode` can use.
  on_opencode_not_found = function(port)
    -- Ignore error so users can safely exclude `snacks.nvim` dependency without overriding this function.
    -- Could incidentally hide an unexpected error in `snacks.terminal`, but seems unlikely.
    local cmd = M.opts.terminal.cmd
    if not cmd:find("--port") then
      cmd = cmd .. " --port " .. tostring(port)
    end
    pcall(require("opencode.terminal").open, cmd)
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

-- Auto-add `--port <port>` to embedded terminal command if set and not already present.
if M.opts.port and not M.opts.terminal.cmd:find("--port") then
  M.opts.terminal.cmd = M.opts.terminal.cmd .. " --port " .. tostring(M.opts.port)
end

return M
