# opencode.nvim

Seamlessly integrate the [opencode](https://github.com/sst/opencode) AI assistant with Neovim.

https://github.com/user-attachments/assets/4f074c86-6863-49b5-b1ff-dcd901a03e02

> [!NOTE]
> Uses opencode's currently undocumented, likely unstable [API](https://github.com/sst/opencode/blob/dev/packages/opencode/src/server/server.ts).
>
> Latest tested opencode version: `v0.4.45`

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
  dependencies = {
    -- Technically optional, but provides a better input and embedded terminal experience.
    -- To bypass: use your own `toggle` (if any), and override `opts.on_send` and `opts.on_opencode_not_found`.
    { 'folke/snacks.nvim', opts = { input = { enabled = true } } },
  },
  ---@type opencode.Config
  opts = {
    -- Your configuration, if any
  },
  keys = {
    { '<leader>ot', function() require('opencode').toggle() end, desc = 'Toggle embedded opencode', },
    { '<leader>oa', function() require('opencode').ask('@cursor: ') end, desc = 'Ask opencode', mode = 'n', },
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

`opencode.nvim` prioritizes a rich and reliable OOTB experience, with a flexible [configuration](./lua/opencode/config.lua#L13) and [API](./lua/opencode.lua) for you to customize and compose according to your preferences.

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

Add keymaps for your favorite [built-in](./lua/opencode/config.lua#L27) or custom prompts:

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

## 🙏 Acknowledgments

- Inspired by (and partially based on) [nvim-aider](https://github.com/GeorgesAlkhouri/nvim-aider) and later [neopencode.nvim](https://github.com/loukotal/neopencode.nvim).
- `opencode.nvim` uses opencode's TUI for simplicity — see [sudo-tee/opencode.nvim](https://github.com/sudo-tee/opencode.nvim) for a Neovim frontend.
- [mcp-neovim-server](https://github.com/bigcodegen/mcp-neovim-server) may better suit you, but it lacks customization and tool calls are slow and unreliable.
