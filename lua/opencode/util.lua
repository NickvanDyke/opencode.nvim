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

-- TODO: These different highlight formats are awkward.
-- Curious if we can unify further. Limited by external APIs though.
-- Maybe transforms would be simpler with a different base format (in `Context:render()`),
-- like `{ text, extmarks }` for each of input and output.
-- Because I think anywhere that takes `Text[]` could also take `Extmark[]` directly.

---Transforms `text` to extmarks.
---Handles multiline texts.
---@param text snacks.picker.Text[]
---@return snacks.picker.Extmark[]
function M.snacks_texts_to_extmarks(text)
  local row = 1
  local col = 1
  local extmarks = {}
  for _, part in ipairs(text) do
    local part_text = part[1]
    local part_hl = part[2] or nil
    local segments = vim.split(part_text, "\n", { plain = true })
    for i, segment in ipairs(segments) do
      if i > 1 then
        row = row + 1
        col = 1
      end
      ---@type snacks.picker.Extmark
      if part_hl then
        local extmark = {
          row = row,
          col = col - 1,
          end_col = col + #segment - 1,
          hl_group = part_hl,
        }
        table.insert(extmarks, extmark)
      end
      col = col + #segment
    end
  end
  return extmarks
end

---Transforms `text` to `:help input()-highlight` format.
---@param text snacks.picker.Text[]
---@return { [1]: number, [2]: number, [3]: string }[]
function M.snacks_texts_to_input_highlights(text)
  local i = 1
  local input_highlights = {}
  for _, part in ipairs(text) do
    local part_text = part[1]
    local part_hl = part[2] or nil
    if part_hl then
      local input_hl = { i - 1, i + #part_text - 1, part_hl }
      table.insert(input_highlights, input_hl)
    end
    i = i + #part_text
  end
  return input_highlights
end

return M
