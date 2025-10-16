vim.api.nvim_create_user_command("OpencodePrompt", function(args)
  local prompt_opts = {}
  local prompt_parts = {}
  for _, arg in ipairs(args.fargs) do
    if arg == "submit=true" then
      prompt_opts.submit = true
    elseif arg == "clear=true" then
      prompt_opts.clear = true
    else
      table.insert(prompt_parts, arg)
    end
  end

  local prompt_text = table.concat(prompt_parts, " ")
  -- Commands are the only way to support arbitrary ranges
  if args.range > 0 then
    local location_text = require("opencode.context").format_location({
      buf = vim.api.nvim_get_current_buf(),
      start_line = args.line1,
      end_line = args.line2,
    })
    if not location_text then
      error("Could not format range location")
    end

    prompt_text = location_text .. ": " .. prompt_text
  end

  require("opencode").prompt(prompt_text, prompt_opts)
end, { desc = "Prompt `opencode`, prepending [range] if any", range = true, nargs = "*" })

vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("OpencodeAutoReload", { clear = true }),
  pattern = "OpencodeEvent",
  callback = function(args)
    if args.data.type == "file.edited" and require("opencode.config").opts.auto_reload then
      if not vim.o.autoread then
        -- Unfortunately `autoread` is kinda necessary, for `:checktime`.
        -- Alternatively we could `:edit!` but that would lose any unsaved changes.
        vim.notify(
          "Please set `vim.opt.autoread = true` to use `opencode.nvim` auto-reload, or disable `vim.g.opencode_opts.auto_reload`",
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
