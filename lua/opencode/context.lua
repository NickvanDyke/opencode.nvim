local M = {}

---Given a buffer number, returns the absolute file path, or nil if not associated with a file.
---@param bufnr number
---@return string|nil
local function file_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and not name:match("^term://") and name or nil
end

---Inject context into a prompt.
---@param prompt string
---@param opts opencode.Config
---@return string
function M.inject(prompt, opts)
  for placeholder, fun in pairs(opts.context) do
    -- Only match whole-word placeholders using Lua frontier patterns.
    -- Ideally we'd have one in front of the pattern too, but I can't find a pattern
    -- that will match the start of the string OR a word boundary but not match
    -- a special character like `@` or `#` at the start of the placeholder.
    prompt = prompt:gsub(placeholder .. "%f[%W]", fun() or placeholder)
  end

  return prompt
end

---The current buffer's file path.
---@return string|nil
function M.file()
  return file_path(0)
end

---File paths of all open buffers.
---@return string|nil
function M.files()
  local file_list = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local rel_path = file_path(buf)
      if rel_path then
        table.insert(file_list, rel_path)
      end
    end
  end

  if #file_list == 0 then
    return nil
  end

  return table.concat(file_list, ", ")
end

---The current cursor position in the format `file_path:Lline:Ccol`.
---@return string
function M.cursor_position()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = pos[1]
  local col = pos[2] + 1 -- Convert to 1-based index

  return string.format("%s:L%d:C%d", file_path(0), line, col)
end

---The selected lines location in the format `file_path:Lstart-end`.
---@return string|nil
function M.visual_selection()
  -- TODO: Should this be a special context that's always inserted when in visual mode,
  -- regardless of prompt/placeholder?
  local is_visual = vim.fn.mode():match("[vV\22]")

  if not is_visual then
    return nil
  end

  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")
  local start_line = start_pos[2]
  local end_line = end_pos[2]
  if start_line > end_line then
    -- Handle "backwards" selection
    start_line, end_line = end_line, start_line
  end

  -- Exit visual mode now that we've "consumed" the selection
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)

  return string.format("%s:L%d-%d", file_path(0), start_line, end_line)
end

---Formatted diagnostics for the current buffer.
---@return string|nil
function M.diagnostics()
  local diagnostics = vim.diagnostic.get(0)
  if #diagnostics == 0 then
    return nil
  end

  local message = #diagnostics .. " error" .. (#diagnostics > 1 and "s" or "") .. ":"

  for _, diagnostic in ipairs(diagnostics) do
    local start_line = diagnostic.lnum + 1 -- Convert to 1-based line numbers
    local start_col = diagnostic.col + 1
    local end_line = diagnostic.end_lnum + 1
    local end_col = diagnostic.end_col + 1
    local short_message = diagnostic.message:gsub("%s+", " "):gsub("^%s", ""):gsub("%s$", "")

    message = string.format(
      "%s, %s:L%d:C%d-L%d:C%d: (%s) %s",
      message,
      file_path(0),
      start_line,
      start_col,
      end_line,
      end_col,
      diagnostic.source or "unknown source",
      short_message
    )
  end

  return message
end

---Formatted quickfix list entries.
---@return string|nil
function M.quickfix()
  local qflist = vim.fn.getqflist()
  if #qflist == 0 then
    return nil
  end

  local lines = {}
  for _, entry in ipairs(qflist) do
    local filename = entry.bufnr ~= 0 and file_path(entry.bufnr) or "unknown file"
    local lnum = entry.lnum
    local col = entry.col
    table.insert(lines, string.format("%s:L%d:C%d", filename, lnum, col))
  end
  local result = table.concat(lines, ", ")
  return result
end

---The git diff (unified diff format).
---@return string|nil
function M.git_diff()
  local handle = io.popen("git --no-pager diff")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  if result and result ~= "" then
    return result
  end
  return nil
end

return M
