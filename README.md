# opencode.nvim

Seamlessly integrate the [opencode](https://github.com/sst/opencode) AI assistant with Neovim.

https://github.com/user-attachments/assets/be5c8545-c69d-456e-91a4-42acee7a49c1

> [!NOTE]
> Uses opencode's currently undocumented, likely unstable [API](https://github.com/sst/opencode/blob/dev/packages/opencode/src/server/server.ts).
>
> Latest tested opencode version: `v0.4.1`

## ✨ Features

- Auto-find any `opencode` process running inside Neovim's CWD or open in an embedded terminal
- Select and input customizable prompts
- Inject customizable editor context
- Auto-reload edited buffers
- Write and refine prompts quickly with completion, highlight, and normal-mode support

## 🕵️ Context

When your prompt contains placeholders, `opencode.nvim` will replace them with context before sending:

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

## 📦 Setup

<details>
<summary><a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
{
  'NickvanDyke/opencode.nvim',
  dependencies = { 'folke/snacks.nvim', },
  ---@type opencode.Config
  opts = {
    -- Your configuration, if any
  },
  -- stylua: ignore
  keys = {
    { '<leader>ot', function() require('opencode').toggle() end, desc = 'Toggle embedded opencode', },
    { '<leader>oa', function() require('opencode').ask() end, desc = 'Ask opencode', mode = 'n', },
    { '<leader>oa', function() require('opencode').ask('@selection: ') end, desc = 'Ask opencode about selection', mode = 'v', },
    { '<leader>op', function() require('opencode').select_prompt() end, desc = 'Select prompt', mode = { 'n', 'v', }, },
    { '<leader>on', function() require('opencode').command('session_new') end, desc = 'New session', },
    { '<leader>oy', function() require('opencode').command('messages_copy') end, desc = 'Copy last message', },
    { '<S-C-u>',    function() require('opencode').command('messages_half_page_up') end, desc = 'Scroll messages up', },
    { '<S-C-d>',    function() require('opencode').command('messages_half_page_down') end, desc = 'Scroll messages down', },
  },
}
```
</details>

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

See all the available options and their defaults [here](./lua/opencode/config.lua#L12).

> [!TIP]
> `opencode.nvim` offers a flexible [API](./lua/opencode.lua) — customize prompts, contexts, and keymaps to fit your workflow!

### Prompts

Add custom selectable prompts to `opts.prompts`:

```lua
{
  prompts = {
    joke = {
      description = 'Tell me a cat joke',
      prompt = 'Tell me a joke about cats. Make it funny, but not too funny.',
    },
  },
}
```

Add keymaps for your favorite [built-in](./lua/opencode/config.lua#L17) or custom prompts:

```lua
local prompts = require('opencode.config').options.prompts or {}
vim.keymap.set('n', '<leader>oj', function() require('opencode').prompt(prompts.joke.prompt) end, { desc = prompts.joke.description })

vim.keymap.set('v', '<leader>os', function() require('opencode').prompt("Tell me a story about cats and @selection") end, { desc = "Tell me a story" })
```

### Contexts

Add custom contexts to `opts.contexts`. The below replaces `@grapple` with files tagged by [grapple.nvim](https://github.com/cbochs/grapple.nvim):

```lua
{
  contexts = {
    ---@type opencode.Context
    ['@grapple'] = {
      description = 'Files tagged by grapple',
      value = function()
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
    },
  }
}
```

## ✍️ Completion

`opencode.nvim` offers context placeholder completions in the `ask` input.

<details>
<summary><a href="https://github.com/Saghen/blink.cmp">blink.cmp</a></summary>

`opencode.nvim` automatically registers `opts.auto_register_cmp_sources` (default: `{ "opencode", "buffer" }`) with `blink.cmp` (if loaded) at runtime.
</details>

<details>
<summary>Built-in</summary>

Press `<Tab>` to trigger Neovim's built-in completion.
</details>

## 👀 Events

`opencode.nvim` forwards opencode's Server-Sent-Events as an autocmd:

```lua
-- Listen for opencode events
vim.api.nvim_create_autocmd("User", {
  pattern = "OpencodeEvent",
  callback = function(args)
    -- See the available event types and their properties
    vim.notify(vim.inspect(args.data), vim.log.levels.DEBUG)
    -- Do something interesting, like show a notification when opencode finishes responding
    if args.data.type == "session.idle" then
      vim.notify("opencode finished responding", vim.log.levels.INFO)
    end
  end,
})
```

## 🌈 Highlights

| Name | Description |
| - | - |
| `OpencodePlaceholder` | Placeholders in `ask` input |

## 🔧 Troubleshooting

### Port Detection Issues

If `opencode.nvim` can't find your opencode server, use the diagnostic tool:

```lua
:lua require('opencode').show_diagnostics()
```

#### Manual Configuration

1. **Environment Variable** (recommended for temporary fixes):
   ```bash
   export OPENCODE_PORT=37669
   nvim
   ```

2. **Plugin Configuration** (permanent):
   ```lua
   require('opencode').setup({
     port = 37669,  -- Your opencode port
   })
   ```

3. **Finding the Port Manually**:
   ```bash
   # List opencode processes
   ps aux | grep opencode
   
   # Find listening ports (Linux)
   ss -tlnp | grep opencode
   lsof -i -P | grep LISTEN | grep opencode
   
   # Find listening ports (macOS)
   lsof -i -P | grep LISTEN | grep opencode
   ```

#### Debug Mode

Enable verbose logging to see detailed detection attempts:

```bash
export OPENCODE_DEBUG=1
nvim
```

This will show:
- Which detection methods are being tried
- Process discovery details
- Port verification attempts
- Exact failure points

### Common Issues

- **Multiple opencode instances**: The plugin looks for opencode running in Neovim's CWD. If you have multiple instances, it may pick the wrong one.
- **Permission issues**: Some detection methods (like `netstat -p` on Linux) may require elevated permissions.
- **Firewall/Security software**: Ensure opencode's port isn't being blocked.

## 🙏 Acknowledgments

- Inspired by (and partially based on) [nvim-aider](https://github.com/GeorgesAlkhouri/nvim-aider) and later [neopencode.nvim](https://github.com/loukotal/neopencode.nvim).
- `opencode.nvim` uses opencode's TUI for simplicity — see [sudo-tee/opencode.nvim](https://github.com/sudo-tee/opencode.nvim) for a Neovim frontend.
- [mcp-neovim-server](https://github.com/bigcodegen/mcp-neovim-server) may better suit you, but it lacks customization and tool calls are slow and unreliable.
