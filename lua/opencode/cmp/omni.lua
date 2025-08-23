---Generate completion items for snacks.input or customlist completion.
---This function finds the last word in the current command line and, for each matching
---placeholder in the config context, returns the entire command line with that word replaced.
---This is necessary because snacks.input replaces the whole input with the selected completion.
---
---Normally we could simply add the 'omni' source to blink.cmp, but the above makes it clunky.
---Completions are really long and get deprioritized because they match less.
---A custom blink.cmp source gives us a little more control and thus better UX anyway.
---Especially for future enhancements.
---
---@param ArgLead string The text to be completed (not used directly; snacks.input passes the full line).
---@param CmdLine string The entire current input line.
---@param CursorPos number The cursor position in the input line (not used).
---@return table
return function(ArgLead, CmdLine, CursorPos)
  local start_idx, end_idx = CmdLine:find("([^%s]+)$")
  local latest_word = start_idx and CmdLine:sub(start_idx, end_idx) or nil

  local items = {}
  for placeholder, _ in pairs(require("opencode.config").opts.contexts) do
    if not latest_word then
      local new_cmd = CmdLine .. placeholder
      table.insert(items, new_cmd)
    elseif placeholder:find(latest_word, 1, true) == 1 then
      local new_cmd = CmdLine:sub(1, start_idx - 1) .. placeholder .. CmdLine:sub(end_idx + 1)
      table.insert(items, new_cmd)
    end
  end
  return items
end
