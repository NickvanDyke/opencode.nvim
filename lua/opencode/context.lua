---The context a prompt is being made in.
---Particularly useful when inputting or selecting a prompt
---because those change the active mode, window, etc.
---So this can store state prior to that.
---@class opencode.Context
---@field win integer
---@field buf integer
---@field row integer
---@field col integer
---@field range table|nil
local Context = {}
Context.__index = Context

local function is_buf_valid(buf)
  return vim.api.nvim_buf_is_loaded(buf)
    and vim.api.nvim_get_option_value("buftype", { buf = buf }) == ""
    and vim.api.nvim_buf_get_name(buf) ~= ""
end

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

local function selection(buf)
  local mode = vim.fn.mode()
  local kind = (mode == "V" and "line") or (mode == "v" and "char") or (mode == "\22" and "block")
  if not kind then
    return nil
  end

  require("opencode.util").exit_visual_mode()

  local from = vim.api.nvim_buf_get_mark(buf, "<")
  local to = vim.api.nvim_buf_get_mark(buf, ">")
  if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
    from, to = to, from
  end

  return {
    from = { from[1], from[2] },
    to = { to[1], to[2] },
    kind = kind,
  }
end

function Context.new()
  local self = setmetatable({}, Context)
  self.win = last_used_valid_win()
  self.buf = vim.api.nvim_win_get_buf(self.win)
  local cursor = vim.api.nvim_win_get_cursor(self.win)
  self.row = cursor[1]
  self.col = cursor[2] + 1
  self.range = selection(self.buf)
  return self
end

---Inject `opts.contexts` into `prompt`.
---@param prompt string
function Context:inject(prompt)
  local contexts = require("opencode.config").opts.contexts or {}
  local placeholders = vim.tbl_keys(contexts)
  table.sort(placeholders, function(a, b)
    return #a > #b
  end)
  for _, placeholder in ipairs(placeholders) do
    prompt = prompt:gsub(placeholder, function()
      return contexts[placeholder](self) or placeholder
    end)
  end
  return prompt
end

---Format a location for `opencode`.
---e.g. `@opencode.lua L21:C10-L65:C11`
---@param args { buf?: integer, path?: string, start_line?: integer, start_col?: integer, end_line?: integer, end_col?: integer }
function Context.format(args)
  assert(args.buf or args.path, "Must provide either `buf` or `path`")
  if args.buf and not is_buf_valid(args.buf) then
    return nil
  end
  local rel_path = vim.fn.fnamemodify(args.path or vim.api.nvim_buf_get_name(args.buf), ":.")
  local result = "@" .. rel_path
  if args.start_line and args.end_line and args.start_line > args.end_line then
    args.start_line, args.end_line = args.end_line, args.start_line
    if args.start_col and args.end_col then
      args.start_col, args.end_col = args.end_col, args.start_col
    end
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

-- TODO: May be a better organization for these built-in `context.Fn`'s

---Normal mode: cursor position.
---Visual mode: selection.
function Context:this()
  if self.range then
    return self:visual_selection()
  else
    return self:cursor_position()
  end
end

---The current buffer.
function Context:buffer()
  return Context.format({
    buf = self.buf,
  })
end

---All open buffers.
function Context:buffers()
  local file_list = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local path = Context.format({ buf = buf })
    if path then
      table.insert(file_list, path)
    end
  end
  if #file_list == 0 then
    return nil
  end
  return table.concat(file_list, " ")
end

function Context:cursor_position()
  return Context.format({
    buf = self.buf,
    start_line = self.row,
    start_col = self.col,
  })
end

function Context:visual_selection()
  if not self.range then
    return nil
  end
  return Context.format({
    buf = self.buf,
    start_line = self.range.from[1],
    start_col = (self.range.kind ~= "line") and self.range.from[2] or nil,
    end_line = self.range.to[1],
    end_col = (self.range.kind ~= "line") and self.range.to[2] or nil,
  })
end

---The visible lines in all open windows.
function Context:visible_text()
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local start_line = vim.fn.line("w0", win)
    local end_line = vim.fn.line("w$", win)
    table.insert(
      visible,
      Context.format({
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
function Context:diagnostics()
  local diagnostics = vim.diagnostic.get(self.buf)
  if #diagnostics == 0 then
    return nil
  end
  local diagnostic_strings = {}
  for _, diagnostic in ipairs(diagnostics) do
    table.insert(
      diagnostic_strings,
      string.format(
        "%s (%s): %s",
        Context.format({
          buf = self.buf,
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
function Context:quickfix()
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
        Context.format({
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
function Context:git_diff()
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
function Context:grapple_tags()
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
    table.insert(paths, Context.format({ path = tag.path }))
  end
  return table.concat(paths, " ")
end

return Context
