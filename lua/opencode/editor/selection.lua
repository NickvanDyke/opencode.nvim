local M = {}
local server = require("opencode.editor.server")

M.state = {
  last_selection = nil,
  enabled = false,
  debounce_timer = nil,
}

local function get_visual_selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()

  if not mode:match("[vV\22]") then
    return nil
  end

  local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")

  if not start_pos or not end_pos then
    return nil
  end

  if start_pos[1] > end_pos[1] or (start_pos[1] == end_pos[1] and start_pos[2] > end_pos[2]) then
    start_pos, end_pos = end_pos, start_pos
  end

  local start_line = start_pos[1]
  local start_col = start_pos[2] + 1
  local end_line = end_pos[1]
  local end_col = end_pos[2] + 1

  local text = ""
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  if #lines > 0 then
    if start_line == end_line then
      text = string.sub(lines[1] or "", start_col, end_col)
    else
      lines[1] = string.sub(lines[1] or "", start_col)
      lines[#lines] = string.sub(lines[#lines] or "", 1, end_col)
      text = table.concat(lines, "\n")
    end
  end

  return {
    start_line = start_line - 1,
    start_col = start_col - 1,
    end_line = end_line - 1,
    end_col = end_col - 1,
    text = text,
    is_empty = #text == 0,
  }
end

local function get_cursor_position()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  local line_text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""
  local char = string.sub(line_text, col + 1, col + 1)

  return {
    start_line = line - 1,
    start_col = col,
    end_line = line - 1,
    end_col = col,
    text = char,
    is_empty = true,
  }
end

local function get_current_selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if filepath == "" or not filepath:match("^/") then
    return nil
  end

  local mode = vim.fn.mode()
  local selection

  if mode:match("[vV\22]") then
    selection = get_visual_selection()
  else
    selection = get_cursor_position()
  end

  if not selection then
    return nil
  end

  return {
    file_path = filepath,
    selection = selection,
  }
end

local function selection_key(selection)
  if not selection then
    return ""
  end
  return string.format(
    "%s:%d:%d-%d:%d",
    selection.file_path,
    selection.selection.start_line,
    selection.selection.start_col,
    selection.selection.end_line,
    selection.selection.end_col
  )
end

local function has_selection_changed(current)
  if not M.state.last_selection then
    return true
  end

  local last_key = selection_key(M.state.last_selection)
  local current_key = selection_key(current)

  return last_key ~= current_key
end

local function send_selection_update()
  if not server.is_running() then
    return
  end

  local current = get_current_selection()

  if current and has_selection_changed(current) then
    server.broadcast_selection_changed(current.file_path, current.selection)
    M.state.last_selection = current
  end
end

local function debounce_send_selection()
  if M.state.debounce_timer then
    M.state.debounce_timer:stop()
    M.state.debounce_timer:close()
    M.state.debounce_timer = nil
  end

  M.state.debounce_timer = vim.uv.new_timer()
  M.state.debounce_timer:start(100, 0, vim.schedule_wrap(function()
    send_selection_update()
    if M.state.debounce_timer then
      M.state.debounce_timer:close()
      M.state.debounce_timer = nil
    end
  end))
end

local function on_cursor_moved()
  if not M.state.enabled then
    return
  end
  debounce_send_selection()
end

local function on_mode_changed()
  if not M.state.enabled then
    return
  end
  debounce_send_selection()
end

local function on_buf_enter()
  if not M.state.enabled then
    return
  end
  debounce_send_selection()
end

local function on_text_changed()
  if not M.state.enabled then
    return
  end
  debounce_send_selection()
end

function M.enable()
  if M.state.enabled then
    return
  end

  M.state.enabled = true

  local group = vim.api.nvim_create_augroup("OpenCodeLiveContext", { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = on_cursor_moved,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = on_mode_changed,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = on_buf_enter,
  })

  vim.api.nvim_create_autocmd("TextChanged", {
    group = group,
    callback = on_text_changed,
  })

  send_selection_update()
end

function M.disable()
  if not M.state.enabled then
    return
  end

  M.state.enabled = false
  vim.api.nvim_del_augroup_by_name("OpenCodeLiveContext")

  if M.state.debounce_timer then
    M.state.debounce_timer:stop()
    M.state.debounce_timer:close()
    M.state.debounce_timer = nil
  end

  M.state.last_selection = nil
end

function M.is_enabled()
  return M.state.enabled
end

function M.send_at_mention(file_path, line_start, line_end)
  if not server.is_running() then
    return false
  end

  server.broadcast_at_mentioned(file_path, line_start, line_end)
  return true
end

function M.send_visual_selection_as_mention()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if filepath == "" or not filepath:match("^/") then
    return false
  end

  local selection = get_visual_selection()
  if not selection then
    return false
  end

  M.send_at_mention(filepath, selection.start_line, selection.end_line)
  return true
end

return M
