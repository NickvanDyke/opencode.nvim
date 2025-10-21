---@module 'snacks.picker'

local M = {}

---@class opencode.Prompt : opencode.prompt.Opts
---@field prompt string The prompt to send to `opencode`, with placeholders for context like `@cursor`, `@buffer`, etc.
---@field ask? boolean Call `ask(prompt)` instead of `prompt(prompt)`. Useful for prompts that expect additional user input.

---@param context opencode.Context
---@param on_choice fun(prompt: opencode.Prompt, callback?: fun())
function M.select(context, on_choice)
  local prompts = require("opencode.config").opts.prompts or {}

  ---@type snacks.picker.finder.Item[]
  local items = {}
  for name, prompt in pairs(prompts) do
    local rendered = context:render(prompt.prompt)
    ---@type snacks.picker.finder.Item
    local item = {
      name = name,
      text = prompt.prompt,
      highlights = rendered.input, -- `snacks.picker`'s `select` seems to ignore this, so we incorporate it ourselves in `format_item`
      preview = {
        text = context.plaintext(rendered.output),
        extmarks = context.extmarks(rendered.output),
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
    ---@param item snacks.picker.finder.Item
    ---@param is_snacks boolean
    format_item = function(item, is_snacks)
      if is_snacks then
        local formatted = vim.deepcopy(item.highlights)
        table.insert(formatted, 1, { item.name, "Title" })
        table.insert(formatted, 2, { string.rep(" ", 18 - #item.name) })
        return formatted
      else
        local indent = #tostring(#items) - #tostring(item.idx)
        return ("%s[%s] %s"):format(string.rep(" ", indent), item.name, string.rep(" ", 18 - #item.name) .. item.text)
      end
    end,
  }

  vim.ui.select(
    items,
    vim.tbl_deep_extend("keep", require("opencode.config").opts.select, select_opts),
    function(choice)
      on_choice(prompts[choice and choice.name])
    end
  )
end

return M
