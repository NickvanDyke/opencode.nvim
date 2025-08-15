local M = {}

local port = 6969

-- Attach a line-level listener to a buffer that reports removed and added lines.
-- Calls `on_change(record)` where record contains:
--   bufnr, changedtick, firstline, lastline (exclusive, old), new_lastline (exclusive, new), removed, added
local function attach_line_listener(bufnr, on_change)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  -- initial snapshot of lines
  local snapshot = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local state = { timer = nil, last_record = nil }

  local function debounce_call(record)
    state.last_record = record

    if state.timer then
      state.timer:stop()
      state.timer:close()
      state.timer = nil
    end

    state.timer = vim.uv.new_timer()
    state.timer:start(
      1000,
      0,
      vim.schedule_wrap(function()
        local rec = state.last_record
        state.last_record = nil
        on_change(rec)
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
      debounce_call(record)

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

-- TODO: Or `opencode serve` and query it?
local function query_opencode(record)
  local query = {
    "I just made these changes to "
      .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(record.bufnr), ":.")
      .. ":L"
      .. record.firstline
      .. "-"
      .. record.lastline
      .. ":",
    "Added lines:\n" .. table.concat(record.added, "\n"),
    "Removed lines:\n" .. table.concat(record.removed, "\n"),
    "Please suggest the next edit I should make to this file.",
    "Respond ONLY with a JSON array of objects, each with the keys file, line, operation, and text.",
    "To change text inside a line, remove the line and add a new one with the changed text.",
  }

  local query_str = table.concat(query, "\n")
  require("opencode.client").send(query_str)
end

function M.setup()
  vim.fn.jobstart({
    "opencode",
    "serve",
    "--port",
    tostring(port),
  }, {
    on_stdout = function(_, data, _)
      vim.print(data)
    end,
    on_stderr = function(_, data)
      if data then
        vim.print("Opencode server stderr:", data)
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.notify("Opencode server exited with code: " .. code, vim.log.levels.ERROR, { title = "opencode" })
      end
    end,
  })
  -- TODO: Other events?
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    callback = function(args)
      local query_opencode_job_id = nil
      if vim.api.nvim_get_option_value("buftype", { buf = args.buf }) == "" then
        -- TODO: I think typing in insert mode only triggers this one character at a time...
        attach_line_listener(args.buf, function(record)
          vim.print(record)

          if query_opencode_job_id then
            vim.print("Stopping previous opencode job")
            vim.fn.jobstop(query_opencode_job_id)
          end

          query_opencode_job_id = query_opencode(record)
        end)
      end
    end,
  })
end

return M
