local M = {}

---@param steps fun(next: fun())[]
---@param i? number
function M.chain_async(steps, i)
  i = i or 1
  local step = steps[i]
  if not step then
    return
  end
  step(function()
    M.chain_async(steps, i + 1)
  end)
end

return M
