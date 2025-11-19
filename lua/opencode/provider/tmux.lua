---Provide `opencode` in a `tmux` pane in the current window.
---Works only in Unix systems.
---@class opencode.provider.Tmux : opencode.Provider
---
---@field opts opencode.provider.tmux.Opts
---@field pane_id? string The tmux pane ID where `opencode` is running (internal use only).
local Tmux = {}
Tmux.__index = Tmux

Tmux.name = "tmux"

---@class opencode.provider.tmux.Opts
---
---`tmux` options for creating the pane.
---@field options? string

---@param opts? opencode.provider.tmux.Opts
---@return opencode.provider.Tmux
function Tmux.new(opts)
  local self = setmetatable({}, Tmux)
  self.opts = opts or {}
  self.pane_id = nil
  return self
end

---Check if `tmux` is running in current terminal.
function Tmux.health()
  if not vim.fn.has("unix") then
    return "Not running inside a Unix system."
  end

  if vim.fn.executable("tmux") ~= 1 then
    return "`tmux` executable not found in `$PATH`.", {
      "Install `tmux` and ensure it's in your `$PATH`.",
    }
  end

  if not vim.env.TMUX then
    return "Not running inside a `tmux` session.", {
      "Launch Neovim inside a `tmux` session.",
    }
  end

  return true
end

---Get the pane ID where `opencode` is running.
---@return string|nil pane_id The tmux pane ID
function Tmux:get_pane_id()
  local ok = self.health()
  if ok ~= true then
    error(ok)
  end

  if self.pane_id then
    -- Confirm it still exists
    if vim.fn.system("tmux list-panes -t " .. self.pane_id):match("can't find pane") then
      self.pane_id = nil
    end
  else
    -- Find existing `opencode` pane
    self.pane_id = vim.fn
      .system(
        string.format(
          "tmux list-panes -F '#{pane_id} #{pane_current_command}' | grep '%s' | awk '{print $1}'",
          self.cmd
        )
      )
      :match("^%S+")
  end

  return self.pane_id
end

---Create or kill the `opencode` tmux pane.
function Tmux:toggle()
  local pane_id = self:get_pane_id()
  if pane_id then
    self:stop()
  else
    self:start()
  end
end

---Start `opencode` in tmux pane.
function Tmux:start()
  local pane_id = self:get_pane_id()
  if not pane_id then
    -- Create new pane
    local tmux_cmd = string.format("tmux split-window -d -P -F '#{pane_id}' %s '%s'", self.opts.options, self.cmd)
    self.pane_id = vim.fn.system(tmux_cmd)
  end
end

---Kill the `opencode` pane.
function Tmux:stop()
  local pane_id = self:get_pane_id()
  if pane_id then
    vim.fn.system("tmux kill-pane -t " .. pane_id)
    self.pane_id = nil
  end
end

---No-op for tmux - too many different implementations that may conflict with user's preferences.
function Tmux:show() end

return Tmux
