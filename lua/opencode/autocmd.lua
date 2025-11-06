local M = {}


---Subscribe to Server-Sent Events (SSE) and trigger OpencodeEvent autocmd.
---Listens for SSE responses on the specified port and triggers a User autocmd
---with the pattern "OpencodeEvent" containing the response data.
---
---@param port number The port number to listen for SSE connections
function M.subscribe_to_sse(port)
  require("opencode.cli.client").listen_to_sse(port, function(response)
    vim.api.nvim_exec_autocmds("User", {
      pattern = "OpencodeEvent",
      data = {
        event = response,
        port = port,
      },
    })
  end)
end

return M
