---@alias opencode.Provider.snacks
---| { name: "snacks", opts: opencode.Provider.snacks.Opts }

---@class opencode.Provider.snacks.Opts : opencode.Provider.Opts, snacks.terminal.Opts

---@type opencode.Provider
return {
  ---@param opts opencode.Provider.snacks.Opts
  toggle = function(opts)
    require("snacks.terminal").toggle(opts.cmd, opts)
  end,
  ---@param opts opencode.Provider.snacks.Opts
  start = function(opts)
    -- We use `get`, not `open`, so that `toggle` will reference the same terminal
    require("snacks.terminal").get(opts.cmd, opts)
  end,
  ---@param opts opencode.Provider.snacks.Opts
  show = function(opts)
    -- Note it only shows if the terminal already exists
    local win = require("snacks.terminal").get(opts.cmd, vim.tbl_deep_extend("force", opts, { create = false }))
    if win then
      win:show()
    end
  end,
}
