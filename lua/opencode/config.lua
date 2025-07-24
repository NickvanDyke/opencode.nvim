local M = {}

-- TODO: Possible to require model_id and provider_id in passed opts?
-- Unlikely they're using the defaults.
-- But without requiring it in single-call opts.
-- Ideally without two separate classes.

---@class opencode.Config
---@field model_id? string [Model](https://models.dev/) to use for opencode requests
---@field provider_id? string [Provider](https://models.dev/) to use for opencode requests
---@field port? number The port opencode is running on — use `--port <port>`. If `nil`, tries to find a running instance.
---@field auto_reload? boolean Automatically reload buffers edited by opencode
---@field context? table<string, fun(string): string|nil> Context to add to prompts
local defaults = {
  model_id = "gpt-4.1",
  provider_id = "github-copilot",
  port = nil,
  auto_reload = false,
  context = {
    ["@file"] = require("opencode.context").file,
    ["@files"] = require("opencode.context").files,
    ["@cursor"] = require("opencode.context").cursor_position,
    ["@selection"] = require("opencode.context").visual_selection,
    ["@diagnostics"] = require("opencode.context").diagnostics,
    ["@quickfix"] = require("opencode.context").quickfix,
    ["@diff"] = require("opencode.context").git_diff,
  },
}

---@type opencode.Config
M.options = vim.deepcopy(defaults)

---@param opts? opencode.Config
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})

  if M.options.auto_reload then
    require("opencode.reload").setup()
  end

  return M.options
end

return M
