local M = {}

-- Attach a line-level listener to a buffer that reports removed and added lines.
-- Calls `on_change(record)` where record contains:
--   bufnr, changedtick, firstline, lastline (exclusive, old), new_lastline (exclusive, new), removed, added
local function attach_line_listener(bufnr, on_change)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  -- initial snapshot of lines
  local snapshot = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local state = { timer = nil, last_record = nil }

  local function debounce_call(record, wait_ms)
    wait_ms = wait_ms or 500
    state.last_record = record
    if state.timer then
      state.timer:stop()
      state.timer:close()
      state.timer = nil
    end
    state.timer = vim.uv.new_timer()
    state.timer:start(
      wait_ms,
      0,
      vim.schedule_wrap(function()
        local rec = state.last_record
        state.last_record = nil
        on_change(rec)
        if state.timer then
          state.timer:stop()
          state.timer:close()
          state.timer = nil
        end
      end)
    )
  end

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf, changedtick, firstline, lastline, new_lastline, _byte_count)
      -- removed lines are snapshot[firstline+1 .. lastline]
      local removed = {}
      if lastline - firstline > 0 then
        for i = firstline + 1, lastline do
          table.insert(removed, snapshot[i])
        end
      end

      -- added lines read from buffer after change
      local added = {}
      if new_lastline - firstline > 0 then
        added = vim.api.nvim_buf_get_lines(buf, firstline, new_lastline, false)
      end

      local record = {
        bufnr = buf,
        changedtick = changedtick,
        firstline = firstline,
        lastline = lastline,
        new_lastline = new_lastline,
        removed = removed,
        added = added,
      }

      -- debounce the on_change calls (500ms)
      debounce_call(record, 500)

      -- update snapshot by splicing
      local new_snapshot = {}
      for i = 1, firstline do
        table.insert(new_snapshot, snapshot[i])
      end
      for _, l in ipairs(added) do
        table.insert(new_snapshot, l)
      end
      for i = lastline + 1, #snapshot do
        table.insert(new_snapshot, snapshot[i])
      end
      snapshot = new_snapshot
    end,
    on_detach = function() end,
  })
end

function M.setup()
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function(args)
      if vim.api.nvim_get_option_value("buftype", { buf = args.buf }) == "" then
        attach_line_listener(args.buf, function(record)
          vim.print(record)
        end)
      end
    end,
  })
end

return M
