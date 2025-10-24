---@class opencode.Provider
---
---The command to start `opencode`.
---`opencode.nvim` will append `--port <port>` if `vim.g.opencode_opts.port` is set.
---@field cmd string
---
---Called by `require("opencode").toggle()`.
---@field toggle fun(cmd: string, opts)
---
---Called when no `opencode` process is found so you can start it,
---after which `opencode.nvim` polls for a couple seconds to see if one appears.
---@field start fun(cmd: string, opts)
---
---Called when a prompt or command is sent to `opencode`.
---@field show fun(cmd: string, opts)

local opt = require("opencode.config").opts.provider
local opts = opt and opt.opts or {}
-- Load provider module if a name is specified.
local provider = opt and opt.name and require("opencode.providers." .. opt.name) or opt

-- Prioritize overridden `cmd`.
-- TODO: Not sure if this is the best way to handle it/represent it.
local cmd = (opt and opt.cmd) or (provider and provider.cmd) or "opencode" -- TODO: Should never have to default... better way to type this? Nest in `opts`?
-- Auto-add `--port <port>` to command if set and not already present.
local port = require("opencode.config").opts.port
if port and not cmd:find("--port") then
  cmd = cmd .. " --port " .. tostring(port)
end

---Wraps `opts.provider`.
return {
  toggle = function()
    if provider then
      provider.toggle(cmd, opts)
    else
      -- Notify the user here because they intentionally called `toggle()`,
      -- unlike `provider.start()` and `provider.show()` which we call implicitly.
      -- We expect the user may not have configured a provider if they manually manage `opencode`.
      vim.notify(
        "No provider configured for `opencode.nvim` — configure `vim.g.opencode_opts.provider`, or install `snacks.nvim` to use the default embedded terminal",
        vim.log.levels.ERROR,
        { title = "opencode" }
      )
    end
  end,
  start = function()
    if provider then
      provider.start(cmd, opts)
    end
  end,
  show = function()
    if provider then
      provider.show(cmd, opts)
    end
  end,
}
