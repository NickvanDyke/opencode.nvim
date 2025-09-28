local M = {}

---@param default? string
---@param on_confirm fun(value: string|nil)
function M.input(default, on_confirm)
  -- Recommended configuration uses snacks.input, so `opts.input` includes options for it too, not just for vim.ui.input.
  vim.ui.input(
    vim.tbl_deep_extend("force", require("opencode.config").opts.input, {
      default = default,
    }),
    on_confirm
  )
end

---Highlights context placeholders in the input string.
---See `:help input()-highlight`.
---@param input string
---@return table[]
function M.highlight(input)
  local placeholders = vim.tbl_keys(require("opencode.config").opts.contexts)
  local hls = {}

  for _, placeholder in ipairs(placeholders) do
    local init = 1
    while true do
      local start_pos, end_pos = input:find(placeholder, init, true)
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

---Highlights context placeholders in the given buffer's first line.
---@param buf number
function M.highlight_buffer(buf)
  local input = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  local hls = M.highlight(input)

  local ns_id = vim.api.nvim_create_namespace("opencode_placeholders")
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_set_extmark(buf, ns_id, 0, hl[1], {
      end_col = hl[2],
      hl_group = hl[3],
    })
  end
end

return M
