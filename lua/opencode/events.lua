local M = {}

---@class opencode.events.Opts
---
---Whether to subscribe to Server-Sent Events (SSE) from `opencode` and execute `OpencodeEvent:<event.type>` autocmds.
---@field enabled? boolean
---
---Reload buffers edited by `opencode` in real-time.
---Requires `vim.o.autoread = true`.
---@field reload? boolean
---
---@field permissions? opencode.events.permissions.Opts

---Subscribe to `opencode`'s Server-Sent Events (SSE) and execute `OpencodeEvent:<event.type>` autocmds.
---
---@param port number
function M.subscribe_to_sse(port)
  require("opencode.cli.client").subscribe_to_sse(
    port,
    ---@param response opencode.cli.client.Event
    function(response)
      vim.api.nvim_exec_autocmds("User", {
        pattern = "OpencodeEvent:" .. response.type,
        data = {
          event = response,
          port = port,
        },
      })
    end
  )
end

return M
