local M = {}

local function is_buf_valid(buf)
  return vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_get_option_value("buftype", { buf = buf }) == ""
end

-- While focusing the input and calling contexts for completion documentation,
-- the input will be the current window. So, find the last used "valid" window.
local function last_used_valid_win()
  local last_used_win = 0
  local latest_lastused = 0

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if is_buf_valid(buf) then
      local last_used = vim.fn.getbufinfo(buf)[1].lastused or 0
      if last_used > latest_lastused then
        latest_lastused = last_used
        last_used_win = win
      end
    end
  end

  return last_used_win
end

---Given a buffer number, returns the file path relative to Neovim's CWD, or nil if not associated with a file.
---Opencode seems to easily ignore directories in the path above its CWD, so it's okay to use paths relative to Neovim's CWD,
---given that we verify the former is inside the latter.
---Unless the user does something weird like set opts.port to an opencode running in an entirely different directory.
---@param buf number
---@return string|nil
local function file_path(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return nil
  end

  return vim.fn.fnamemodify(name, ":.")
end

---Inject context into a prompt.
---@param prompt string
---@param contexts table<string, opencode.Context>
---@return string
function M.inject(prompt, contexts)
  -- TODO: In the midst of replacing, I think this considers already-replaced values as part of the prompt, and attempts to "chain replace" them?
  -- Like if selection context injects text containing a literal placeholder.
  local placeholders = vim.tbl_keys(contexts)
  -- Replace the longest placeholders first, in case they overlap. e.g. @buffer should not replace "@buffers" in the prompt.
  table.sort(placeholders, function(a, b)
    return #a > #b
  end)
  for _, placeholder in ipairs(placeholders) do
    prompt = prompt:gsub(placeholder, function()
      -- Pass a function so it's only called when the placeholder is matched
      return contexts[placeholder].value() or placeholder
    end)
  end

  return prompt
end

---The current buffer's file path.
---@return string|nil
function M.buffer()
  return file_path(vim.api.nvim_win_get_buf(last_used_valid_win()))
end

---All open buffers' file paths.
---@return string|nil
function M.buffers()
  local file_list = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_buf_valid(buf) then
      local path = file_path(buf)
      if path then
        table.insert(file_list, path)
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
  local win = last_used_valid_win()
  local pos = vim.api.nvim_win_get_cursor(win)
  local line = pos[1]
  local col = pos[2] + 1 -- Convert to 1-based index

  return string.format("%s:L%d:C%d", file_path(vim.api.nvim_win_get_buf(win)), line, col)
end

---The visual selection range in the format `file_path:Lstart-end`.
---@return string|nil
function M.visual_selection()
  local is_visual = vim.fn.mode():match("[vV\22]")
  local path = file_path(vim.api.nvim_win_get_buf(last_used_valid_win()))
  if not path then
    return nil
  end

  -- Need to change our getpos arg when in visual mode because '< and '> update upon exiting visual mode, not during.
  -- Whereas snacks.input clears visual mode, so we need to get the now-set range.
  local _, start_line = unpack(vim.api.nvim_win_call(last_used_valid_win(), function()
    return vim.fn.getpos(is_visual and "v" or "'<")
  end))
  local _, end_line = unpack(vim.api.nvim_win_call(last_used_valid_win(), function()
    return vim.fn.getpos(is_visual and "." or "'>")
  end))
  if start_line > end_line then
    -- Handle "backwards" selection
    start_line, end_line = end_line, start_line
  end

  return string.format("%s:L%d-%d", path, start_line, end_line)
end

function M.visible_text()
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if is_buf_valid(buf) then
      local path = file_path(buf)
      if path then
        local start_line = vim.fn.line("w0", win)
        local end_line = vim.fn.line("w$", win)
        table.insert(visible, string.format("%s:L%d-%d", path, start_line, end_line))
      end
    end
  end

  if #visible == 0 then
    return nil
  end

  return table.concat(visible, ", ")
end

---Formatted diagnostics for the current buffer.
---@param curr_line_only? boolean Whether to only include diagnostics for the current line.
---@return string|nil
function M.diagnostics(curr_line_only)
  local win = last_used_valid_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local diagnostics =
    vim.diagnostic.get(buf, { lnum = curr_line_only and vim.api.nvim_win_get_cursor(win)[1] - 1 or nil })
  if #diagnostics == 0 then
    return nil
  end

  local message = #diagnostics .. " diagnostic" .. (#diagnostics > 1 and "s" or "") .. ":"

  for _, diagnostic in ipairs(diagnostics) do
    local start_line = diagnostic.lnum + 1 -- Convert to 1-based line numbers
    local start_col = diagnostic.col + 1
    local end_line = diagnostic.end_lnum + 1
    local end_col = diagnostic.end_col + 1
    local short_message = diagnostic.message:gsub("%s+", " "):gsub("^%s", ""):gsub("%s$", "")

    message = string.format(
      "%s %s:L%d:C%d-L%d:C%d: (%s) %s",
      message,
      file_path(buf),
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
    local filename = entry.bufnr ~= 0 and file_path(entry.bufnr) or nil
    if filename then
      local lnum = entry.lnum
      local col = entry.col
      table.insert(lines, string.format("%s:L%d:C%d", filename, lnum, col))
    end
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

---Tags from the `grapple.nvim` plugin.
---@return string|nil
function M.grapple_tags()
  if not pcall(require, "grapple") then
    return nil
  end

  local tags = require("grapple").tags()
  if not tags or #tags == 0 then
    return nil
  end

  local paths = {}
  for _, tag in ipairs(tags) do
    table.insert(paths, tag.path)
  end
  return table.concat(paths, ", ")
end

return M
