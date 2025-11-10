---@module 'snacks.terminal'

---Provide methods for `opencode.nvim` to conveniently manage `opencode` for you.
---@class opencode.Provider
---
---The command to start `opencode`.
---`opencode.nvim` will append `--port <port>` if not already present and `opts.port` is set.
---@field cmd? string
---
---Toggle the visibility of `opencode`.
---@field toggle? fun(self: opencode.Provider)
---
---Start `opencode`.
---Called when attempting to interact with `opencode` but none was found.
---`opencode.nvim` then polls for a couple seconds waiting for one to appear.
---@field start? fun(self: opencode.Provider)
---
---Show `opencode`.
---Called when a prompt or command is sent to `opencode`.
---Should no-op if `opencode` isn't already running via this provider,
---so as not to interfere with externally managing `opencode`.
---@field show? fun(self: opencode.Provider)

---Configure and enable built-in providers.
---@class opencode.provider.Opts
---
---The built-in provider to use, or `false` for none.
---Defaults to `"snacks"` if `snacks.terminal` is available, else `"tmux"` if in a `tmux` session, else `false`.
---@field enabled? "snacks"|"tmux"|false
---
---@field snacks? opencode.provider.snacks.Opts
---@field tmux? opencode.provider.tmux.Opts

local M = {}

local function subscribe_to_sse()
  require("opencode.cli.server")
    .get_port(false)
    :next(function(port)
      require("opencode.autocmd").subscribe_to_sse(port)
    end)
    :catch(function(err)
      vim.notify("Failed to subscribe to SSE: " .. err, vim.log.levels.WARN)
    end)
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
