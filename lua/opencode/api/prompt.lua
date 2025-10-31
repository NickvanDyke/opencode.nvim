local M = {}

---@class opencode.prompt.Opts
---@field clear? boolean Clear the TUI input before.
---@field submit? boolean Submit the TUI input after.
---@field context? opencode.Context The context the prompt was written or selected in, if any.

---Prompt `opencode`.
---
---1. Resolves `prompt` if it's a prompt name from `opts.prompts`.
---2. Clears the TUI input if `opts.clear`.
---3. Injects `opts.contexts` into `prompt`.
---4. Appends `prompt` to the TUI input.
---5. Submits the TUI input if `opts.submit`.
---6. Listens for Server-Sent-Events to forward as `OpencodeEvent` autocmd.
---7. Calls `callback` if provided.
---
---@param prompt string The prompt to send to `opencode`, or a prompt name from `opts.prompts`.
---@param opts? opencode.prompt.Opts
---@param callback? fun()
function M.prompt(prompt, opts, callback)
  local referenced_prompt = require("opencode.config").opts.prompts[prompt]
  prompt = referenced_prompt and referenced_prompt.prompt or prompt
  opts = {
    clear = opts and opts.clear or false,
    submit = opts and opts.submit or false,
    context = opts and opts.context or require("opencode.context").new(),
  }

  require("opencode.cli.server").get_port(function(ok, port)
    if not ok then
      vim.notify(port, vim.log.levels.ERROR, { title = "opencode" })
      return
    end

    require("opencode.provider").show()

    require("opencode.util").chain({
      function(next)
        if opts.clear then
          require("opencode.cli.client").tui_clear_prompt(port, next)
        else
          next()
        end
      end,
      function(next)
        local rendered = opts.context:render(prompt)
        local plaintext = opts.context.plaintext(rendered.output)
        require("opencode.cli.client").tui_append_prompt(plaintext, port, next)
      end,
      function(next)
        if opts.submit then
          -- WARNING: If user never prompts opencode via the plugin, we'll never receive SSEs.
          -- Could register in `/plugin` and even periodically check, but is it worth the complexity and performance hit?
          require("opencode.cli.client").listen_to_sse(port, function(response)
            vim.api.nvim_exec_autocmds("User", {
              pattern = "OpencodeEvent",
              data = {
                event = response,
                port = port,
              },
            })
          end)

          require("opencode.cli.client").tui_submit_prompt(port, next)
        else
          next()
        end
      end,
      function()
        if callback then
          callback()
        end
      end,
    })
  end)
end

return M
