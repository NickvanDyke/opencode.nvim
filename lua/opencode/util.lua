---@module 'snacks.picker'

local M = {}

---@param steps fun(next: fun())[]
---@param i? number
function M.chain(steps, i)
  i = i or 1
  local step = steps[i]
  if not step then
    return
  end
  step(function()
    M.chain(steps, i + 1)
  end)
end

function M.exit_visual_mode()
  if vim.fn.mode():match("[vV\22]") then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", true)
  end
end

return M
