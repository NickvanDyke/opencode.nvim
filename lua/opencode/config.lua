local M = {}

---@module 'snacks.input'
---@module 'snacks.terminal'

---Your `opencode.nvim` configuration.
---Passed via global variable for [simpler UX and faster startup](https://mrcjkb.dev/posts/2023-08-22-setup.html).
---@type opencode.Opts|nil
vim.g.opencode_opts = vim.g.opencode_opts

---@class opencode.Opts
---@field port? number The port opencode is running on. If `nil`, searches for an opencode process inside Neovim's CWD (requires `lsof` to be installed on your system). The embedded terminal will automatically use this; launch external processes with `opencode --port <port>`.
---@field auto_reload? boolean Automatically reload buffers edited by opencode in real-time. Requires `vim.opt.autoread = true`.
---@field auto_register_cmp_sources? string[] Completion sources to automatically register with [blink.cmp](https://github.com/Saghen/blink.cmp) (if loaded) in the `ask` input. Only available when using [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md).
---@field contexts? table<string, opencode.Context> Contexts to inject into prompts, keyed by their placeholder.
---@field prompts? table<string, opencode.Prompt> Prompts to select from.
---@field input? snacks.input.Opts Input options for `ask` — see [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md) (if enabled).
---@field terminal? snacks.terminal.Opts Embedded terminal options — see [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@field on_opencode_not_found? fun(): boolean Called when no opencode process is found. Return `true` if opencode was started and the plugin should try again. By default, opens an embedded terminal using [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md) (if available).
---@field on_send? fun() Called when a prompt or command is sent to opencode. By default, shows the embedded terminal if it exists.
local defaults = {
  port = nil,
  auto_reload = true,
  auto_register_cmp_sources = { "opencode", "buffer" },
  contexts = {
    ---@class opencode.Context
    ---@field description string Description of the context. Shown in completion docs.
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
  prompts = {
    ---@class opencode.Prompt
    ---@field description string Description of the prompt. Shown in selection menu.
    ---@field prompt string The prompt to send to opencode, with placeholders for context like `@cursor`, `@buffer`, etc.
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
  input = {
    prompt = "Ask opencode: ",
    icon = "󱚣 ",
    -- Built-in completion - trigger via `<C-x><C-o>` or `<Tab>` in insert mode.
    -- Only available when using `snacks.input` - built-in `vim.ui.input` does not support `omnifunc`.
    -- It's okay to enable simultaneously with `blink.cmp` because those keymaps take priority.
    completion = "customlist,v:lua.require'opencode.cmp.omni'",
    highlight = require("opencode.input").highlight,
    win = {
      title_pos = "left",
      relative = "cursor",
      row = -3, -- Row above the cursor
      col = 0, -- Align with the cursor
      b = {
        -- Enable `blink.cmp` completion
        completion = true,
      },
      bo = {
        -- Custom filetype to enable `blink.cmp` source on
        filetype = "opencode_ask",
      },
      on_buf = function(win)
        -- Wait as long as possible to check for `blink.cmp` loaded - many users lazy-load on `InsertEnter`.
        -- And OptionSet :runtimepath didn't seem to fire for lazy.nvim.
        vim.api.nvim_create_autocmd("InsertEnter", {
          once = true,
          buffer = win.buf,
          callback = function()
            if package.loaded["blink.cmp"] then
              require("opencode.cmp.blink").setup(require("opencode.config").opts.auto_register_cmp_sources)
            end
          end,
        })

        -- `snacks.input` doesn't seem to actually call `opts.highlight`... so highlight its buffer ourselves
        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWinEnter" }, {
          group = vim.api.nvim_create_augroup("OpencodeAskHighlight", { clear = true }),
          buffer = win.buf,
          callback = function(args)
            require("opencode.input").highlight_buffer(args.buf)
          end,
        })
      end,
    },
  },
  terminal = {
    -- This defaults to false when `auto_insert` or `start_insert` are set to false.
    -- But it's very confusing if the embedded terminal doesn't exit when opencode exits.
    -- So always default to true.
    auto_close = true,
    win = {
      -- "right" seems like a better default than `snacks.terminal`'s "float" default
      position = "right",
      -- Stay in the editor after opening the terminal
      enter = false,
      wo = {
        -- Title is unnecessary - opencode TUI has its own footer
        winbar = "",
      },
      bo = {
        -- Make it easier to target for customization, and prevent possibly unintended "snacks_terminal" targeting.
        -- e.g. the recommended edgy.nvim integration puts all "snacks_terminal" windows at the bottom.
        filetype = "opencode_terminal",
      },
    },
    env = {
      -- Other themes have visual bugs in embedded terminals: https://github.com/sst/opencode/issues/445
      OPENCODE_THEME = "system",
    },
  },
  on_opencode_not_found = function()
    -- Default experience prioritizes embedded `snacks.terminal`,
    -- but you could also e.g. call a different terminal plugin, launch an external opencode, or no-op.
    local ok, opened = pcall(require("opencode.terminal").open)
    if not ok then
      -- Discard error so users can safely exclude `snacks.nvim` dependency without overriding this function.
      -- Could incidentally hide an unexpected error in `snacks.terminal`, but seems unlikely.
      return false
    elseif not opened then
      -- `snacks.terminal` is available but failed to open, which we do want to know about.
      error("Failed to auto-open embedded opencode terminal", 0)
    end

    return true
  end,
  on_send = function()
    -- "if exists" because user may alternate between embedded and external opencode.
    -- `opts.on_opencode_not_found` comments also apply here.
    pcall(require("opencode.terminal").show_if_exists)
  end,
}

---@type opencode.Opts
M.opts = vim.deepcopy(defaults)

---@param opts? opencode.Opts
---@return opencode.Opts
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

  return M.opts
end

return M
