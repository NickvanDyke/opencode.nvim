---@module 'snacks.input'

local M = {}

---Input a prompt to send to `opencode`.
---Press the up arrow to browse recent prompts.
---
--- - Highlights `opts.contexts` placeholders.
--- - Completes `opts.contexts` placeholders.
---   - Press `<Tab>` to trigger built-in completion.
---   - When using `blink.cmp` and `snacks.input`, registers `opts.auto_register_cmp_sources`.
---
---@param default? string Text to pre-fill the input with.
---@param opts? opencode.prompt.Opts Options for `prompt()`.
function M.ask(default, opts)
  opts = opts or {}
  opts.context = opts.context or require("opencode.context").new()

  ---@type snacks.input.Opts
  local input_opts = {
    default = default,
    highlight = function(text)
      local rendered = opts.context:render(text)
      -- Transform to `:help input()-highlight` format
      return vim.tbl_map(function(extmark)
        return { extmark.col, extmark.end_col, extmark.hl_group }
      end, opts.context.extmarks(rendered.input))
    end,
    completion = "customlist,v:lua.opencode_completion",
    -- snacks-only options
    win = {
      b = {
        -- Enable `blink.cmp` completion
        completion = true,
      },
      bo = {
        -- Custom filetype to enable `blink.cmp` source on
        filetype = "opencode_ask",
      },
      on_buf = function(win)
        -- Wait as long as possible to check for `blink.cmp` loaded - many users lazy-load on `InsertEnter`.
        -- And OptionSet :runtimepath didn't seem to fire for lazy.nvim. And/or it may never fire if already loaded.
        vim.api.nvim_create_autocmd("InsertEnter", {
          once = true,
          buffer = win.buf,
          callback = function()
            if package.loaded["blink.cmp"] then
              require("opencode.cmp.blink").setup(require("opencode.config").opts.auto_register_cmp_sources)
            end
          end,
        })
      end,
    },
  }

  require("opencode.cmp.blink").context = opts.context

  vim.ui.input(vim.tbl_deep_extend("force", input_opts, require("opencode.config").opts.input), function(value)
    if value and value ~= "" then
      require("opencode").prompt(value, opts)
    end
  end)
end

-- FIX: Overridden by blink.cmp cmdline completion if both are enabled, and that won't have our items.
-- Possible to register our blink source there? But only active in our own vim.ui.input calls.

---Completion function for context placeholders.
---Must be a global variable for use with `vim.ui.select`.
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
