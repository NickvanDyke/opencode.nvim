local M = {}

local function highlight_placeholders(bufnr, text, placeholders)
  local ns_id = vim.api.nvim_create_namespace("opencode_placeholders")
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  for _, placeholder in ipairs(placeholders) do
    local start = 1
    while true do
      local s, e = string.find(text, placeholder, start, true)
      if not s or not e then
        break
      end
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, 0, s - 1, { end_col = e, hl_group = "OpencodePlaceholder" })
      start = e + 1
    end
  end
end

---@param bufnr number
function M.setup(bufnr)
  if vim.fn.hlexists("OpencodePlaceholder") == 0 then
    vim.api.nvim_set_hl(0, "OpencodePlaceholder", { link = "@lsp.type.enum" })
  end

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWinEnter" }, {
    group = vim.api.nvim_create_augroup("OpencodeAskHighlight", { clear = true }),
    buffer = bufnr,
    callback = function(args)
      local text = vim.api.nvim_buf_get_lines(args.buf, 0, 1, false)[1] or ""
      local placeholders = vim.tbl_keys(require("opencode.config").options.contexts)
      highlight_placeholders(args.buf, text, placeholders)
    end,
  })
end

return M
