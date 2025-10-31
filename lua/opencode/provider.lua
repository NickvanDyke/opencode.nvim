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
---@field enabled? "snacks"|false
---
---@field snacks? opencode.provider.Snacks

---Provide an embedded `opencode` via [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@class opencode.provider.Snacks : opencode.Provider, snacks.terminal.Opts

local M = {}

---@type opencode.Provider|nil
local provider
local provider_or_opts = require("opencode.config").opts.provider
if provider_or_opts and (provider_or_opts.toggle or provider_or_opts.start or provider_or_opts.show) then
  -- An implementation was passed.
  -- Be careful: `provider.enabled` may still exist from merging with defaults.
  ---@cast provider_or_opts opencode.Provider
  provider = provider_or_opts
elseif provider_or_opts and provider_or_opts.enabled then
  -- Resolve the built-in provider.
  -- Retains the base `cmd` if not overridden to deduplicate necessary config.
  provider = provider_or_opts[provider_or_opts.enabled]
  provider.cmd = provider.cmd or provider_or_opts.cmd
end

-- Auto-add `--port <port>` to `provider.cmd` if set and not already present.
local port = require("opencode.config").opts.port
if port and provider and provider.cmd and not provider.cmd:find("--port") then
  provider.cmd = provider.cmd .. " --port " .. tostring(port)
end

local started = false

---Toggle `opencode` via `opts.provider`.
function M.toggle()
  if provider and provider.toggle then
    provider:toggle()
    started = true
  else
    vim.notify(
      "No `provider.toggle` available — configure `vim.g.opencode_opts.provider`, or install `snacks.nvim` to use the default provider",
      vim.log.levels.ERROR,
      { title = "opencode" }
    )
  end
end

---Start `opencode` via `opts.provider`.
function M.start()
  if provider and provider.start then
    provider:start()
    started = true
  else
    vim.notify(
      "No `provider.start` available — start `opencode` yourself, or configure `vim.g.opencode_opts.provider`, or install `snacks.nvim` to use the default provider",
      vim.log.levels.ERROR,
      { title = "opencode" }
    )
  end
end

---Show `opencode` via `opts.provider`.
--- Only called if `provider.toggle` or `provider.start` was previously called.
function M.show()
  if provider and provider.show and started then
    provider:show()
  else
    -- no-op - this is more of a preference than a requirement.
  end
end

return M
