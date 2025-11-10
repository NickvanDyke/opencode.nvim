---@module 'snacks.terminal'

---Provide an embedded `opencode` via [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@class opencode.provider.Snacks : opencode.Provider
---
---@field opts snacks.terminal.Opts
local Snacks = {}
Snacks.__index = Snacks

---@class opencode.provider.snacks.Opts : snacks.terminal.Opts

---@param opts? opencode.provider.snacks.Opts
---@return opencode.provider.Snacks
function Snacks.new(opts)
  local self = setmetatable({}, Snacks)
  self.opts = opts or {}
  return self
end

function Snacks:toggle()
  require("snacks.terminal").toggle(self.cmd, self.opts)
end

function Snacks:start()
  require("snacks.terminal").open(self.cmd, self.opts)
end

function Snacks:show()
  ---@type snacks.terminal.Opts
  local opts = vim.tbl_deep_extend("force", self.opts, { create = false })
  local win = require("snacks.terminal").get(self.cmd, opts)
  if win then
    win:show()
  end
end

return Snacks
