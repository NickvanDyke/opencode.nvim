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
---The `"opencode"` source offers completions and previews for contexts and agents.
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
---How to provide an integrated `opencode` when one is not found.
---@field provider? opencode.Provider|opencode.provider.Opts

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
    ["@this"] = function(context) return context:this() end,
    ["@buffer"] = function(context) return context:buffer() end,
    ["@buffers"] = function(context) return context:buffers() end,
    ["@visible"] = function(context) return context:visible_text() end,
    ["@diagnostics"] = function(context) return context:diagnostics() end,
    ["@quickfix"] = function(context) return context:quickfix() end,
    ["@diff"] = function(context) return context:git_diff() end,
    ["@grapple"] = function(context) return context:grapple_tags() end,
  },
  prompts = {
    ask_append = { prompt = "", ask = true }, -- Handy to insert context mid-prompt. Simpler than exposing every context as a prompt by default.
    ask_this = { prompt = "@this: ", ask = true, submit = true },
    diagnostics = { prompt = "Explain @diagnostics", submit = true },
    diff = { prompt = "Review the following git diff for correctness and readability: @diff", submit = true },
    document = { prompt = "Add comments documenting @this", submit = true },
    explain = { prompt = "Explain @this and its context", submit = true },
    fix = { prompt = "Fix @diagnostics", submit = true },
    optimize = { prompt = "Optimize @this for performance and readability", submit = true },
    review = { prompt = "Review @this for correctness and readability", submit = true },
    test = { prompt = "Add tests for @this", submit = true },
  },
  commands = {
    ["session.new"] = "Start a new session",
    ["session.share"] = "Share the current session",
    ["session.interrupt"] = "Interrupt the current session",
    ["session.compact"] = "Compact the current session (reduce context size)",
    ["session.undo"] = "Undo the last action in the current session",
    ["session.redo"] = "Redo the last undone action in the current session",
    ["agent.cycle"] = "Cycle the selected agent",
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
        -- Default to snacks if `snacks.terminal` is available
        return "snacks"
      end
      if vim.env.TMUX then
        -- Default to tmux if inside a tmux session
        return "tmux"
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
    },
    tmux = {
      options = "-h", -- Open in a horizontal split
    },
  },
}

---Plugin options, lazily merged from `defaults` and `vim.g.opencode_opts`.
---@type opencode.Opts
M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), vim.g.opencode_opts or {})

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

---The `opencode` provider resolved from `opts.provider`.
---@type opencode.Provider|nil
M.provider = (function()
  local provider
  local provider_or_opts = M.opts.provider

  if provider_or_opts and (provider_or_opts.toggle or provider_or_opts.start or provider_or_opts.show) then
    -- An implementation was passed.
    -- Be careful: `provider.enabled` may still exist from merging with defaults.
    ---@cast provider_or_opts opencode.Provider
    provider = provider_or_opts
  elseif provider_or_opts and provider_or_opts.enabled then
    -- Resolve the built-in provider.
    ---@type boolean, opencode.provider.Snacks|opencode.provider.Tmux
    local ok, resolved_provider = pcall(require, "opencode.provider." .. provider_or_opts.enabled)
    if not ok then
      vim.notify(
        "Failed to load `opencode` provider '" .. provider_or_opts.enabled .. "': " .. resolved_provider,
        vim.log.levels.ERROR,
        { title = "opencode" }
      )
      return nil
    end

    local resolver_provider_opts = provider_or_opts[provider_or_opts.enabled]
    provider = resolved_provider.new(resolver_provider_opts)
    -- Retain the base `cmd` if not overridden.
    provider.cmd = provider.cmd or provider_or_opts.cmd
  end

  -- Auto-add `--port <port>` to `provider.cmd` if set and not already present.
  local port = M.opts.port
  if port and provider and provider.cmd and not provider.cmd:find("--port") then
    provider.cmd = provider.cmd .. " --port " .. tostring(port)
  end

  return provider
end)()

return M
