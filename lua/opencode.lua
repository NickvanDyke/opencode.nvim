local M = {}

local config = require("opencode.config")
local context = require("opencode.context")
local client = require("opencode.client")
local server = require("opencode.server")

---@param opts opencode.Config
function M.setup(opts)
  config.setup(opts)
end

---Send a prompt to opencode.
---Injects context before sending.
---@param prompt string Prompt to send to opencode.
---@param opts? opencode.Config Optional config to merge for this call only.
function M.prompt(prompt, opts)
  opts = vim.tbl_deep_extend("force", {}, config.options, opts or {})

  local context_injected_prompt = context.inject(prompt, opts)

  local server_pid
  for _, pid in ipairs(server.get_all_pids()) do
    local opencode_cwd = server.get_cwd(pid)
    -- CWDs match exactly, or opencode's CWD is under neovim's CWD.
    if opencode_cwd and string.find(opencode_cwd, vim.fn.getcwd(), 1, true) == 1 then
      server_pid = pid
      break
    end
  end

  if not server_pid then
    vim.notify("Couldn't find an opencode server process running in or under Neovim's CWD", vim.log.levels.ERROR)
    return
  end

  local server_port = server.get_port(server_pid)
  print("server_port", server_port)

  if not server_port then
    return
  end

  client.get_sessions(server_port, function(sessions)
    if not sessions or #sessions == 0 then
      vim.notify("No opencode sessions found", vim.log.levels.ERROR)
      return
    end

    -- TODO: I don't see a way to get the currently active session in the TUI.
    -- Kinda awkward because when the TUI currently has no open session,
    -- we can create one, but we can't then open it in the TUI.
    -- Also awkward because user might change sessions in TUI, but they need
    -- to then send a message there for it to be the active session here.

    -- Find the most recently interacted session.
    local most_recent_session_id = sessions[1].id
    local max_updated = sessions[1].time.updated
    for _, session in ipairs(sessions) do
      if session.time.updated > max_updated then
        max_updated = session.time.updated
        most_recent_session_id = session.id
      end
    end
    client.send(prompt, most_recent_session_id, server_port, opts)
  end)
end

---Input a prompt to send to opencode.
---Convenience function that calls `prompt` internally.
---@param prefill? string Text to prefill the input with.
---@param opts? opencode.Config Optional config to merge for this call only.
function M.ask(prefill, opts)
  vim.ui.input({ prompt = "Ask opencode: ", default = prefill }, function(input)
    if input ~= nil then
      M.prompt(input, opts)
    end
  end)
end

-- TODO: Another convenience function that shows a floating buffer to input a prompt.

return M
