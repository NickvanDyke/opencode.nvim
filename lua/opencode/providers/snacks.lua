local function safe_snacks_terminal()
  local is_available, snacks_terminal = pcall(require, "snacks.terminal")
  if not is_available then
    error("Please install `snacks.nvim` to use the embedded `opencode` terminal", 0)
  end
  return snacks_terminal
end

local function opts()
  return require("opencode.config").opts.terminal
end

---@type opencode.Provider
return {
  toggle = function()
    safe_snacks_terminal().toggle(opts().cmd, opts())
  end,
  start = function()
    -- We use `get`, not `open`, so that `toggle` will reference the same terminal
    safe_snacks_terminal().get(opts().cmd, opts())
  end,
  show = function()
    local win = safe_snacks_terminal().get(opts().cmd, vim.tbl_deep_extend("force", opts(), { create = false }))
    if win then
      win:show()
    end
  end,
}
