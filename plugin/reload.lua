vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("OpencodeAutoReload", { clear = true }),
  pattern = "OpencodeEvent",
  callback = function(args)
    local event = args.data.event

    if event.type == "file.edited" and require("opencode.config").opts.auto_reload then
      if not vim.o.autoread then
        -- Unfortunately `autoread` is kinda necessary, for `:checktime`.
        -- Alternatively we could `:edit!` but that would lose any unsaved changes.
        vim.notify(
          "Please set `vim.o.autoread = true` to use `opencode.nvim` auto-reload, or set `vim.g.opencode_opts.auto_reload = false`",
          vim.log.levels.WARN,
          { title = "opencode" }
        )
      else
        -- `schedule` because blocking the event loop during rapid SSE influx can drop events
        vim.schedule(function()
          -- `:checktime` checks all buffers - no need to check the event's file
          vim.cmd("checktime")
        end)
      end
    end
  end,
  desc = "Reload buffers edited by `opencode`",
})

