vim.api.nvim_create_autocmd("VimLeave", {
  group = vim.api.nvim_create_augroup("OpencodeProvider", { clear = true }),
  pattern = "*",
  callback = function()
    pcall(require("opencode.provider").stop)
  end,
  desc = "Stop `opencode` provider on exit",
})
