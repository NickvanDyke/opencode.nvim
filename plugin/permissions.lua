local is_permission_request_open = false
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
