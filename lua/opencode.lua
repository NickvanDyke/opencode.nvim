local M = {}

local config = require("opencode.config")
local terminal = require("opencode.terminal")

--@param opts opencode.Config
function M.setup(opts)
  config.setup(opts)
end

---Toggle the opencode window.
---@param opts? opencode.Config Optional config that will override the base config for this call only
function M.toggle(opts)
  return terminal.toggle(opts)
end

---Send a command to opencode.
---@param command string opencode command (e.g. "/new")
---@param opts? opencode.Config Optional config that will override the base config for this call only
function M.command(command, opts)
  terminal.send(command, opts, false)
end

---Send a prompt to opencode.
---Prepends visual selection and expands placeholders before sending.
---@param prompt string The prompt to send
---@param opts? opencode.Config Optional config that will override the base config for this call only
function M.send(prompt, opts)
  local mode = vim.fn.mode()
  local is_visual = mode:match("[vV\22]")
  if is_visual then
    -- Prepend file path and selected line range
    local start_pos = vim.fn.getpos('v')
    local end_pos = vim.fn.getpos('.')
    local start_line = start_pos[2]
    local end_line = end_pos[2]
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    local file_path = vim.api.nvim_buf_get_name(0)
    prompt = string.format("%s:L%d-%d\n\n%s", file_path, start_line, end_line, prompt)
    -- Exit visual mode now that we've "consumed" the selection
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
  end

  -- Expand placeholders
  for placeholder, replace_func in pairs(config.options.expansions) do
    prompt = prompt:gsub(placeholder, replace_func())
  end

  terminal.send(prompt, opts)
end

---Input a prompt to send to opencode.
---Convenience function that calls `send` internally.
---@param opts? opencode.Config Optional config that will override the base config for this call only
function M.ask(opts)
  vim.ui.input({ prompt = "Ask opencode: " }, function(input)
    if input ~= nil then
      M.send(input, opts)
    end
  end)
end

return M
