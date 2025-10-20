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
end, { desc = "Prompt `opencode`. Prepends [range]. Supports `submit=true`, `clear=true`.", range = true, nargs = "*" })

local is_permission_request_open = false
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

vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("OpencodePermissions", { clear = true }),
  pattern = "OpencodeEvent",
  callback = function(args)
    local event = args.data.event
    ---@type number
    local port = args.data.port

    if event.type == "permission.updated" then
      --[[
      --{
        callID = "call_UgJGOepAJ5vQ7rkfGI5LNTaQ",
        id = "per_9fe806323001XBhIAz9OrYTrgl",
        messageID = "msg_9fe805f7700166572ZsmpxllBH",
        metadata = {
          command = "ls",
          patterns = { "ls *" }
        },
        pattern = { "ls *" },
        sessionID = "ses_60196b60affeVgP0AqbqjvORtu",
        time = {
          created = 1760911450915
        },
        title = "ls",
        type = "bash"
      }
      --]]
      is_permission_request_open = true
      vim.ui.select({ "Once", "Always", "Reject" }, {
        prompt = 'opencode requesting permission: "' .. event.properties.title .. '": ',
        format_item = function(item)
          return item
        end,
      }, function(choice)
        is_permission_request_open = false
        if choice then
          local session_id = event.properties.sessionID
          local permission_id = event.properties.id
          require("opencode.client").permit(port, session_id, permission_id, choice:lower())
        end
      end)
    elseif event.type == "permission.replied" and is_permission_request_open then
      -- Close our permission dialog, in case user responded in the TUI
      -- TODO: Hmm, we don't seem to process the event while built-in select is open...
      -- TODO: With snacks.picker open, we process the event, but this isn't the right way to close it...
      -- Or we don't process the event until after it closes (manually)
      -- vim.api.nvim_feedkeys("q", "n", true)
      -- is_permission_request_open = false
    end
  end,
  desc = "Display permission requests from `opencode`",
})
