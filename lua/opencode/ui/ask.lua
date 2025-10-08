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

---Computes context placeholder highlights for `line`.
---See `:help input()-highlight`.
---@param line string
---@return table[]
function M.highlight(line)
  local placeholders = vim.tbl_keys(require("opencode.config").opts.contexts)
  local hls = {}

  for _, placeholder in ipairs(placeholders) do
    local init = 1
    while true do
      local start_pos, end_pos = line:find(placeholder, init, true)
      if not start_pos then
        break
      end
      table.insert(hls, {
        start_pos - 1,
        end_pos,
        -- I don't expect users to care to customize this, so keep it simple with a sensible built-in highlight.
        "@lsp.type.enum",
      })
      init = end_pos + 1
    end
  end

  -- Must occur in-order or neovim will error
  table.sort(hls, function(a, b)
    return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
  end)

  return hls
end

---Sets up autocommands to highlight context placeholders in the given buffer.
---@param buf number
function M.setup_highlight(buf)
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWinEnter" }, {
    group = vim.api.nvim_create_augroup("OpencodeAskHighlight", { clear = true }),
    buffer = buf,
    callback = function(args)
      local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
      for _, line in ipairs(lines) do
        local hls = M.highlight(line)

        local ns_id = vim.api.nvim_create_namespace("opencode_placeholders")
        vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

        for _, hl in ipairs(hls) do
          vim.api.nvim_buf_set_extmark(buf, ns_id, 0, hl[1], {
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

return M
