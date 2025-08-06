---Calls the opencode [server](https://github.com/sst/opencode/blob/dev/packages/opencode/src/server/server.ts).
local M = {}

local origin = "http://localhost:"
local partial_event = {}

---@param data table
---@param callback fun(response: table)|nil
local function sse_handle(data, callback)
  for _, line in ipairs(data) do
    if line ~= "" then
      if type(partial_event) ~= "table" then
        partial_event = {}
      end
      local clean_line = (line:gsub("^data: ?", ""))
      table.insert(partial_event, clean_line)
    else
      line = line:gsub("^data: ", "")
      if line == "" and partial_event == {} then
        return
      end
      if line ~= "" then
        table.insert(partial_event, line)
      end
      local full_data = table.concat(partial_event)
      partial_event = {} --reset table

      if full_data ~= "" then
        local ok, response = pcall(vim.fn.json_decode, full_data)
        if ok and callback then
          callback(response)
        elseif not ok then
          vim.notify("SSE JSON decode error: " .. full_data, vim.log.levels.ERROR, { title = "opencode" })
        end
      end
    end
  end
end

---@param data table
---@param callback fun(response: table)|nil
local function json_handle(data, callback)
  for _, line in ipairs(data) do
    if line == "" then
      return
    end
    local ok, response = pcall(vim.fn.json_decode, line)
    if not ok then
      vim.notify("JSON decode error: " .. line, vim.log.levels.ERROR, { title = "opencode" })
    else
      if callback then
        callback(response)
      end
    end
  end
end

---@param url string
---@param method string
---@param body table|nil
---@param callback fun(response: table)|nil
---@param is_sse boolean|nil
local function curl(url, method, body, callback, is_sse)
  local command = {
    "curl",
    "-s",
    "-X",
    method,
    "-H",
    "Content-Type: application/json",
    "-H",
    "Accept: application/json",
    "-H",
    "Accept: text/event-stream",
    "-N", -- No buffering, for streaming SSEs
    body and "-d" or nil,
    body and vim.fn.json_encode(body) or nil,
    url,
  }

  local stderr_lines = {}
  vim.fn.jobstart(command, {
    on_stdout = function(_, data)
      if is_sse then
        sse_handle(data, callback)
      else
        json_handle(data, callback)
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
      -- 18 means connection closed while there was more data to read, which happens occasionally with SSEs when we quit opencode. nbd.
      if code ~= 0 and code ~= 18 then
        local error_message = "curl command failed with exit code: "
          .. code
          .. "\n\nstderr:\n"
          .. table.concat(stderr_lines, "\n")
        vim.notify(error_message, vim.log.levels.ERROR, { title = "opencode" })
      end
    end,
  })
end

---@param port number
---@param callback fun(response: table)|nil
function M.sse_listen(port, callback)
  curl(origin .. port .. "/event", "GET", nil, callback, true)
end

---@param text string
---@param port number
---@param callback fun(response: table)|nil
function M.tui_append_prompt(text, port, callback)
  curl(origin .. port .. "/tui/append-prompt", "POST", { text = text }, callback)
end

---@param port number
---@param callback fun(response: table)|nil
function M.tui_submit_prompt(port, callback)
  curl(origin .. port .. "/tui/submit-prompt", "POST", {}, callback)
end

---@param port number
---@param callback fun(response: table)|nil
function M.tui_clear_prompt(port, callback)
  curl(origin .. port .. "/tui/clear-prompt", "POST", {}, callback)
end

---@param command string
---@param port number
function M.tui_execute_command(command, port)
  curl(origin .. port .. "/tui/execute-command", "POST", { command = command })
end

---@param prompt string
---@param session_id string
---@param port number
---@param provider_id string
---@param model_id string
---@param callback fun(response: table)|nil
function M.send(prompt, session_id, port, provider_id, model_id, callback)
  local body = {
    sessionID = session_id,
    providerID = provider_id,
    modelID = model_id,
    parts = {
      {
        type = "text",
        id = vim.fn.system("uuidgen"):gsub("\n", ""),
        text = prompt,
      },
    },
  }

  curl(origin .. port .. "/session/" .. session_id .. "/message", "POST", body, callback)
end

---@param port number
---@param callback fun(sessions: table)
function M.get_sessions(port, callback)
  curl(origin .. port .. "/session", "GET", nil, callback)
end

---@param port number
---@param callback fun(session: table)
function M.create_session(port, callback)
  curl(origin .. port .. "/session", "POST", nil, callback)
end

return M
