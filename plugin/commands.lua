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
