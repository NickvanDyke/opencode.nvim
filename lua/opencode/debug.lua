local M = {}

---Show diagnostic information about opencode detection
function M.show_diagnostics()
  local detection = require("opencode.server_detection")
  local diagnostics = detection.get_diagnostics()
  
  local lines = {
    "=== Opencode Detection Diagnostics ===",
    "",
    "Operating System: " .. diagnostics.os,
    "Cached Port: " .. (diagnostics.cached_port or "none"),
    "Cache Valid: " .. tostring(diagnostics.cache_valid),
    "",
    "Available Commands:",
  }
  
  for cmd, available in pairs(diagnostics.available_commands) do
    table.insert(lines, "  " .. cmd .. ": " .. (available and "✓" or "✗"))
  end
  
  if diagnostics.proc_available ~= nil then
    table.insert(lines, "")
    table.insert(lines, "/proc filesystem: " .. (diagnostics.proc_available and "✓" or "✗"))
  end
  
  table.insert(lines, "")
  table.insert(lines, "Attempting port detection...")
  
  local port, error_msg = detection.find_port()
  if port then
    table.insert(lines, "✓ Found opencode on port: " .. port)
    
    -- Try to verify it's actually opencode
    local handle = io.popen("curl -s -m 0.5 http://localhost:" .. port .. "/session 2>/dev/null | head -c 50")
    if handle then
      local response = handle:read("*a")
      handle:close()
      if response and response:match("ses_") then
        table.insert(lines, "✓ Verified opencode API is responding")
      else
        table.insert(lines, "⚠ Port is open but API verification failed")
      end
    end
  else
    table.insert(lines, "✗ Detection failed: " .. (error_msg or "unknown error"))
  end
  
  -- Create a floating window to display diagnostics
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  
  local width = 60
  local height = #lines
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
    title = ' Opencode Detection ',
    title_pos = 'center',
  })
  
  -- Close on any key press
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':close<CR>', { noremap = true, silent = true })
end

return M