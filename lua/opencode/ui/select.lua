local M = {}

---@class opencode.Prompt
---@field prompt string The prompt to send to `opencode`, with placeholders for context like `@cursor`, `@buffer`, etc.
---@field description? string Description of the prompt. Shown in selection menu.
---@field ask? boolean Call `ask(prompt)` instead of `prompt(prompt)`. Useful for prompts that expect additional user input.
---@field opts? opencode.prompt.Opts Options for `prompt()`.

---@param on_choice fun(prompt: opencode.Prompt, cb?: fun())
function M.select(on_choice)
  require("opencode.context").store_mode()

  local items = vim.tbl_map(function(prompt)
    local item = vim.deepcopy(prompt)
    item.preview = {
      text = require("opencode.context").inject(prompt.prompt),
      -- TODO: hl contexts
      -- extmarks = {}
    }
    return item
  end, vim.tbl_values(require("opencode.config").opts.prompts))

  -- Sort keyed `opts.prompts` table for consistency, and prioritize ones that trigger `ask()`.
  table.sort(items, function(a, b)
    if a.ask and not b.ask then
      return true
    elseif not a.ask and b.ask then
      return false
    elseif a.description and b.description then
      return a.description < b.description
    else
      return a.prompt < b.prompt
    end
  end)

  vim.ui.select(items, {
    prompt = "Prompt opencode: ",
    format_item = function(item)
      return item.description or item.prompt
    end,
    picker = {
      preview = "preview",
      layout = {
        preview = true,
      },
    },
  }, function(choice)
    on_choice(choice, function()
      require("opencode.context").clear_mode()
    end)
  end)
end

return M
