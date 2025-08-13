-- Utility functions for opencode.nvim
-- Provides privacy protection, environment handling, and formatting helpers

local M = {}

---Sanitize a path for display, protecting user privacy
-- Replaces home directory with $HOME and abbreviates intermediate directories
-- Example: "/home/user/work/project/file.lua" -> "$HOME/w/p/file.lua"
---@param path string
---@return string
function M.sanitize_path(path)
  if not path then
    return "nil"
  end
  
  local home = os.getenv("HOME") or os.getenv("USERPROFILE")
  if not home then
    -- If we can't get home dir, just return the basename
    return path:match("([^/\\]+)$") or path
  end
  
  -- Replace home directory with $HOME
  local sanitized = path:gsub("^" .. vim.pesc(home), "$HOME")
  
  -- Split path into parts
  local parts = {}
  for part in sanitized:gmatch("[^/\\]+") do
    table.insert(parts, part)
  end
  
  -- If we have $HOME and other parts, abbreviate intermediate directories
  if #parts > 1 and parts[1] == "$HOME" then
    local result = "$HOME"
    for i = 2, #parts do
      if i == #parts then
        -- Keep the last part (filename/final dir) full
        result = result .. "/" .. parts[i]
      else
        -- Abbreviate intermediate directories to first character
        result = result .. "/" .. parts[i]:sub(1, 1)
      end
    end
    return result
  end
  
  return sanitized
end

---Format a detection attempt result for display
-- Shows success/failure status with optional details
-- Example: format_detection_attempt("lsof", true, "found port 37669") -> "✓ lsof - found port 37669"
---@param method string
---@param success boolean
---@param details string|nil
---@return string
function M.format_detection_attempt(method, success, details)
  local status = success and "✓" or "✗"
  local line = status .. " " .. method
  if details then
    line = line .. " - " .. details
  end
  return line
end

---Format a process info for display with privacy
-- Combines PID, port, and sanitized CWD into readable string
-- Example: format_process_info(1234, 37669, "/home/user/work/project") 
--          -> "PID: 1234, Port: 37669, CWD: $HOME/w/project"
---@param pid number
---@param port number|nil
---@param cwd string|nil
---@return string
function M.format_process_info(pid, port, cwd)
  local info = "PID: " .. pid
  if port then
    info = info .. ", Port: " .. port
  end
  if cwd then
    info = info .. ", CWD: " .. M.sanitize_path(cwd)
  end
  return info
end

---Parse environment variable for port
-- Reads OPENCODE_PORT from environment and validates it
-- Example: OPENCODE_PORT=37669 -> returns 37669
--          OPENCODE_PORT=invalid -> returns nil
---@return number|nil
function M.get_env_port()
  local env_port = os.getenv("OPENCODE_PORT")
  if env_port then
    local port = tonumber(env_port)
    if port and port > 0 and port < 65536 then
      return port
    end
  end
  return nil
end

---Check if debug mode is enabled
-- Checks OPENCODE_DEBUG environment variable
-- Example: OPENCODE_DEBUG=1 -> returns true
--          OPENCODE_DEBUG=true -> returns true
--          (not set) -> returns false
---@return boolean
function M.is_debug_mode()
  local debug_env = os.getenv("OPENCODE_DEBUG")
  return debug_env == "1" or debug_env == "true"
end

return M