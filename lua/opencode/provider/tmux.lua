---Configuration options for the tmux provider.
---@class opencode.provider.tmux.Opts
---
---Tmux options to use when creating the pane. Defaults to `-h`, which creates a horizontal split.
---@field options? string

---Provide an opencode instance in a tmux pane (works only in Unix systems).
---@class opencode.provider.Tmux : opencode.Provider
---
---@field options string Tmux options to use when creating the pane. Defaults to `-h`, which creates a horizontal split.
---@field pane_id? string The tmux pane ID where opencode is running (internal use only)
local Tmux = {}
Tmux.__index = Tmux

---Create a new Tmux provider instance
---Upon toggling or starting, this will create a new tmux pane to run opencode, in the current window.
---@param opts opencode.provider.tmux.Opts Configuration options
---@return opencode.provider.Tmux
function Tmux.new(opts)
  local self = setmetatable({}, Tmux)
  self.options = opts.options
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

return {
  Tmux = Tmux,
}
