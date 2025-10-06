vim.api.nvim_create_user_command("OpencodeAdd", function(args)
  require("opencode").prompt(require("opencode.context").format_location({
    buf = vim.api.nvim_get_current_buf(),
    start_line = args.line1,
    end_line = args.line2,
  }) or "")
end, { desc = "Add selected lines to opencode prompt", range = true })
