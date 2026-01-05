---Event handler for custom chat frontend
local M = {}

---@type number|nil
local sse_job_id = nil

---Subscribe to opencode events and update chat UI
---@param port number
function M.subscribe(port)
  local chat = require("opencode.ui.chat")

  -- Unsubscribe from previous if any
  M.unsubscribe()

  -- Subscribe to SSE events
  sse_job_id = require("opencode.cli.client").call(port, "/event", "GET", nil, function(event)
    -- Only process events if chat window is still open
    local state = chat.get_state()
    if not state then
      M.unsubscribe()
      return
    end

    -- Handle different event types
    if event.type == "message.delta" then
      -- Streaming message chunk
      local delta = event.properties and event.properties.delta or ""
      local current_msg = state.messages[state.streaming_message_index]
      if current_msg then
        current_msg.text = (current_msg.text or "") .. delta
        chat.render()
      end
    elseif event.type == "message.created" or event.type == "message.updated" then
      -- Complete message
      local msg = event.properties and event.properties.message
      if msg and msg.role == "assistant" then
        -- Check if we have a streaming message to update
        if state.streaming_message_index then
          local current_msg = state.messages[state.streaming_message_index]
          if current_msg then
            current_msg.text = msg.text or current_msg.text or ""
            current_msg.complete = true
            current_msg.streaming = false
            state.streaming_message_index = nil
            chat.render()
          end
        else
          -- Add as new message
          chat.add_message({
            role = msg.role or "assistant",
            text = msg.text or "",
            streaming = false,
            complete = true,
          })
        end
      end
    elseif event.type == "session.created" or event.type == "session.switched" then
      -- New session started or switched
      local session = event.properties and event.properties.session
      if session and session.id then
        chat.set_session_id(session.id)
        -- Add a system message to indicate new session
        chat.add_message({
          role = "system",
          text = "Session started: " .. session.id,
          streaming = false,
          complete = true,
        })
      end
    elseif event.type == "session.idle" then
      -- Session finished responding
      if state.streaming_message_index then
        local msg = state.messages[state.streaming_message_index]
        if msg then
          msg.complete = true
          msg.streaming = false
        end
        state.streaming_message_index = nil
        chat.render()
      end
    elseif event.type == "error" then
      -- Handle errors
      local error_msg = event.properties and event.properties.message or "Unknown error"
      vim.notify("OpenCode error: " .. error_msg, vim.log.levels.ERROR, { title = "opencode" })

      -- Mark streaming message as complete if error occurred
      if state.streaming_message_index then
        local msg = state.messages[state.streaming_message_index]
        if msg then
          msg.text = (msg.text or "") .. "\n\n[Error: " .. error_msg .. "]"
          msg.complete = true
          msg.streaming = false
        end
        state.streaming_message_index = nil
        chat.render()
      end
    end
  end)
end

---Unsubscribe from SSE events
function M.unsubscribe()
  if sse_job_id then
    vim.fn.jobstop(sse_job_id)
    sse_job_id = nil
  end
end

return M
