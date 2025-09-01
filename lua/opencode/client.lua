---Calls the opencode [server](https://github.com/sst/opencode/blob/dev/packages/opencode/src/server/server.ts).
local M = {}

-- Persistent buffer for SSE lines, because SSEs can span multiple `on_stdout` calls.
local sse_buffer = {}

---@param data table
---@return table|nil
local function handle_sse(data)
  for _, line in ipairs(data) do
    if line ~= "" then
      local clean_line = (line:gsub("^data: ?", ""))
      table.insert(sse_buffer, clean_line)
    elseif #sse_buffer > 0 then
      -- Blank line: end of event. Process the accumulated event.
      local full_event = table.concat(sse_buffer)
      sse_buffer = {} -- Reset for next event

      local ok, response = pcall(vim.fn.json_decode, full_event)
      if ok then
        return response
      else
        vim.notify("SSE JSON decode error: " .. full_event, vim.log.levels.ERROR, { title = "opencode" })
      end
    end
  end
end

---@param data table
---@return table|nil
local function handle_json(data)
  for _, line in ipairs(data) do
    if line == "" then
      return
    end
    local ok, response = pcall(vim.fn.json_decode, line)
    if ok then
      return response
    else
      vim.notify("JSON decode error: " .. line, vim.log.levels.ERROR, { title = "opencode" })
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
      local response = is_sse and handle_sse(data) or handle_json(data)
      if response and callback then
        callback(response)
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
          .. "\nstderr:\n"
          .. (#stderr_lines > 0 and table.concat(stderr_lines, "\n") or "<none>")
        vim.notify(error_message, vim.log.levels.ERROR, { title = "opencode" })
      end
    end,
  })
end

---Call an opencode server endpoint.
---@param port number
---@param path string
---@param method string
---@param body table|nil
---@param callback fun(response: table)|nil
---@param is_sse boolean|nil
function M.call(port, path, method, body, callback, is_sse)
  curl("http://localhost:" .. port .. path, method, body, callback, is_sse)
end

---@param text string
---@param port number
---@param callback fun(response: table)|nil
function M.tui_append_prompt(text, port, callback)
  M.call(port, "/tui/append-prompt", "POST", { text = text }, callback)
end

---@param port number
---@param callback fun(response: table)|nil
function M.tui_submit_prompt(port, callback)
  M.call(port, "/tui/submit-prompt", "POST", {}, callback)
end

---@param port number
---@param callback fun(response: table)|nil
function M.tui_clear_prompt(port, callback)
  M.call(port, "/tui/clear-prompt", "POST", {}, callback)
end

---@param command string
---@param port number
function M.tui_execute_command(command, port)
  M.call(port, "/tui/execute-command", "POST", { command = command })
end

---@param prompt string
---@param session_id string
---@param port number
---@param provider_id string
---@param model_id string
---@param callback fun(response: table)|nil
function M.send_message(prompt, session_id, port, provider_id, model_id, callback)
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

  M.call(port, "/session/" .. session_id .. "/message", "POST", body, callback)
end

---@param port number
---@param callback fun(sessions: table)
function M.get_sessions(port, callback)
  M.call(port, "/session", "GET", nil, callback)
end

---@param port number
---@param callback fun(session: table)
function M.create_session(port, callback)
  M.call(port, "/session", "POST", nil, callback)
end

---@param port number
---@param callback fun(response: table)|nil
function M.listen_for_sse(port, callback)
  M.call(port, "/event", "GET", nil, callback, true)
end

return M
