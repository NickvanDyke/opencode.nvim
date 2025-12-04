local M = {}

---@class opencode.prompt.Opts
---@field clear? boolean Clear the TUI input before.
---@field submit? boolean Submit the TUI input after.
---@field context? opencode.Context The context the prompt was written or selected in, if any.

---Prompt `opencode`.
---
--- - Resolves `prompt` if it references an `opts.prompts` entry by name.
--- - Injects `opts.contexts` into `prompt`.
--- - `opencode` will interpret `@` references to files or subagents
---
---@param prompt string
---@param opts? opencode.prompt.Opts
function M.prompt(prompt, opts)
  -- TODO: Referencing `ask = true` prompts doesn't actually ask.
  local referenced_prompt = require("opencode.config").opts.prompts[prompt]
  prompt = referenced_prompt and referenced_prompt.prompt or prompt
  opts = {
    clear = opts and opts.clear or false,
    submit = opts and opts.submit or false,
    context = opts and opts.context or require("opencode.context").new(),
  }

  require("opencode.cli.server")
    .get_port()
    :next(function(port)
      if opts.clear then
        return require("opencode.promise").new(function(resolve)
          require("opencode.cli.client").tui_execute_command("prompt.clear", port, function()
            resolve(port)
          end)
        end)
      end
      return port
    end)
    :next(function(port)
      local rendered = opts.context:render(prompt)
      local plaintext = opts.context.plaintext(rendered.output)
      return require("opencode.promise").new(function(resolve)
        require("opencode.cli.client").tui_append_prompt(plaintext, port, function()
          resolve(port)
        end)
      end)
    end)
    :next(function(port)
      if require("opencode.config").opts.events.enabled then
        require("opencode.events").subscribe_to_sse(port)
      end
      return port
    end)
    :next(function(port)
      if opts.submit then
        require("opencode.cli.client").tui_execute_command("prompt.submit", port)
      end
      return port
    end)
    :catch(function(err)
      vim.notify(err, vim.log.levels.ERROR, { title = "opencode" })
    end)
end

return M
