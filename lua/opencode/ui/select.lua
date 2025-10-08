local M = {}

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
    on_choice(choice, function()
      require("opencode.context").clear_mode()
    end)
  end)
end

return M
