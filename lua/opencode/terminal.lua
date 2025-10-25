local M = {}

local function safe_snacks_terminal()
  local is_available, snacks_terminal = pcall(require, "snacks.terminal")
  if not is_available then
    error("Please install `snacks.nvim` to use the embedded `opencode` terminal", 0)
  end
  return snacks_terminal
end

function M.toggle()
  safe_snacks_terminal().toggle(require("opencode.config").opts.terminal.cmd, require("opencode.config").opts.terminal)
end

---Open an embedded `opencode` terminal.
---@param cmd? string Command to run in the terminal. Defaults to `opts.terminal.cmd`.
function M.open(cmd)
  -- We use `get`, not `open`, so that `toggle` will reference the same terminal
  safe_snacks_terminal().get(
    cmd or require("opencode.config").opts.terminal.cmd,
    require("opencode.config").opts.terminal
  )
end

---Show the embedded `opencode` terminal, if it already exists.
function M.show_if_exists()
  local win = safe_snacks_terminal().get(
    require("opencode.config").opts.terminal.cmd,
    vim.tbl_deep_extend("force", require("opencode.config").opts.terminal, { create = false })
  )
  if win then
    win:show()
  end
end

return M
