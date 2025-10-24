---@class opencode.Provider
---
---Called by `require("opencode").toggle()`.
---@field toggle fun(opts: opencode.Provider.Opts)
---
---Called when no `opencode` process is found so you can start it,
---after which `opencode.nvim` polls for a couple seconds to see if one appears.
---@field start fun(opts: opencode.Provider.Opts)
---
---Called when a prompt or command is sent to `opencode`.
---@field show fun(opts: opencode.Provider.Opts)

---@class opencode.Provider.Opts
---
---The command to start `opencode`.
---`opencode.nvim` will append `--port <port>` if `vim.g.opencode_opts.port` is set.
---@field cmd string

local opt = require("opencode.config").opts.provider
local opts = opt and opt.opts or {}
-- Load provider module if a name is specified.
local provider = opt and opt.name and require("opencode.providers." .. opt.name) or opt

-- Auto-add `--port <port>` to command if set and not already present.
if opts.cmd and not opts.cmd:find("--port") then
  opts.cmd = opts.cmd .. " --port " .. tostring(require("opencode.config").opts.port)
end

---Wraps `opts.provider`.
return {
  toggle = function()
    if provider then
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
    if provider then
      provider.start(opts)
    end
  end,
  show = function()
    if provider then
      provider.show(opts)
    end
  end,
}
