---@module 'snacks'

---Provide an embedded `opencode` via [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@class opencode.provider.Snacks : opencode.Provider
---
---@field opts snacks.terminal.Opts
local Snacks = {}
Snacks.__index = Snacks
Snacks.name = "snacks"

---@class opencode.provider.snacks.Opts : snacks.terminal.Opts

---@param opts? opencode.provider.snacks.Opts
---@return opencode.provider.Snacks
function Snacks.new(opts)
  local self = setmetatable({}, Snacks)
  self.opts = opts or {}
  return self
end

---Check if `snacks.terminal` is available and enabled.
function Snacks.health()
  local snacks_ok, snacks = pcall(require, "snacks")
  if not snacks_ok then
    return "`snacks.nvim` is not available.", {
      "Install `snacks.nvim` and enable `snacks.terminal.`",
    }
  elseif not snacks.config.get("terminal", {}).enabled then
    return "`snacks.terminal` is not enabled.",
      {
        "Enable `snacks.terminal` in your `snacks.nvim` configuration.",
      }
  end

  return true
end

function Snacks:get()
  ---@type snacks.terminal.Opts
  local opts = vim.tbl_deep_extend("force", self.opts, { create = false })
  local win = require("snacks.terminal").get(self.cmd, opts)
  return win
end

---@param current_cwd string
---@return boolean
---@private
function Snacks:hide_other_visible_terminals(current_cwd)
  local terminals = require("snacks.terminal").list()
  local did_hide = false
  for _, term in ipairs(terminals) do
    if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
      local term_info = vim.b[term.buf].snacks_terminal
      local is_opencode = term_info and term_info.cmd == self.cmd
      local is_other_cwd = term_info and term_info.cwd ~= current_cwd
      local is_visible = term.win and vim.api.nvim_win_is_valid(term.win)
      if is_opencode and is_other_cwd and is_visible then
        term:hide()
        did_hide = true
      end
    end
  end
  return did_hide
end

function Snacks:toggle()
  local cwd = require("opencode.provider").get_project_root()
  if self:hide_other_visible_terminals(cwd) then
    return
  end
  local opts = vim.tbl_deep_extend("force", self.opts, { cwd = cwd })
  require("snacks.terminal").toggle(self.cmd, opts)
end

function Snacks:start()
  if not self:get() then
    local cwd = require("opencode.provider").get_project_root()
    local opts = vim.tbl_deep_extend("force", self.opts, { cwd = cwd })
    require("snacks.terminal").open(self.cmd, opts)
  end
end

function Snacks:stop()
  local win = self:get()
  if win then
    win:close()
  end
end

return Snacks
