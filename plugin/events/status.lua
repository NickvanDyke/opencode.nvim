vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("OpencodeStatus", { clear = true }),
  pattern = "OpencodeEvent:*",
  callback = function(args)
    ---@type opencode.cli.client.Event
    local event = args.data.event
    require("opencode.status").update(event)
  end,
  desc = "Update opencode status",
})
