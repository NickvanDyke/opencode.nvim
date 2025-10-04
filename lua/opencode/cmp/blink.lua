--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

local is_setup = false

---@param sources string[]
function source.setup(sources)
  if is_setup then
    return
  end
  is_setup = true

  require("blink.cmp").add_source_provider("opencode", {
    module = "opencode.cmp.blink",
  })
  for _, src in ipairs(sources) do
    require("blink.cmp").add_filetype_source("opencode_ask", src)
  end
end

-- `opts` table comes from `sources.providers.your_provider.opts`
-- You may also accept a second argument `config`, to get the full
-- `sources.providers.your_provider` table
function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts
  return self
end

function source:enabled()
  return vim.bo.filetype == "opencode_ask"
end

function source:get_trigger_characters()
  -- Parse `opts.context` to return all non-alphanumeric first characters in placeholders
  local trigger_chars = {}
  for placeholder, _ in pairs(require("opencode.config").opts.contexts) do
    local first_char = placeholder:sub(1, 1)
    if not first_char:match("%w") and not vim.tbl_contains(trigger_chars, first_char) then
      table.insert(trigger_chars, first_char)
    end
  end

  return trigger_chars
end

function source:get_completions(ctx, callback)
  -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItem
  --- @type lsp.CompletionItem[]
  local items = {}
  for placeholder, context in pairs(require("opencode.config").opts.contexts) do
    --- @type lsp.CompletionItem
    local item = {
      label = placeholder,
      kind = require("blink.cmp.types").CompletionItemKind.Enum,
      filterText = placeholder,
      insertText = placeholder,
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
      documentation = {
        kind = "markdown",
        value = context.description,
      },

      -- There are some other fields you may want to explore which are blink.cmp
      -- specific, such as `score_offset` (blink.cmp.CompletionItem)
    }
    table.insert(items, item)
  end

  -- The callback _MUST_ be called at least once. The first time it's called,
  -- blink.cmp will show the results in the completion menu. Subsequent calls
  -- will append the results to the menu to support streaming results.
  --
  -- blink.cmp will mutate the items you return, so you must vim.deepcopy them
  -- before returning if you want to re-use them in the future (such as for caching)
  callback({
    items = items,
    -- Whether blink.cmp should request items when deleting characters
    -- from the keyword (i.e. "foo|" -> "fo|")
    -- Note that any non-alphanumeric characters will always request
    -- new items (excluding `-` and `_`)
    is_incomplete_backward = false,
    -- Whether blink.cmp should request items when adding characters
    -- to the keyword (i.e. "fo|" -> "foo|")
    -- Note that any non-alphanumeric characters will always request
    -- new items (excluding `-` and `_`)
    is_incomplete_forward = false,
  })

  -- (Optional) Return a function which cancels the request
  -- If you have long running requests, it's essential you support cancellation
  return function() end
end

function source:resolve(item, callback)
  item = vim.deepcopy(item)
  local context = require("opencode.config").opts.contexts[item.label]

  -- Newspaces after and before the triple backticks in case the context value starts or ends with backticks.
  -- Adds unnecessary empty lines though...
  item.documentation.value = item.documentation.value .. ":\n" .. "```\n" .. (context.value() or "nil") .. "\n```"

  callback(item)
end

return source
