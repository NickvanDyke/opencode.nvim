---Call the `opencode` server.
--- - [docs](https://opencode.ai/docs/server/#apis)
--- - [implementation](https://github.com/sst/opencode/blob/dev/packages/opencode/src/server/server.ts)
local M = {}

local sse_state = {
  -- Important to track the port, not just true/false,
  -- because opencode may have restarted (usually on a new port) while the plugin is running.
  port = nil,
  -- Persistent buffer for SSE lines, because SSEs can span multiple `on_stdout` calls.
  buffer = {},
  job_id = nil,
}

---@param data table
---@return table|nil
local function handle_sse(data)
  for _, line in ipairs(data) do
    if line ~= "" then
      local clean_line = (line:gsub("^data: ?", ""))
      table.insert(sse_state.buffer, clean_line)
    elseif #sse_state.buffer > 0 then
      -- Blank line: end of event. Process the accumulated event.
      local full_event = table.concat(sse_state.buffer)
      sse_state.buffer = {} -- Reset for next event

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
---@return number job_id
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
  return vim.fn.jobstart(command, {
    on_stdout = function(_, data)
      local response
      if is_sse then
        response = handle_sse(data)
      else
        response = handle_json(data)
      end
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
---@param method "GET"|"POST"
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
  M.call(port, "/tui/submit-prompt", "POST", vim.empty_dict(), callback)
end

---@param port number
---@param callback fun(response: table)|nil
function M.tui_clear_prompt(port, callback)
  M.call(port, "/tui/clear-prompt", "POST", vim.empty_dict(), callback)
end

---@param command string
---@param port number
---@param callback fun(response: table)|nil
function M.tui_execute_command(command, port, callback)
  M.call(port, "/tui/execute-command", "POST", { command = command }, callback)
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
  M.call(port, "/session", "POST", vim.empty_dict(), callback)
end

---@param port number
---@param session number
---@param permission number
---@param response "once"|"always"|"reject"
---@param callback? fun(session: table)
function M.permit(port, session, permission, response, callback)
  M.call(port, "/session/" .. session .. "/permissions/" .. permission, "POST", {
    response = response,
  }, callback)
end

---Calls the `/event` SSE endpoint and invokes `callback` for each event received.
---
---@param port number
---@param callback fun(response: table)|nil
function M.listen_to_sse(port, callback)
  if sse_state.port ~= port then
    if sse_state.job_id then
      vim.fn.jobstop(sse_state.job_id)
    end

    sse_state = {
      port = port,
      buffer = {},
      job_id = M.call(port, "/event", "GET", nil, callback, true),
    }
  end
end

return M
