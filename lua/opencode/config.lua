local M = {}

---@module 'snacks.input'
---@module 'snacks.terminal'

---@class opencode.Opts
---@field port? number The port opencode is running on. If `nil`, searches for an opencode process inside Neovim's CWD (requires `lsof` to be installed on your system). The embedded terminal will automatically use this; launch external processes with `opencode --port <port>`.
---@field auto_reload? boolean Automatically reload buffers edited by opencode in real-time. Requires `vim.opt.autoread = true`.
---@field auto_register_cmp_sources? string[] Completion sources to automatically register with [blink.cmp](https://github.com/Saghen/blink.cmp) (if loaded) in the `ask` input.
---@field on_opencode_not_found? fun(): boolean Called when no opencode process is found. Return `true` if opencode was started and the plugin should try again.
---@field on_send? fun() Called when a prompt or command is sent to opencode.
---@field prompts? table<string, opencode.Prompt> Prompts to select from.
---@field contexts? table<string, opencode.Context> Contexts to inject into prompts.
---@field input? snacks.input.Opts Input options for `ask` — see [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md) (if enabled).
---@field terminal? snacks.terminal.Opts Embedded terminal options — see [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
local defaults = {
  port = nil,
  auto_reload = true,
  auto_register_cmp_sources = { "opencode", "buffer" },
  on_opencode_not_found = function()
    -- Default experience prioritizes embedded snacks.terminal,
    -- but you could also e.g. call a different terminal plugin, launch an external opencode, or no-op.
    local ok, result = pcall(require("opencode.terminal").open)
    if not ok then
      -- Swallow error so users can safely exclude snacks.nvim dependency without overriding this function.
      -- Could accidentally hide an unexpected error in snacks.terminal, but seems unlikely.
      return false
    elseif not result then
      vim.notify("Failed to auto-open embedded opencode terminal", vim.log.levels.ERROR, { title = "opencode" })
    end
    return result
  end,
  on_send = function()
    -- "if exists" because user may alternate between embedded and external opencode.
    -- `opts.on_opencode_not_found` comments also apply here.
    pcall(require("opencode.terminal").show_if_exists)
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
    review_buffer = {
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
    ["@grapple"] = { description = "Grapple tags", value = require("opencode.context").grapple_tags },
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
      col = 0, -- Align with the cursor
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
    win = {
      -- "right" seems like a better default than snacks.terminal's "float" default...
      position = "right",
      -- Stay in the editor after opening the terminal
      enter = false,
      wo = {
        -- Title is unnecessary - opencode TUI has its own footer
        winbar = "",
      },
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
