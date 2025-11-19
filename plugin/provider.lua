vim.api.nvim_create_autocmd("VimLeave", {
  pattern = "*",
  callback = function()
    pcall(require("opencode.provider").stop)
  end,
})
