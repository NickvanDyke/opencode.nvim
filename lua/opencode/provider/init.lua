---@module 'snacks.terminal'

---Provide an integrated `opencode`.
---Providers should ignore manually-started `opencode` instances,
---operating only on those they start themselves.
---@class opencode.Provider
---
---The name of the provider.
---@field name? string
---
---The command to start `opencode`.
---`opencode.nvim` will append `--port <port>` if not already present and `opts.port` is set.
---@field cmd? string
---
---@field new? fun(opts: table): opencode.Provider
---
---Toggle `opencode`.
---@field toggle? fun(self: opencode.Provider)
---
---Start `opencode`.
---Called when attempting to interact with `opencode` but none was found.
---`opencode.nvim` then polls for a couple seconds waiting for one to appear.
---Should not steal focus by default, if possible.
---@field start? fun(self: opencode.Provider)
---
---Stop the previously started `opencode`.
---Called when Neovim is exiting.
---@field stop? fun(self: opencode.Provider)
---
---Health check for the provider.
---Should return `true` if the provider is available,
---else an error string and optional advice (for `vim.health.warn`).
---@field health? fun(): boolean|string, ...string|string[]

---Configure and enable built-in providers.
---@class opencode.provider.Opts
---
---The built-in provider to use, or `false` for none.
---Default order:
---  - `"snacks"` if `snacks.terminal` is available and enabled
---  - `"kitty"` if in a `kitty` session with remote control enabled
---  - `"wezterm"` if in a `wezterm` window
---  - `"tmux"` if in a `tmux` session
---  - `"terminal"` as a fallback
---@field enabled? "terminal"|"snacks"|"kitty"|"wezterm"|"tmux"|false
---
---@field terminal? opencode.provider.terminal.Opts
---@field snacks? opencode.provider.snacks.Opts
---@field kitty? opencode.provider.kitty.Opts
---@field wezterm? opencode.provider.wezterm.Opts
---@field tmux? opencode.provider.tmux.Opts

local M = {}

---Get the project root directory using smart detection.
---Priority: 1) git root, 2) LSP workspace, 3) nvim directory argument, 4) current buffer dir, 5) cwd
---@return string
function M.get_project_root()
  local cwd = vim.fn.getcwd()

  local git_cmd = "git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --show-toplevel 2>/dev/null"
  local git_root = vim.fn.systemlist(git_cmd)[1]
  if vim.v.shell_error == 0 and git_root and git_root ~= "" then
    return git_root
  end

  local clients = vim.lsp.get_clients({ bufnr = 0 })
  for _, client in ipairs(clients) do
    if client.config.root_dir then
      return client.config.root_dir
    end
  end

  local arg = vim.fn.argv(0)
  ---@cast arg string
  if arg and arg ~= "" and vim.fn.isdirectory(arg) == 1 then
    local path = vim.fn.fnamemodify(arg, ":p"):gsub("/$", "")
    return path
  end

  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name and buf_name ~= "" then
    local buf_dir = vim.fn.fnamemodify(buf_name, ":p:h")
    if vim.fn.isdirectory(buf_dir) == 1 then
      return buf_dir
    end
  end

  return cwd
end

local function subscribe_to_sse()
  if not require("opencode.config").opts.events.enabled then
    return
  end

  require("opencode.cli.server")
    .get_port(false)
    :next(function(port)
      require("opencode.events").subscribe_to_sse(port)
    end)
    :catch(function(err)
      vim.notify("Failed to subscribe to SSE: " .. err, vim.log.levels.WARN)
    end)
end

---Get all providers.
---@return opencode.Provider[]
function M.list()
  return {
    require("opencode.provider.snacks"),
    require("opencode.provider.kitty"),
    require("opencode.provider.wezterm"),
    require("opencode.provider.tmux"),
    require("opencode.provider.terminal"),
  }
end

---Toggle `opencode` via the configured provider.
function M.toggle()
  local provider = require("opencode.config").provider
  if provider and provider.toggle then
    provider:toggle()
    subscribe_to_sse()
  else
    error("`provider.toggle` unavailable — run `:checkhealth opencode` for details", 0)
  end
end

---Start `opencode` via the configured provider.
function M.start()
  local provider = require("opencode.config").provider
  if provider and provider.start then
    provider:start()
    subscribe_to_sse()
  else
    error("`provider.start` unavailable — run `:checkhealth opencode` for details", 0)
  end
end

---Stop `opencode` via the configured provider.
function M.stop()
  local provider = require("opencode.config").provider
  if provider and provider.stop then
    provider:stop()
  else
    error("`provider.stop` unavailable — run `:checkhealth opencode` for details", 0)
  end
end

return M
