---Provide `opencode` in a [`tmux`](https://github.com/tmux/tmux) pane in the current window.
---@class opencode.provider.Tmux : opencode.Provider
---
---@field opts opencode.provider.tmux.Opts
---
---The `tmux` pane ID where `opencode` is running (internal use only).
---@field pane_id? string
---
---Cached port of the `opencode` server (internal use only).
---@field port? number
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
  self.port = nil
  return self
end

---Check if we're running inside a `tmux` session.
function Tmux.health()
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

---Get the `tmux` pane ID where we started `opencode`, if it still exists.
---Ideally we'd find existing panes by title or command, but `tmux` doesn't make that straightforward.
---@return string|nil pane_id
function Tmux:get_pane_id()
  local ok = self.health()
  if ok ~= true then
    error(ok, 0)
  end

  if self.pane_id then
    -- Confirm it still exists
    if vim.fn.system("tmux list-panes -t " .. self.pane_id):match("can't find pane") then
      self.pane_id = nil
    end
  end

  return self.pane_id
end

---Create or kill the `opencode` pane.
function Tmux:toggle()
  local pane_id = self:get_pane_id()
  if pane_id then
    self:stop()
  else
    self:start()
  end
end

---Start `opencode` in pane.
function Tmux:start()
  local pane_id = self:get_pane_id()
  if not pane_id then
    -- Create new pane
    self.pane_id =
      vim.fn.system(string.format("tmux split-window -d -P -F '#{pane_id}' %s '%s'", self.opts.options, self.cmd))
  end
end

---Kill the `opencode` pane.
function Tmux:stop()
  local pane_id = self:get_pane_id()
  if pane_id then
    vim.fn.system("tmux kill-pane -t " .. pane_id)
    self.pane_id = nil
    self.port = nil
  end
end

---Get the PID of the shell process running in the opencode pane.
---@return number|nil pid
function Tmux:get_pane_process_pid()
  local pane_id = self:get_pane_id()
  if not pane_id then
    return nil
  end

  local output = vim.fn.system("tmux list-panes -t " .. pane_id .. " -F '#{pane_pid}'")
  local pid = tonumber(vim.trim(output))
  return pid
end

---Get the port of the opencode server started in this pane.
---Traces from pane PID through descendants to find the listening port.
---Caches the result for subsequent calls.
---@return number|nil port
function Tmux:get_port()
  -- Return cached port if pane still exists
  if self.port and self:get_pane_id() then
    return self.port
  end

  local pane_pid = self:get_pane_process_pid()
  if not pane_pid then
    return nil
  end

  local process = require("opencode.util.process")
  self.port = process.get_descendant_listening_port(pane_pid, 3)
  return self.port
end

return Tmux
