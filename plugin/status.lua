vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("OpencodeStatus", { clear = true }),
  pattern = "OpencodeEvent",
  callback = function(args)
    require("opencode.status").update(args.data.event)
  end,
  desc = "Update opencode status",
})
