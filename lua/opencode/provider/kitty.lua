---Provide `opencode` in a `kitty` terminal instance.
---Requires [kitty remote control](https://sw.kovidgoyal.net/kitty/remote-control/#remote-control-via-a-socket) to be enabled.
---@class opencode.provider.Kitty : opencode.Provider
---
---@field opts opencode.provider.kitty.Opts
---@field window_id? number The `kitty` window ID where `opencode` is running (internal use only).
local Kitty = {}
Kitty.__index = Kitty
Kitty.name = "kitty"

---@class opencode.provider.kitty.Opts
---
---Location where `opencode` instance should be opened.
---Possible values:
--- * https://sw.kovidgoyal.net/kitty/launch/#cmdoption-launch-location
--- * `tab`
--- * `os-window`
---@field location? "after" | "before" | "default" | "first" | "hsplit" | "last" | "neighbor" | "split" | "vsplit" | "tab" | "os-window"
---
---Optional password for `kitty` remote control.
---https://sw.kovidgoyal.net/kitty/remote-control/#cmdoption-kitten-password
---@field password? string
---
---@param opts? opencode.provider.kitty.Opts
---@return opencode.provider.Kitty
function Kitty.new(opts)
  local self = setmetatable({}, Kitty)
  self.opts = vim.tbl_extend("keep", opts or {}, {
    location = "default",
  })
  self.window_id = nil
  return self
end

---Check if `kitty` remote control is available.
function Kitty.health()
  if vim.env.KITTY_LISTEN_ON and #vim.env.KITTY_LISTEN_ON > 0 then
    return true
  else
    return "KITTY_LISTEN_ON environment variable is not set.", "Enable remote control in `kitty`."
  end
end

---Execute a `kitty` remote control command.
---@param args string[] Arguments to pass to kitty @
---@return string|nil output, number|nil code
function Kitty:kitty_exec(args)
  local cmd = { "kitty", "@" }

  -- Add password if configured
  local password = self.opts.password or ""
  if #password > 0 then
    table.insert(cmd, "--password")
    table.insert(cmd, password)
  end

  -- Add the actual command arguments
  for _, arg in ipairs(args) do
    table.insert(cmd, arg)
  end

  local output = vim.fn.system(cmd)
  local code = vim.v.shell_error

  return output, code
end

---Get the `kitty` window ID where `opencode` is running.
---@return number|nil window_id
function Kitty:get_window_id()
  -- Return cached window_id if it still exists
  if self.window_id then
    local _, code = self:kitty_exec({ "ls", "--match", "id:" .. self.window_id })
    if code == 0 then
      return self.window_id -- Window still exists, return the cached ID
    end
    self.window_id = nil -- Window no longer exists
  end

  -- Get all kitty windows and parse JSON
  local output, code = self:kitty_exec({ "ls" })
  if code ~= 0 or not output then
    return nil
  end

  local ok, kitty_info = pcall(vim.json.decode, output)
  if not ok or not kitty_info then
    return nil
  end

  -- Extract base command to search for (e.g., "opencode" from "opencode --some-flag")
  local base_cmd = self.cmd:match("^%S+")

  local location = self.opts.location
  local search_focused_os_window_only = location ~= "os-window"
  local search_focused_tab_only = location ~= "tab" and search_focused_os_window_only

  -- Search for the window running opencode
  for _, client in ipairs(kitty_info) do
    -- Skip non-relevant clients when searching for the process in the same OS window
    if search_focused_os_window_only and not client.is_focused then
      goto continue_client
    end

    for _, tab in ipairs(client.tabs or {}) do
      -- Skip non-relevant tabs when searching for the process in the same tab
      if search_focused_tab_only and not tab.is_focused then
        goto continue_tab
      end

      for _, window in ipairs(tab.windows or {}) do
        for _, process in ipairs(window.foreground_processes or {}) do
          for _, cmd_part in ipairs(process.cmdline or {}) do
            if cmd_part:match(base_cmd) then
              self.window_id = window.id
              return window.id
            end
          end
        end
      end

      ::continue_tab::
    end

    ::continue_client::
  end

  return nil
end

---Toggle `opencode` in window.
function Kitty:toggle()
  local ok, err = self:health()
  if ok ~= true then
    error(err, 0)
  end

  local window_id = self:get_window_id()
  if not window_id then
    -- Create new window
    self:start()
  else
    -- Close existing window
    self:stop()
  end
end

---Start `opencode` in window.
function Kitty:start()
  local ok, err = self:health()
  if ok ~= true then
    error(err, 0)
  end

  local window_id = self:get_window_id()
  if window_id then
    vim.notify("An opencode instance is already running", vim.log.levels.INFO, { title = "opencode" })
    return
  end

  local location = self.opts.location
  local launch_cmd = { "launch", "--cwd=current", "--hold" }

  -- Input validation for `location` option
  local VALID_LOCATIONS = {
    "after",
    "before",
    "default",
    "first",
    "hsplit",
    "last",
    "neighbor",
    "split",
    "vsplit",
    "tab",
    "os-window",
  }

  if not vim.tbl_contains(VALID_LOCATIONS, location) then
    error(string.format("Invalid location '%s' specified", location), 0)
  end

  -- Use `--location` for splits and `--type` for tab and os-window
  if location == "tab" or location == "os-window" then
    table.insert(launch_cmd, "--type=" .. location)
  else
    table.insert(launch_cmd, "--location=" .. location)
  end

  table.insert(launch_cmd, self.cmd)

  local stdout, code = self:kitty_exec(launch_cmd)

  if code == 0 then
    -- The window ID is returned directly in stdout
    self.window_id = tonumber(stdout)
  end
end

---Stop `opencode` window.
function Kitty:stop()
  local window_id = self:get_window_id()
  if window_id then
    local _, code = self:kitty_exec({ "close-window", "--match", "id:" .. window_id })
    if code == 0 then
      self.window_id = nil
    end
  end
end

---Show `opencode` window.
function Kitty:show()
  local window_id = self:get_window_id()
  if not window_id then
    vim.notify("No opencode instance is currently running", vim.log.levels.WARN, { title = "opencode" })
    return
  end

  self:kitty_exec({ "focus-window", "--match", "id:" .. window_id })
end

return Kitty
