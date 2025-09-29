# opencode.nvim

Seamlessly integrate the [opencode](https://github.com/sst/opencode) AI assistant with Neovim — convenient and editor-aware research, reviews, and requests. 

https://github.com/user-attachments/assets/340ce139-173c-4e81-b39a-f089862db9ce

> Uses `opencode`'s currently undocumented [API](https://github.com/sst/opencode/blob/dev/packages/opencode/src/server/server.ts) — latest tested version: `v0.9.1`

## ✨ Features

- Open `opencode` in an embedded terminal, or auto-connect to one matching Neovim's CWD.
- Input prompts with completions, highlights, and normal-mode support.
- Select from a built-in prompt library and define custom prompts.
- Inject relevant editor context (buffer, selection, cursor, diagnostics, etc.).
- Auto-reload buffers edited by `opencode` in real-time.
- Forward `opencode`'s Server-Sent-Events as Neovim autocmds for automation.
- Sensible defaults with well-documented, flexible configuration and API.

## 📦 Setup

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'NickvanDyke/opencode.nvim',
  dependencies = {
    -- Recommended for better prompt input, and required to use `opencode.nvim`'s embedded terminal — otherwise optional
    { 'folke/snacks.nvim', opts = { input = { enabled = true } } },
  },
  config = function()
    vim.g.opencode_opts = {
      -- Your configuration, if any — see `lua/opencode/config.lua`
    }

    -- Required for `opts.auto_reload`
    vim.opt.autoread = true

    -- Recommended/example keymaps
    vim.keymap.set('n', '<leader>ot', function() require('opencode').toggle() end, { desc = 'Toggle embedded' })
    vim.keymap.set('n', '<leader>oA', function() require('opencode').ask() end, { desc = 'Ask' })
    vim.keymap.set('n', '<leader>oa', function() require('opencode').ask('@cursor: ') end, { desc = 'Ask about this' })
    vim.keymap.set('v', '<leader>oa', function() require('opencode').ask('@selection: ') end, { desc = 'Ask about selection' })
    vim.keymap.set('n', '<leader>oe', function() require('opencode').prompt('Explain @cursor and its context') end, { desc = 'Explain this code' })
    vim.keymap.set('n', '<leader>o+', function() require('opencode').prompt('@buffer', { append = true }) end, { desc = 'Add buffer to prompt' })
    vim.keymap.set('v', '<leader>o+', function() require('opencode').prompt('@selection', { append = true }) end, { desc = 'Add selection to prompt' })
    vim.keymap.set('n', '<leader>on', function() require('opencode').command('session_new') end, { desc = 'New session' })
    vim.keymap.set('n', '<S-C-u>',    function() require('opencode').command('messages_half_page_up') end, { desc = 'Messages half page up' })
    vim.keymap.set('n', '<S-C-d>',    function() require('opencode').command('messages_half_page_down') end, { desc = 'Messages half page down' })
    vim.keymap.set({ 'n', 'v' }, '<leader>os', function() require('opencode').select() end, { desc = 'Select prompt' })
  end,
}
```

<details>
<summary><a href="https://github.com/nix-community/nixvim">nixvim</a></summary>

```nix
programs.nixvim = {
  extraPlugins = [
    pkgs.vimPlugins.opencode-nvim
  ];
  keymaps = [
    { key = "<leader>ot"; action = "<cmd>lua require('opencode').toggle()<CR>"; }
    { key = "<leader>oa"; action = "<cmd>lua require('opencode').ask()<CR>"; mode = "n"; }
    { key = "<leader>oa"; action = "<cmd>lua require('opencode').ask('@selection: ')<CR>"; mode = "v"; }
    { key = "<leader>oe"; action = "<cmd>lua require('opencode').select_prompt()<CR>"; mode = ["n" "v"]; }
    { key = "<leader>on"; action = "<cmd>lua require('opencode').command('session_new')<CR>"; }
  ];
};
```
</details>

## ⚙️ Configuration

`opencode.nvim` strives to provide a rich and reliable default experience, with a well-documented and flexible [configuration](./lua/opencode/config.lua#L47) and [API](./lua/opencode.lua) for you to customize and build on according to your preferences.

## 🕵️ Context

When your prompt contains placeholders, `opencode.nvim` replaces them with context before sending:

| Placeholder | Context |
| - | - |
| `@buffer` | Current buffer |
| `@buffers` | Open buffers |
| `@cursor` | Cursor position |
| `@selection` | Selected text |
| `@visible` | Visible text |
| `@diagnostic` | Current line diagnostics |
| `@diagnostics` | Current buffer diagnostics |
| `@quickfix` | Quickfix list |
| `@diff` | Git diff |
| `@grapple` | [grapple.nvim](https://github.com/cbochs/grapple.nvim) tags |

Add custom contexts to `opts.contexts`.

## 👀 Events

`opencode.nvim` forwards `opencode`'s Server-Sent-Events as an `OpencodeEvent` autocmd:

```lua
-- Listen for opencode events
vim.api.nvim_create_autocmd("User", {
  pattern = "OpencodeEvent",
  callback = function(args)
    -- See the available event types and their properties
    vim.notify(vim.inspect(args.data))
    -- Do something interesting, like show a notification when opencode finishes responding
    if args.data.type == "session.idle" then
      vim.notify("opencode finished responding")
    end
  end,
})
```

## 🙏 Acknowledgments

- Inspired by (and partially based on) [nvim-aider](https://github.com/GeorgesAlkhouri/nvim-aider) and later [neopencode.nvim](https://github.com/loukotal/neopencode.nvim).
- `opencode.nvim` uses opencode's TUI for simplicity — see [sudo-tee/opencode.nvim](https://github.com/sudo-tee/opencode.nvim) for a Neovim frontend.
- [mcp-neovim-server](https://github.com/bigcodegen/mcp-neovim-server) may better suit you, but it lacks customization and tool calls are slow and unreliable.
