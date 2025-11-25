---@module 'snacks.terminal'

---Provide an integrated `opencode`.
---@class opencode.Provider
---
---The name of the provider.
---@field name? string
---
---The command to start `opencode`.
---`opencode.nvim` will append `--port <port>` if not already present and `opts.port` is set.
---@field cmd? string
---
---Toggle `opencode`.
---@field toggle? fun(self: opencode.Provider)
---
---Start `opencode`.
---Called when attempting to interact with `opencode` but none was found.
---`opencode.nvim` then polls for a couple seconds waiting for one to appear.
---@field start? fun(self: opencode.Provider)
---
---Stop `opencode`.
---Called when Neovim is exiting.
---@field stop? fun(self: opencode.Provider)
---
---Show `opencode`.
---Called when a prompt or command is sent to `opencode`.
---Should no-op if `opencode` isn't already running via this provider,
---so as not to interfere with externally managing `opencode`.
---@field show? fun(self: opencode.Provider)
---
---Health check for the provider.
---Should return `true` if the provider is available,
---else an error string and optional advice (for `vim.health.warn`).
---@field health? fun(): boolean|string, ...string|string[]

---Configure and enable built-in providers.
---@class opencode.provider.Opts
---
---The built-in provider to use, or `false` for none.
---Default order:
---  - `"snacks"` if `snacks.terminal` is available and enabled
---  - `"kitty"` if in a `kitty` session with remote control enabled
---  - `"tmux"` if in a `tmux` session
---  - `false`
---@field enabled? "snacks"|"kitty"|"tmux"|false
---
---@field snacks? opencode.provider.snacks.Opts
---@field kitty? opencode.provider.kitty.Opts
---@field tmux? opencode.provider.tmux.Opts

local M = {}

local function subscribe_to_sse()
  if not require("opencode.config").opts.events.enabled then
    return
  end

  require("opencode.cli.server")
    .get_port(false)
    :next(function(port)
      require("opencode.events").subscribe_to_sse(port)
    end)
    :catch(function(err)
      vim.notify("Failed to subscribe to SSE: " .. err, vim.log.levels.WARN)
    end)
end

---Get all providers.
---@return opencode.Provider[]
function M.list()
  return {
    require("opencode.provider.snacks"),
    require("opencode.provider.kitty"),
    require("opencode.provider.tmux"),
  }
end

---Toggle `opencode` via the configured provider.
function M.toggle()
  local provider = require("opencode.config").provider
  if provider and provider.toggle then
    provider:toggle()
    subscribe_to_sse()
  else
    error("`provider.toggle` unavailable — run `:checkhealth opencode` for details", 0)
  end
end

---Start `opencode` via the configured provider.
function M.start()
  local provider = require("opencode.config").provider
  if provider and provider.start then
    provider:start()
    subscribe_to_sse()
  else
    error("`provider.start` unavailable — run `:checkhealth opencode` for details", 0)
  end
end

---Stop `opencode` via the configured provider.
function M.stop()
  local provider = require("opencode.config").provider
  if provider and provider.stop then
    provider:stop()
  else
    error("`provider.stop` unavailable — run `:checkhealth opencode` for details", 0)
  end
end

---Show `opencode` via the configured provider.
function M.show()
  local provider = require("opencode.config").provider
  if provider and provider.show then
    provider:show()
  else
    error("`provider.show` unavailable — run `:checkhealth opencode` for details", 0)
  end
end

return M
