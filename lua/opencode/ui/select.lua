---@module 'snacks.picker'

local M = {}

---@class opencode.select.Opts
---@field prompts? boolean
---@field commands? boolean
---@field provider? boolean

---Select a prompt, command, or provider function.
---Includes previews when using `snacks.picker`.
---@param opts? opencode.select.Opts
function M.select(opts)
  opts = opts or {
    prompts = true,
    commands = true,
    provider = true,
  }
  local context = require("opencode.context").new()
  local prompts = require("opencode.config").opts.prompts or {}
  local commands = require("opencode.config").opts.commands or {}

  ---@type snacks.picker.finder.Item[]
  local items = {}

  -- Prompts group
  if opts.prompts then
    table.insert(items, { __group = true, name = "PROMPT", preview = { text = "" } })
    local prompt_items = {}
    for name, prompt in pairs(prompts) do
      local rendered = context:render(prompt.prompt)
      ---@type snacks.picker.finder.Item
      local item = {
        __type = "prompt",
        name = name,
        text = prompt.prompt .. (prompt.ask and "…" or ""),
        highlights = rendered.input, -- `snacks.picker`'s `select` seems to ignore this, so we incorporate it ourselves in `format_item`
        preview = {
          text = context.plaintext(rendered.output),
          extmarks = context.extmarks(rendered.output),
        },
        ask = prompt.ask,
      }
      table.insert(prompt_items, item)
    end
    -- Sort: ask=true first, then by name
    table.sort(prompt_items, function(a, b)
      if a.ask and not b.ask then
        return true
      elseif not a.ask and b.ask then
        return false
      else
        return a.name < b.name
      end
    end)
    for _, item in ipairs(prompt_items) do
      table.insert(items, item)
    end
  end

  -- Commands group
  if opts.commands then
    table.insert(items, { __group = true, name = "COMMAND", preview = { text = "" } })
    local command_items = {}
    for name, description in pairs(commands) do
      table.insert(command_items, {
        __type = "command",
        name = name, -- TODO: Truncate if it'd run into `text`
        text = description,
        highlights = { { description, "Comment" } },
        preview = {
          text = "",
        },
      })
    end
    table.sort(command_items, function(a, b)
      return a.name < b.name
    end)
    for _, item in ipairs(command_items) do
      table.insert(items, item)
    end
  end

  -- Provider group
  if opts.provider then
    table.insert(items, { __group = true, name = "PROVIDER", preview = { text = "" } })
    table.insert(items, {
      __type = "provider",
      name = "toggle",
      text = "Toggle opencode",
      highlights = { { "Toggle opencode", "Comment" } },
      preview = { text = "" },
    })
    table.insert(items, {
      __type = "provider",
      name = "start",
      text = "Start opencode",
      highlights = { { "Start opencode", "Comment" } },
      preview = { text = "" },
    })
    table.insert(items, {
      __type = "provider",
      name = "show",
      text = "Show opencode",
      highlights = { { "Show opencode", "Comment" } },
      preview = { text = "" },
    })
  end

  for i, item in ipairs(items) do
    item.idx = i -- Store the index for non-snacks formatting
  end

  ---@type snacks.picker.ui_select.Opts
  local select_opts = {
    ---@param item snacks.picker.finder.Item
    ---@param is_snacks boolean
    format_item = function(item, is_snacks)
      if is_snacks then
        if item.__group then
          return { { item.name, "Title" } }
        end
        local formatted = vim.deepcopy(item.highlights)
        if item.ask then
          table.insert(formatted, { "…", "Keyword" })
        end
        table.insert(formatted, 1, { item.name, "Keyword" })
        table.insert(formatted, 2, { string.rep(" ", 18 - #item.name) })
        return formatted
      else
        local indent = #tostring(#items) - #tostring(item.idx)
        if item.__group then
          local divider = string.rep("—", (80 - #item.name) / 2)
          return string.rep(" ", indent) .. divider .. item.name .. divider
        end
        return ("%s[%s]%s%s"):format(
          string.rep(" ", indent),
          item.name,
          string.rep(" ", 18 - #item.name),
          item.text or ""
        )
      end
    end,
  }

  vim.ui.select(
    items,
    vim.tbl_deep_extend("force", select_opts, require("opencode.config").opts.select),
    function(choice)
      if not choice then
        return
      elseif choice.__type == "prompt" then
        ---@type opencode.Prompt
        local prompt = require("opencode.config").opts.prompts[choice.name]
        prompt.context = context
        if prompt.ask then
          require("opencode").ask(prompt.prompt, prompt)
        else
          require("opencode").prompt(prompt.prompt, prompt)
        end
      elseif choice.__type == "command" then
        require("opencode").command(choice.name)
      elseif choice.__type == "provider" then
        if choice.name == "toggle" then
          require("opencode").toggle()
        elseif choice.name == "start" then
          require("opencode").start()
        elseif choice.name == "show" then
          require("opencode").show()
        end
      end
    end
  )
end

return M
