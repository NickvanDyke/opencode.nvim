local function opts()
  return require("opencode.config").provider.opts or {}
end

---@type opencode.Provider
return {
  toggle = function()
    require("snacks.terminal").toggle(opts().cmd, opts())
  end,
  start = function()
    -- We use `get`, not `open`, so that `toggle` will reference the same terminal
    require("snacks.terminal").get(opts().cmd, opts())
  end,
  show = function()
    -- Note it only shows if the terminal already exists
    local win = require("snacks.terminal").get(opts().cmd, vim.tbl_deep_extend("force", opts(), { create = false }))
    if win then
      win:show()
    end
  end,
}
