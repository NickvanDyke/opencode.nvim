---Provide methods for `opencode.nvim` to toggle, start, and show `opencode`.
---@class opencode.Provider
---
---The command to start `opencode`.
---`opencode.nvim` will append `--port <port>` if not already present and `opts.port` is set.
---@field cmd? string
---
---Called by `require("opencode").toggle()`.
---@field toggle? fun(self: opencode.Provider)
---
---Called when sending a prompt or command to `opencode` but no process was found.
---`opencode.nvim` will poll for a couple seconds waiting for one to appear.
---@field start? fun(self: opencode.Provider)
---
---Called when a prompt or command is sent to `opencode`,
---*and* this provider's `toggle` or `start` has previously been called
---(so as to not interfere when `opencode` was started externally).
---@field show? fun(self: opencode.Provider)

---Configure and enable built-in providers.
---@class opencode.provider.Opts
---
---The built-in provider to use, or `false` for none.
---Defaults to [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md) if available.
---@field enabled? "snacks"|"tmux"|false
---
---@field snacks? opencode.provider.Snacks
---@field tmux? opencode.provider.tmux.Opts

---Provide an embedded `opencode` via [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@class opencode.provider.Snacks : opencode.Provider, snacks.terminal.Opts

local M = {}

-- Re-export Tmux class from tmux module
M.Tmux = require("opencode.provider.tmux").Tmux

local started = false

---Toggle `opencode` via `opts.provider`.
function M.toggle()
  local provider = require("opencode.config").provider
  if provider and provider.toggle then
    provider:toggle()
    started = true
  else
    error("No `provider.toggle` available — run `:checkhealth opencode` for details", 0)
  end
end

---Start `opencode` via `opts.provider`.
function M.start()
  local provider = require("opencode.config").provider
  if provider and provider.start then
    provider:start()
    started = true
  else
    error("No `provider.start` available — run `:checkhealth opencode` for details", 0)
  end
end

---Show `opencode` via `opts.provider`,
---if `provider.toggle` or `provider.start` was previously called.
function M.show()
  local provider = require("opencode.config").provider
  if started then
    if provider and provider.show then
      provider:show()
    else
      error("No `provider.show` available — run `:checkhealth opencode` for details", 0)
    end
  end
end

return M
