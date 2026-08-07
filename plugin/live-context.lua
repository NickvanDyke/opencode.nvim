vim.api.nvim_create_user_command("OpenCodeLiveContextStart", function()
  local ok, result = require("opencode").start_live_context()
  if ok then
    vim.notify("OpenCode live context started on port " .. result, vim.log.levels.INFO, { title = "OpenCode" })
  else
    vim.notify("Failed to start live context: " .. result, vim.log.levels.ERROR, { title = "OpenCode" })
  end
end, { desc = "Start OpenCode live context WebSocket server" })

vim.api.nvim_create_user_command("OpenCodeLiveContextStop", function()
  require("opencode").stop_live_context()
  vim.notify("OpenCode live context stopped", vim.log.levels.INFO, { title = "OpenCode" })
end, { desc = "Stop OpenCode live context WebSocket server" })

vim.api.nvim_create_user_command("OpenCodeAttach", function()
  require("opencode").attach_context()
end, { range = true, desc = "Attach visual selection to OpenCode context (no submit)" })
