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
---Input options for `ask` — see also [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md) (if enabled).
---@field input? snacks.input.Opts
---
---Embedded terminal options — see also [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@field terminal? opencode.Opts.terminal
---
---Called when no `opencode` process is found.
---Return `true` if `opencode` was started and the plugin should try again.
---By default, opens an embedded terminal using [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md) (if available).
---But you could also e.g. call your own terminal plugin, launch an external `opencode`, or no-op.
---@field on_opencode_not_found? fun(): boolean
---
---Called when a prompt or command is sent to `opencode`.
---By default, shows the embedded terminal if it exists.
---@field on_submit? fun()

---@type opencode.Opts
local defaults = {
  port = nil,
  auto_reload = true,
  auto_register_cmp_sources = { "opencode", "buffer" },
  contexts = {
    ---@class opencode.Context
    ---@field description string Description of the context. Shown in completion docs.
    ---@field value fun(): string|nil Function that returns the text that will replace the placeholder.
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
    ---@class opencode.Prompt
    ---@field description string Description of the prompt. Shown in selection menu.
    ---@field prompt string The prompt to send to `opencode`, with placeholders for context like `@cursor`, `@buffer`, etc.
    ---@field ask? boolean Call `ask(prompt)` instead of `prompt(prompt)`. Useful for prompts that expect additional user input.
    ---@field opts? opencode.prompt.Opts Options for sending the prompt.
    ask = {
      -- With an "Ask" item, the select menu can serve as the only entrypoint to all plugin-exclusive functionality, without numerous keymaps.
      description = "Ask…",
      prompt = "",
      ask = true,
      opts = {
        submit = true,
      },
    },
    explain = {
      description = "Explain",
      prompt = "Explain @this and its context",
      opts = {
        submit = true,
      },
    },
    optimize = {
      description = "Optimize",
      prompt = "Optimize @this for performance and readability",
      opts = {
        submit = true,
      },
    },
    document = {
      description = "Document",
      prompt = "Add documentation comments for @this",
      opts = {
        submit = true,
      },
    },
    test = {
      description = "Add tests",
      prompt = "Add tests for @this",
      opts = {
        submit = true,
      },
    },
    review = {
      description = "Review buffer",
      prompt = "Review @buffer for correctness and readability",
      opts = {
        submit = true,
      },
    },
    diagnostics = {
      description = "Explain diagnostics",
      prompt = "Explain @diagnostics",
      opts = {
        submit = true,
      },
    },
    fix = {
      description = "Fix diagnostics",
      prompt = "Fix @diagnostics",
      opts = {
        submit = true,
      },
    },
    diff = {
      description = "Review git diff",
      prompt = "Review the following git diff for correctness and readability:\n@diff",
      opts = {
        submit = true,
      },
    },
    add_buffer = {
      description = "Add buffer",
      prompt = "@buffer",
    },
    add_this = {
      description = "Add this",
      prompt = "@this",
    },
  },
  input = {
    prompt = "Ask opencode: ",
    highlight = require("opencode.ask").highlight,
    -- Options below here only apply to [snacks.input](https://github.com/folke/snacks.nvim/blob/main/docs/input.md).
    icon = "󱚣 ",
    -- Only available when using `snacks.input` - `vim.ui.input` does not support `custom/customlist`.
    -- It's okay to enable simultaneously with `blink.cmp` because those keymaps take priority.
    -- TODO: https://github.com/folke/snacks.nvim/issues/2217
    completion = "customlist,v:lua.require'opencode.cmp.omni'",
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
        require("opencode.ask").setup_completion(win.buf)
        -- `snacks.input` doesn't seem to actually call `opts.highlight`? So highlight its buffer ourselves.
        --  TODO: https://github.com/folke/snacks.nvim/issues/2216
        require("opencode.ask").setup_highlight(win.buf)
      end,
    },
  },
  ---@class opencode.Opts.terminal : snacks.terminal.Opts
  ---@field cmd string The command to run in the embedded terminal. See [here](https://opencode.ai/docs/cli) for options.
  terminal = {
    cmd = "opencode",
    -- This will default to false if `auto_insert` or `start_insert` are set to false.
    -- But it's very confusing if the embedded terminal doesn't exit when `opencode` exits.
    -- So override that.
    auto_close = true,
    win = {
      -- `"right"` seems like a better default than `snacks.terminal`'s `"float"` default
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
    local ok = pcall(require("opencode.terminal").open)
    -- Ignore error so users can safely exclude `snacks.nvim` dependency without overriding this function.
    -- Could incidentally hide an unexpected error in `snacks.terminal`, but seems unlikely.
    return ok
  end,
  on_submit = function()
    -- "if exists" because user may alternate between embedded and external `opencode`.
    -- `opts.on_opencode_not_found` comments also apply here.
    pcall(require("opencode.terminal").show_if_exists)
  end,
}

---@module 'snacks'

---Plugin options, lazily merged from `defaults` and `vim.g.opencode_opts`.
---@type opencode.Opts
M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), vim.g.opencode_opts or {})

return M
