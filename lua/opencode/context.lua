local M = {}

---Inject `opts.contexts` into `prompt`.
---@param prompt string
---@return string
function M.inject(prompt)
  local contexts = require("opencode.config").opts.contexts or {}
  local placeholders = vim.tbl_keys(contexts)
  -- Replace the longest placeholders first, in case they overlap. e.g. "@buffer" should not replace "@buffers" in the prompt.
  table.sort(placeholders, function(a, b)
    return #a > #b
  end)
  -- I worried that mid-replacing, this considers already-replaced values as part of the prompt, and attempts to "chain replace" them?
  -- Like if diff context injects text containing a literal placeholder.
  -- But so far haven't managed to make that happen, so maybe it's fine.
  for _, placeholder in ipairs(placeholders) do
    prompt = prompt:gsub(placeholder, function()
      -- Default to empty string so users can safely always include contexts like @diagnostics even if there are none
      return contexts[placeholder].value() or ""
    end)
  end

  return prompt
end

local function is_buf_valid(buf)
  return vim.api.nvim_buf_is_loaded(buf)
    and vim.api.nvim_get_option_value("buftype", { buf = buf }) == ""
    and vim.api.nvim_buf_get_name(buf) ~= ""
end

---Format a location for `opencode`.
---Prepends `@` to the path so `opencode` attaches the file's content to the prompt.
---(CWDs must match, or `opencode` falls back to its `read` tool).
---Numbers should be 1-indexed.
---Returns `nil` if the provided buffer is invalid.
---@param args { buf?: number, path?: string, start_line?: number, end_line?: number, start_col?: number, end_col?: number }
---@return string|nil
function M.format_location(args)
  if not args.buf and not args.path then
    error("Must provide either `buf` or `path`")
  elseif args.buf and not is_buf_valid(args.buf) then
    return nil
  end

  local rel_path = vim.fn.fnamemodify(args.path or vim.api.nvim_buf_get_name(args.buf), ":.")
  -- The path must be its own word for `opencode`, i.e. preceeded and followed by nothing or whitespace.
  local result = "@" .. rel_path

  if args.start_line and args.end_line and args.start_line > args.end_line then
    -- Handle "backwards" selection
    args.start_line, args.end_line = args.end_line, args.start_line
  end

  if args.start_line then
    result = result .. string.format(" L%d", args.start_line)
    if args.start_col then
      result = result .. string.format(":C%d", args.start_col)
    end
    if args.end_line then
      result = result .. string.format("-L%d", args.end_line)
      if args.end_col then
        result = result .. string.format(":C%d", args.end_col)
      end
    end
  end

  return result
end

-- While focusing the input and calling contexts for completion documentation,
-- the input will be the current window. So, find the last used "valid" window.
---@return number
local function last_used_valid_win()
  local last_used_win = 0
  local latest_last_used = 0

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if is_buf_valid(buf) then
      local last_used = vim.fn.getbufinfo(buf)[1].lastused or 0
      if last_used > latest_last_used then
        latest_last_used = last_used
        last_used_win = win
      end
    end
  end

  return last_used_win
end

---The current buffer.
---@return string|nil
function M.buffer()
  return M.format_location({
    buf = vim.api.nvim_win_get_buf(last_used_valid_win()),
  })
end

---All open buffers.
---@return string|nil
function M.buffers()
  local file_list = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local path = M.format_location({ buf = buf })
    if path then
      table.insert(file_list, path)
    end
  end

  if #file_list == 0 then
    return nil
  end

  return table.concat(file_list, " ")
end

---The current cursor position.
---@return string|nil
function M.cursor_position()
  local win = last_used_valid_win()
  local pos = vim.api.nvim_win_get_cursor(win)

  return M.format_location({
    buf = vim.api.nvim_win_get_buf(win),
    start_line = pos[1],
    start_col = pos[2] + 1,
  })
end

---The currently selected lines in visual mode, or the lines that were selected before exiting visual mode.
---@return string|nil
function M.visual_selection()
  local is_visual = vim.fn.mode():match("[vV\22]")

  -- Need to change our getpos arg when in visual mode because '< and '> update upon exiting visual mode, not during.
  -- Whereas `snacks.input` clears visual mode, so we need to get the now-set range.
  local _, start_line, start_col = unpack(vim.api.nvim_win_call(last_used_valid_win(), function()
    return vim.fn.getpos(is_visual and "v" or "'<")
  end))
  local _, end_line, end_col = unpack(vim.api.nvim_win_call(last_used_valid_win(), function()
    return vim.fn.getpos(is_visual and "." or "'>")
  end))

  return M.format_location({
    buf = vim.api.nvim_win_get_buf(last_used_valid_win()),
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
  })
end

---The visible lines in all open windows.
---@return string|nil
function M.visible_text()
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local start_line = vim.fn.line("w0", win)
    local end_line = vim.fn.line("w$", win)
    table.insert(
      visible,
      M.format_location({
        buf = buf,
        start_line = start_line,
        end_line = end_line,
      })
    )
  end

  if #visible == 0 then
    return nil
  end

  return table.concat(visible, " ")
end

---Diagnostics for the current buffer.
---@return string|nil
function M.diagnostics()
  local win = last_used_valid_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local diagnostics = vim.diagnostic.get(buf)
  if #diagnostics == 0 then
    return nil
  end

  local diagnostic_strings = {}

  for _, diagnostic in ipairs(diagnostics) do
    table.insert(
      diagnostic_strings,
      string.format(
        "%s (%s): %s",
        M.format_location({
          buf = buf,
          start_line = diagnostic.lnum + 1,
          start_col = diagnostic.col + 1,
          end_line = diagnostic.end_lnum + 1,
          end_col = diagnostic.end_col + 1,
        }),
        diagnostic.source or "unknown source",
        diagnostic.message:gsub("%s+", " "):gsub("^%s", ""):gsub("%s$", "")
      )
    )
  end

  return #diagnostics
    .. " diagnostic"
    .. (#diagnostics > 1 and "s" or "")
    .. ": "
    .. table.concat(diagnostic_strings, "; ")
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
    local has_buf = entry.bufnr ~= 0 and vim.api.nvim_buf_get_name(entry.bufnr) ~= ""
    if has_buf then
      table.insert(
        lines,
        M.format_location({
          buf = entry.bufnr,
          start_line = entry.lnum,
          start_col = entry.col,
        })
      )
    end
  end

  return table.concat(lines, " ")
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

---[`grapple.nvim`](https://github.com/cbochs/grapple.nvim) tags.
---@return string|nil
function M.grapple_tags()
  local is_available, grapple = pcall(require, "grapple")
  if not is_available then
    return nil
  end

  local tags = grapple.tags()
  if not tags or #tags == 0 then
    return nil
  end

  local paths = {}
  for _, tag in ipairs(tags) do
    table.insert(paths, M.format_location({ path = tag.path }))
  end
  return table.concat(paths, " ")
end

return M
