---@class opencode.Provider
---
---Called by `require("opencode").toggle()`.
---@field toggle fun(opts: opencode.providers.Opts)
---
---Called when no `opencode` process is found,
---after which `opencode.nvim` polls for a couple seconds waiting for one to appear.
---@field start fun(opts: opencode.providers.Opts)
---
---Called when a prompt or command is sent to `opencode`.
---Consider no-oping if the provider hasn't already started so you can alternate with external `opencode`s.
---@field show fun(opts: opencode.providers.Opts)

---@class opencode.providers.Opts
---
---The command to start `opencode`.
---`opencode.nvim` will append `--port <port>` if `vim.g.opencode_opts.port` is set.
---@field cmd string

---@class opencode.providers.Custom : opencode.Provider, opencode.providers.Opts

local opts = require("opencode.config").opts.provider
-- Load provider module if a name is specified.
local provider = opts and opts.name and require("opencode.providers." .. opts.name) or opts

-- Auto-add `--port <port>` to command if set and not already present.
local port = require("opencode.config").opts.port
if port and opts and not opts.cmd:find("--port") then
  opts.cmd = opts.cmd .. " --port " .. tostring(port)
end

---Wraps `opts.provider`.
return {
  toggle = function()
    if provider and opts then
      provider.toggle(opts)
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
    if provider and opts then
      provider.start(opts)
    end
  end,
  show = function()
    if provider and opts then
      provider.show(opts)
    end
  end,
}
