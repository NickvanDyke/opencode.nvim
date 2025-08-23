local M = {}

local function cmd()
  local port = require("opencode.config").opts.port
  return "opencode" .. (port and (" --port " .. port) or "")
end

local function safe_snacks_terminal()
  local is_available, snacks_terminal = pcall(require, "snacks.terminal")
  if not is_available then
    error("Please install snacks.nvim to use the embedded opencode terminal", 0)
  end
  return snacks_terminal
end

function M.toggle()
  safe_snacks_terminal().toggle(cmd(), require("opencode.config").opts.terminal)
end

---Open an embedded opencode terminal.
---Returns whether the terminal was successfully opened.
---@return boolean
function M.open()
  -- We use `get`, not `open`, so that `toggle` will reference the same terminal
  local win = safe_snacks_terminal().get(cmd(), require("opencode.config").opts.terminal)
  return win ~= nil
end

function M.show_if_exists()
  local win = safe_snacks_terminal().get(
    cmd(),
    vim.tbl_deep_extend("force", require("opencode.config").opts.terminal, { create = false })
  )
  if win then
    win:show()
  end
end

return M
