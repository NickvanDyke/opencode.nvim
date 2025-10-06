local M = {}

function M.setup()
  if not vim.o.autoread then
    -- Unfortunately autoread is kinda necessary, for :checktime.
    -- Alternatively we could :edit! but that would lose any unsaved changes.
    vim.notify(
      "Please set `vim.opt.autoread = true` to use `opencode.nvim` auto_reload, or disable `vim.g.opencode_opts.auto_reload`",
      vim.log.levels.WARN,
      { title = "opencode" }
    )
    return
  end

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("OpencodeAutoReload", { clear = true }),
    pattern = "OpencodeEvent",
    callback = function(args)
      if args.data.type == "file.edited" then
        -- `schedule` because blocking the event loop during rapid SSE influx can drop events
        vim.schedule(function()
          -- :checktime checks all buffers - no need to check event's file
          vim.cmd("checktime")
        end)
      end
    end,
    desc = "Reload buffers edited by opencode",
  })
end

return M
