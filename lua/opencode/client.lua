local config = require("opencode.config")

---Calls the opencode [server](https://github.com/sst/opencode/blob/dev/packages/opencode/src/server/server.ts).
local M = {}

---@param url string
---@param method string
---@param body table|nil
---@param callback fun(response: table)|nil
local function curl(url, method, body, callback)
  local command = {
    "curl",
    "-s",
    "-X",
    method,
    "-H",
    "Content-Type: application/json",
    body and "-d" or nil,
    body and vim.fn.json_encode(body) or nil,
    url,
  }

  local stderr_lines = {}
  vim.fn.jobstart(command, {
    on_stdout = function(_, data)
      if data and #data > 0 then
        local response_str = table.concat(data, "")
        if response_str == "" then
          return
        end
        local ok, response = pcall(vim.fn.json_decode, response_str)
        if not ok then
          vim.notify("JSON decode error: " .. response_str, vim.log.levels.ERROR)
        else
          if callback then
            callback(response)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stderr_lines, line)
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        local error_message = "curl command failed with exit code: "
          .. code
          .. "\n\nstderr:\n"
          .. table.concat(stderr_lines, "\n")
        vim.notify(error_message, vim.log.levels.ERROR)
      end
    end,
  })
end

---@param prompt string
---@param session_id string
---@param port number
---@param opts opencode.Config
function M.send(prompt, session_id, port, opts)
  local url = "http://localhost:" .. port .. "/session/" .. session_id .. "/message"
  local body = {
    sessionID = session_id,
    providerID = opts.provider_id,
    modelID = opts.model_id,
    parts = {
      {
        type = "text",
        id = vim.fn.system("uuidgen"):gsub("\n", ""),
        text = prompt,
      },
    },
  }

  curl(url, "POST", body)
end

---@param port number
---@param callback fun(sessions: table)
function M.get_sessions(port, callback)
  local url = "http://localhost:" .. port .. "/session"

  curl(url, "GET", nil, callback)
end

function M.create_session(port, callback)
  local url = "http://localhost:" .. port .. "/session"

  curl(url, "POST", nil, callback)
end

return M
