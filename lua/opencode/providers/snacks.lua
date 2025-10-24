---@alias opencode.Provider.snacks
---| { name: "snacks", opts: snacks.terminal.Opts }

---@type opencode.Provider
return {
  cmd = "opencode",
  ---@param opts snacks.terminal.Opts
  toggle = function(cmd, opts)
    require("snacks.terminal").toggle(cmd, opts)
  end,
  ---@param opts snacks.terminal.Opts
  start = function(cmd, opts)
    -- We use `get`, not `open`, so that `toggle` will reference the same terminal
    require("snacks.terminal").get(cmd, opts)
  end,
  ---@param opts snacks.terminal.Opts
  show = function(cmd, opts)
    -- Note it only shows if the terminal already exists
    local win = require("snacks.terminal").get(cmd, vim.tbl_deep_extend("force", opts, { create = false }))
    if win then
      win:show()
    end
  end,
}
