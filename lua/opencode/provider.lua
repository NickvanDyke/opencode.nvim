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
---@field tmux? opencode.provider.Tmux

---Provide an embedded `opencode` via [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@class opencode.provider.Snacks : opencode.Provider, snacks.terminal.Opts

---Provide an opencode instance in a tmux pane (works only in Unix systems).
---@class opencode.provider.Tmux : opencode.Provider
---
---@field options? string Tmux options to use when creating the pane. Defaults to `-h`, which creates a horizontal split.
---@field pane_id? string The tmux pane ID where opencode is running (internal use only)
local Tmux = {}
Tmux.__index = Tmux

---Create a new Tmux provider instance
---@param opts? {options?: string} Configuration options
---@return opencode.provider.Tmux
function Tmux.new(opts)
  local self = setmetatable({}, Tmux)
  self.options = opts and opts.options or "-h"
  self.pane_id = nil -- The tmux pane ID where opencode is running
  return self
end

---Check if tmux is running in current terminal
function Tmux:check_tmux()
  if not vim.env.TMUX then
    error("Tmux provider selected but not running inside a tmux session.", 0)
  end

  if not vim.fn.has("unix") then
    error("Tmux provider is only supported on Unix-like systems.", 0)
  end
end

---Get the pane ID where opencode is running
---@return string|nil pane_id The tmux pane ID
function Tmux:get_pane_id()
  if self.pane_id then
    local pane_found = vim.fn.system("tmux list-panes -t " .. self.pane_id)
    if pane_found:match("can't find pane") then
      self.pane_id = nil
    end
    return self.pane_id
  end

  -- Find existing opencode pane
  local find_cmd =
    string.format("tmux list-panes -F '#{pane_id} #{pane_current_command}' | grep '%s' | awk '{print $1}'", self.cmd)
  local result = vim.fn.system(find_cmd):match("^%S+")

  if result then
    self.pane_id = result
  end

  return result
end

---Toggle opencode in tmux pane
function Tmux:toggle()
  self:check_tmux()

  local pane_id = self:get_pane_id()
  if pane_id then
    -- Kill existing pane
    vim.fn.system("tmux kill-pane -t " .. pane_id)
    self.pane_id = nil
  else
    -- Create new pane
    local tmux_cmd = string.format("tmux split-window -P -F '#{pane_id}' %s '%s'", self.options, self.cmd)
    self.pane_id = vim.fn.system(tmux_cmd)
  end
end

---Start opencode in tmux pane
function Tmux:start()
  self:check_tmux()

  local pane_id = self:get_pane_id()
  if not pane_id then
    -- Create new pane
    local tmux_cmd = string.format("tmux split-window -d -P -F '#{pane_id}' %s '%s'", self.options, self.cmd)
    self.pane_id = vim.fn.system(tmux_cmd)
  end
end

---Show opencode pane (no-op for tmux)
function Tmux:show() end

local M = {}

-- Export Tmux class for external use
M.Tmux = Tmux

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
