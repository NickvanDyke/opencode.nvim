---@module 'snacks.picker'

local M = {}

---@class opencode.Prompt
---@field prompt string The prompt to send to `opencode`, with placeholders for context like `@cursor`, `@buffer`, etc.
---@field ask? boolean Call `ask(prompt)` instead of `prompt(prompt)`. Useful for prompts that expect additional user input.
---@field opts? opencode.prompt.Opts Options for `prompt()`.

---@param on_choice fun(prompt: opencode.Prompt, cb?: fun())
function M.select(on_choice)
  require("opencode.context").store_mode()

  local prompts = require("opencode.config").opts.prompts or {}

  ---@type snacks.picker.finder.Item[]
  local items = {}
  for name, prompt in pairs(prompts) do
    ---@type snacks.picker.finder.Item
    local item = {
      name = name,
      text = prompt.prompt,
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
      -- TODO: Not sure how other `select` overrides align items. But this aligns them for built-in.
      -- local indent = is_snacks and 0 or (#tostring(#items) - #tostring(item.idx))
      return ("[%s] %s"):format(
        -- string.rep(" ", indent),
        item.name,
        string.rep(" ", 18 - #item.name) .. item.text
      )
    end,
    picker = {
      preview = "preview",
      layout = {
        preview = true,
      },
    },
  }

  vim.ui.select(items, select_opts, function(choice)
    on_choice(prompts[choice and choice.name], function()
      require("opencode.context").clear_mode()
    end)
  end)
end

return M
