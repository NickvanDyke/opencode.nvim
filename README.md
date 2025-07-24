# opencode.nvim

Send editor-aware prompts to the powerful [opencode AI](https://github.com/sst/opencode) from Neovim.

https://github.com/user-attachments/assets/331271d7-e590-4e30-a161-5c643909a922

> [!NOTE]
> Uses opencode's currently undocumented, likely unstable [API](https://github.com/sst/opencode/blob/dev/packages/opencode/src/server/server.ts).
> 
> Latest tested opencode version: `v0.3.58`

## ✨ Features

- Finds your `opencode` process running in or under Neovim's CWD
- Sends prompts to its active session
- Injects customizable editor context
- Auto-reloads edited buffers

> Please use the opencode TUI to manage its active session until [the plugin can do so](https://github.com/sst/opencode/issues/1255).

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'NickvanDyke/opencode.nvim',
  ---@type opencode.Config
  opts = {
    -- Your configuration, if any
  },
  -- stylua: ignore
  keys = {
    -- opencode.nvim exposes a general, flexible API — customize it to your workflow!
    -- But here are some examples to get you started :)
    { '<leader>oa', function() require('opencode').ask() end, desc = 'Ask opencode', mode = { 'n', 'v' }, },
    { '<leader>oA', function() require('opencode').ask('@file ') end, desc = 'Ask opencode about current file', mode = { 'n', 'v' }, },
    { '<leader>oe', function() require('opencode').prompt('Explain @cursor and its context') end, desc = 'Explain code near cursor' },
    { '<leader>or', function() require('opencode').prompt('Review @file for correctness and readability') end, desc = 'Review file', },
    { '<leader>of', function() require('opencode').prompt('Fix these @diagnostics') end, desc = 'Fix errors', },
    { '<leader>oo', function() require('opencode').prompt('Optimize @selection for performance and readability') end, desc = 'Optimize selection', mode = 'v', },
    { '<leader>od', function() require('opencode').prompt('Add documentation comments for @selection') end, desc = 'Document selection', mode = 'v', },
    { '<leader>ot', function() require('opencode').prompt('Add tests for @selection') end, desc = 'Test selection', mode = 'v', },
  },
}
```

## ⚙️ Configuration

Default settings:

```lua
---@type opencode.Config
{
  model_id = "gpt-4.1",            -- Model to use for opencode requests — see https://models.dev/
  provider_id = "github-copilot",  -- Provider to use for opencode requests — see https://models.dev/
  port = nil,                      -- The port opencode is running on — use `opencode --port <port>`. If `nil`, tries to find a running instance in or under Neovim's CWD.
  auto_reload = false,             -- Automatically reload buffers edited by opencode
  context = {                      -- Context to inject in prompts
    ["@file"] = require("opencode.context").file,
    ["@files"] = require("opencode.context").files,
    ["@cursor"] = require("opencode.context").cursor_position,
    ["@selection"] = require("opencode.context").visual_selection,
    ["@diagnostics"] = require("opencode.context").diagnostics,
    ["@quickfix"] = require("opencode.context").quickfix,
    ["@diff"] = require("opencode.context").git_diff,
  },
}
```

## 🕵️‍♂️ Context

When your prompt contains placeholders, the plugin will replace it with context before sending:

| Placeholder | Context |
| - | - |
| `@file` | Current file |
| `@files` | Open files |
| `@cursor` | Cursor position |
| `@selection` | Selected text |
| `@diagnostics` | Current buffer diagnostics |
| `@quickfix` | Quickfix list |
| `@diff` | Git diff |

Add custom contexts via `opts.context`. The below replaces `@grapple` with files tracked by [grapple.nvim](https://github.com/cbochs/grapple.nvim):

```lua
---@type opencode.Config
{
  context = {
    ---@return string|nil
    ['@grapple'] = function()
      local tags = require('grapple').tags()
      if not tags or #tags == 0 then
        return nil
      end

      local paths = {}
      for _, tag in ipairs(tags) do
        table.insert(paths, tag.path)
      end
      return table.concat(paths, ', ')
    end,
  }
}
```

## 👀 Events

You can prompt opencode on Neovim events:

```lua
-- Prompt opencode to fix diagnostics whenever they change in the current buffer.
-- Kind of annoying and should at least debounce, but just to show what's possible.
vim.api.nvim_create_autocmd('DiagnosticChanged', {
  callback = function(args)
    local diagnostics = vim.diagnostic.get(args.buf)
    if #diagnostics > 0 then
      require('opencode').prompt('Fix these @diagnostics')
    end
  end,
})
```

## 💻 Embedded

`opencode.nvim` calls *any* `opencode` process running in or under Neovim's CWD, but you can easily embed it in Neovim using [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md):

```lua
{
  'NickvanDyke/opencode.nvim',
  dependencies = {
    'folke/snacks.nvim',
  },
  keys = {
    {
      '<leader>ot',
      function()
        require('snacks.terminal').toggle('opencode', { win = { position = 'right' } })
      end,
      desc = "Toggle opencode",
    },
  }
}
```

> [!IMPORTANT]
> Set your [opencode theme](https://opencode.ai/docs/themes/) to `system` — other themes currently have [visual bugs in embedded terminals](https://github.com/sst/opencode/issues/445).

## 🙏 Acknowledgments

- Inspired by (and partially based on) [nvim-aider](https://github.com/GeorgesAlkhouri/nvim-aider) and later [neopencode.nvim](https://github.com/loukotal/neopencode.nvim).
- This plugin uses opencode's familiar TUI for simplicity — see [sudo-tee/opencode.nvim](https://github.com/sudo-tee/opencode.nvim) for a Neovim frontend.
- [mcp-neovim-server](https://github.com/bigcodegen/mcp-neovim-server) may better suit you, but it lacks customization and tool calls are slow and unreliable.
