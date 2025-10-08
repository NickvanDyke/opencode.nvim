---@module 'snacks'

local M = {}

function M.select()
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
    else
      return a.description < b.description
    end
  end)

  vim.ui.select(items, {
    prompt = "Prompt opencode: ",
    format_item = function(item)
      return item.description
    end,
    picker = {
      preview = "preview",
      layout = {
        preview = true,
      },
    },
  }, function(choice)
    if choice then
      if choice.ask then
        M.ask(choice.prompt, choice.opts)
      else
        M.prompt(choice.prompt, choice.opts)
      end
    end
  end)
end

return M
