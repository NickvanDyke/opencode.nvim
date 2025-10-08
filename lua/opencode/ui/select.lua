---@module 'snacks.picker'

local M = {}

---Merge `line` and `hls` into a format suitable for `snacks.picker`.
---
---@param line string
---@param hls table[]
---@return snacks.picker.Highlight[]
local function snacksify(line, hls)
  local ret = {}
  if #hls > 0 then
    local offset = 1
    for _, hl in ipairs(hls) do
      if offset < hl.col then
        ret[#ret + 1] = { line:sub(offset, hl.col - 1) }
      end
      ret[#ret + 1] = { line:sub(hl.col, hl.end_col), hl.hl_group }
      offset = hl.end_col + 1
    end
    if offset <= #line then
      ret[#ret + 1] = { line:sub(offset) }
    end
  else
    ret[1] = { line }
  end
  return ret
end

---@class opencode.Prompt : opencode.prompt.Opts
---@field prompt string The prompt to send to `opencode`, with placeholders for context like `@cursor`, `@buffer`, etc.
---@field ask? boolean Call `ask(prompt)` instead of `prompt(prompt)`. Useful for prompts that expect additional user input.

---@param on_choice fun(prompt: opencode.Prompt, cb?: fun())
function M.select(on_choice)
  local prompts = require("opencode.config").opts.prompts or {}

  ---@type snacks.picker.finder.Item[]
  local items = {}
  for name, prompt in pairs(prompts) do
    local hls = require("opencode.ui.highlight").highlight(prompt.prompt)
    ---@type snacks.picker.finder.Item
    local item = {
      name = name,
      text = prompt.prompt,
      highlights = #hls > 0 and {
        vim.tbl_map(function(hl)
          return { col = hl[1], end_col = hl[2], hl_group = hl[3], row = 1 }
        end, hls),
      },
      preview = {
        text = require("opencode.context").inject(prompt.prompt),
      },
    }
    table.insert(items, item)
  end

  table.sort(items, function(a, b)
    local aPrompt = prompts[a.name]
    local bPrompt = prompts[b.name]
    if aPrompt.ask and not bPrompt.ask then
      return true
    elseif not aPrompt.ask and bPrompt.ask then
      return false
    end
    return a.name < b.name
  end)

  for i, item in ipairs(items) do
    item.idx = i
  end

  ---@type snacks.picker.ui_select.Opts
  local select_opts = {
    prompt = "Prompt opencode: ",
    ---@param item snacks.picker.finder.Item
    ---@param is_snacks boolean
    format_item = function(item, is_snacks)
      if is_snacks then
        ---@type snacks.picker.Highlight[]
        local formatted = snacksify(item.text, item.highlights and item.highlights[1] or {})
        table.insert(formatted, 1, { item.name, "Title" })
        table.insert(formatted, 2, { string.rep(" ", 18 - #item.name) })
        return formatted
      else
        local indent = #tostring(#items) - #tostring(item.idx)
        return ("%s[%s] %s"):format(string.rep(" ", indent), item.name, string.rep(" ", 18 - #item.name) .. item.text)
      end
    end,
    picker = {
      preview = "preview",
      layout = {
        preview = true,
      },
    },
  }

  require("opencode.context").store_mode()
  vim.ui.select(items, select_opts, function(choice)
    on_choice(prompts[choice and choice.name], function()
      require("opencode.context").clear_mode()
    end)
  end)
end

return M
