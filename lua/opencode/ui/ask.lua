local M = {}

---@param default? string Text to pre-fill the input with.
---@param on_confirm fun(value: string|nil, cb?: fun())
function M.input(default, on_confirm)
  require("opencode.context").store_mode()
  vim.ui.input(
    vim.tbl_deep_extend("force", require("opencode.config").opts.input, {
      default = default,
    }),
    function(value)
      on_confirm(value, function()
        require("opencode.context").clear_mode()
      end)
    end
  )
end

---Sets up autocommands to highlight context placeholders in the given buffer.
---@param buf number
function M.setup_highlight(buf)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWinEnter" }, {
    group = vim.api.nvim_create_augroup("OpencodeAskHighlight", { clear = true }),
    buffer = buf,
    callback = function(args)
      local ns_id = vim.api.nvim_create_namespace("opencode_placeholders")
      vim.api.nvim_buf_clear_namespace(args.buf, ns_id, 0, -1)

      local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
      for i, line in ipairs(lines) do
        local hls = require("opencode.ui.highlight").highlight(line)
        for _, hl in ipairs(hls) do
          vim.api.nvim_buf_set_extmark(args.buf, ns_id, i - 1, hl[1], {
            end_col = hl[2],
            hl_group = hl[3],
          })
        end
      end
    end,
  })
end

---@param buf number
function M.setup_completion(buf)
  -- Wait as long as possible to check for `blink.cmp` loaded - many users lazy-load on `InsertEnter`.
  -- And OptionSet :runtimepath didn't seem to fire for lazy.nvim. And/or it may never fire if already loaded.
  vim.api.nvim_create_autocmd("InsertEnter", {
    once = true,
    buffer = buf,
    callback = function()
      if package.loaded["blink.cmp"] then
        require("opencode.cmp.blink").setup(require("opencode.config").opts.auto_register_cmp_sources)
      end
    end,
  })
end

-- FIX: Overridden by blink.cmp cmdline completion if both are enabled, and that won't have our items.
-- Possible to register our blink source there? But only active in our own vim.ui.input calls.

---Completion function for `vim.ui.input` to suggest context placeholders.
---Must be a global variable; reference as `opts.completion = "customlist,v:lua.opencode_completion"`.
---Trigger with `<Tab>`.
---
---@param ArgLead string The text being completed.
---@param CmdLine string The entire current input line.
---@param CursorPos number The cursor position in the input line.
---@return table<string> items A list of filtered completion items.
_G.opencode_completion = function(ArgLead, CmdLine, CursorPos)
  -- Not sure if it's me or vim, but ArgLead = CmdLine... so we have to parse and complete the entire line, not just the last word.
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

return M
