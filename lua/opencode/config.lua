local M = {}

---@class opencode.Opts
---@field port? number The port opencode's server is running on. If `nil`, searches for an opencode process inside Neovim's CWD — usually you can leave this unset unless that fails. Embedded instances will automatically use this — launch external instances with `opencode --port <port>`.
---@field auto_reload? boolean Automatically reload buffers edited by opencode. Requires `vim.opt.autoread = true`.
---@field auto_register_cmp_sources? string[] Completion sources to automatically register with [blink.cmp](https://github.com/Saghen/blink.cmp) in the `ask` input.
---@field on_opencode_not_found? fun(): boolean Called when no opencode process is found. Return `true` if opencode was started and the plugin should try again.
---@field on_send? fun() Called when a prompt or command is sent to opencode.
---@field prompts? table<string, opencode.Prompt> Prompts to select from.
---@field contexts? table<string, opencode.Context> Contexts to inject into prompts.
---@field input? snacks.input.Opts Input options for `ask` — uses [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md) if enabled.
---@field terminal? snacks.terminal.Opts Embedded terminal options — uses [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
local defaults = {
  port = nil,
  auto_reload = true,
  auto_register_cmp_sources = { "opencode", "buffer" },
  on_opencode_not_found = function()
    -- OOTB experience prioritizes embedded snacks.terminal,
    -- but you could also e.g. utilize a different terminal plugin, launch an external opencode, or no-op.
    local opened = require("opencode.terminal").open()
    if not opened then
      vim.notify("Failed to auto-open embedded opencode terminal", vim.log.levels.ERROR, { title = "opencode" })
    end
    return opened
  end,
  on_send = function()
    -- "if exists" because user may alternate between embedded and external opencode.
    -- `opts.on_opencode_not_found` comment also applies here.
    require("opencode.terminal").show_if_exists()
  end,
  prompts = {
    ---@class opencode.Prompt
    ---@field description? string Description of the prompt, show in selection menu.
    ---@field prompt? string The prompt to send to opencode, with placeholders for context like `@cursor`, `@buffer`, etc.
    explain = {
      description = "Explain code near cursor",
      prompt = "Explain @cursor and its context",
    },
    fix = {
      description = "Fix diagnostics",
      prompt = "Fix these @diagnostics",
    },
    optimize = {
      description = "Optimize selection",
      prompt = "Optimize @selection for performance and readability",
    },
    document = {
      description = "Document selection",
      prompt = "Add documentation comments for @selection",
    },
    test = {
      description = "Add tests for selection",
      prompt = "Add tests for @selection",
    },
    review_file = {
      description = "Review buffer",
      prompt = "Review @buffer for correctness and readability",
    },
    review_diff = {
      description = "Review git diff",
      prompt = "Review the following git diff for correctness and readability:\n@diff",
    },
  },
  contexts = {
    ---@class opencode.Context
    ---@field description? string Description of the context, shown in completion docs.
    ---@field value fun(): string|nil Function that returns the context value for replacement.
    ["@buffer"] = { description = "Current buffer", value = require("opencode.context").buffer },
    ["@buffers"] = { description = "Open buffers", value = require("opencode.context").buffers },
    ["@cursor"] = { description = "Cursor position", value = require("opencode.context").cursor_position },
    ["@selection"] = { description = "Selected text", value = require("opencode.context").visual_selection },
    ["@visible"] = { description = "Visible text", value = require("opencode.context").visible_text },
    ["@diagnostic"] = {
      description = "Current line diagnostics",
      value = function()
        return require("opencode.context").diagnostics(true)
      end,
    },
    ["@diagnostics"] = { description = "Current buffer diagnostics", value = require("opencode.context").diagnostics },
    ["@quickfix"] = { description = "Quickfix list", value = require("opencode.context").quickfix },
    ["@diff"] = { description = "Git diff", value = require("opencode.context").git_diff },
  },
  input = {
    prompt = "Ask opencode: ",
    icon = "󱚣 ",
    -- Built-in completion as fallback.
    -- It's okay to enable simultaneously with blink.cmp because built-in completion
    -- only triggers via <Tab> and blink.cmp keymaps take priority.
    completion = "customlist,v:lua.require'opencode.cmp.omni'",
    win = {
      title_pos = "left",
      relative = "cursor",
      row = -3, -- Row above the cursor
      col = -5, -- Position first input cell directly above the cursor
      b = {
        -- Enable blink completion
        completion = true,
      },
      bo = {
        -- Custom filetype to configure blink with
        filetype = "opencode_ask",
      },
    },
  },
  terminal = {
    -- No reason to prefer normal mode - can't scroll TUI like a normal buffer
    auto_insert = true,
    auto_close = true,
    win = {
      position = "right",
      -- I usually want to `toggle` and then immediately `ask` - seems like a sensible default
      enter = false,
    },
    env = {
      -- Other themes have visual bugs in embedded terminals: https://github.com/sst/opencode/issues/445
      OPENCODE_THEME = "system",
    },
  },
}

---@type opencode.Opts
M.options = vim.deepcopy(defaults)

---@param opts? opencode.Opts
---@return opencode.Opts
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})

  return M.options
end

return M
