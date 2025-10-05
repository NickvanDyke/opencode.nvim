# opencode.nvim

Integrate the [opencode](https://github.com/sst/opencode) AI assistant with Neovim — streamline editor-aware research, reviews, and requests. 

https://github.com/user-attachments/assets/340ce139-173c-4e81-b39a-f089862db9ce

> Uses `opencode`'s currently undocumented [API](https://github.com/sst/opencode/blob/dev/packages/opencode/src/server/server.ts) — latest tested version: `v0.14.1`

## ✨ Features

- Auto-connect to *any* `opencode` inside Neovim's CWD, or toggle an embedded instance.
- Input prompts with completions, highlights, and normal-mode support.
- Select from a prompt library and define custom prompts.
- Inject relevant editor context (buffer, selection, cursor, diagnostics, etc.).
- Auto-reload buffers edited by `opencode` in real-time.
- Forward `opencode`'s Server-Sent-Events as Neovim autocmds for automation.
- Sensible defaults with well-documented, flexible configuration and API to fit your workflow.

## 📦 Setup

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "NickvanDyke/opencode.nvim",
  dependencies = {
    -- Recommended for `ask()`, and required for `toggle()` — otherwise optional
    { "folke/snacks.nvim", opts = { input = { enabled = true } } },
  },
  config = function()
    vim.g.opencode_opts = {
      -- Your configuration, if any — see `lua/opencode/config.lua`
    }

    -- Required for `vim.g.opencode_opts.auto_reload`
    vim.opt.autoread = true

    -- Recommended/example keymaps
    vim.keymap.set("n", "<leader>ot", function() require("opencode").toggle() end, { desc = "Toggle embedded" })
    vim.keymap.set("n", "<leader>oa", function() require("opencode").ask("@cursor: ") end, { desc = "Ask about this" })
    vim.keymap.set("v", "<leader>oa", function() require("opencode").ask("@selection: ") end, { desc = "Ask about selection" })
    vim.keymap.set("n", "<leader>o+", function() require("opencode").prompt("@buffer", { append = true }) end, { desc = "Add buffer to prompt" })
    vim.keymap.set("v", "<leader>o+", function() require("opencode").prompt("@selection", { append = true }) end, { desc = "Add selection to prompt" })
    vim.keymap.set("n", "<leader>oe", function() require("opencode").prompt("Explain @cursor and its context") end, { desc = "Explain this code" })
    vim.keymap.set("n", "<leader>on", function() require("opencode").command("session_new") end, { desc = "New session" })
    vim.keymap.set("n", "<S-C-u>",    function() require("opencode").command("messages_half_page_up") end, { desc = "Messages half page up" })
    vim.keymap.set("n", "<S-C-d>",    function() require("opencode").command("messages_half_page_down") end, { desc = "Messages half page down" })
    vim.keymap.set({ "n", "v" }, "<leader>os", function() require("opencode").select() end, { desc = "Select prompt" })
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
};
```
</details>

## ⚙️ Configuration

`opencode.nvim` provides a rich and reliable default experience — see all available options and their defaults [here](./lua/opencode/config.lua#L47).

## 🚀 Usage

### 🙋 Prompt — `require("opencode").prompt()`

Send a prompt. The main entrypoint — build on it!

### ✍️ Ask — `require("opencode").ask()`

Input a prompt.

- Highlights [contexts](lua/opencode/config.lua#L51).
- Completes [contexts](lua/opencode/config.lua#L51) when using [`snacks.input`](https://github.com/folke/snacks.nvim/blob/main/docs/input.md).
  - Press `<Tab>` or `<C-x><C-o>` to trigger built-in completion.
  - Registers `vim.g.opencode_opts.auto_register_cmp_sources` with [`blink.cmp`](https://github.com/Saghen/blink.cmp).

### 📝 Select — `require("opencode").select()`

Select from [prompts](lua/opencode/config.lua#65) to review, explain, and improve your code:

| Description                        | Prompt                                                    |
|------------------------------------|-----------------------------------------------------------|
| Ask…                               | *(user input required)*                                   |
| Explain code near cursor           | Explain @cursor and its context                           |
| Explain diagnostics              | Explain @diagnostics                                        |
| Optimize selection                | Optimize @selection for performance and readability        |
| Document selection                | Add documentation comments for @selection                  |
| Add tests for selection            | Add tests for @selection                                  |
| Review buffer                      | Review @buffer for correctness and readability            |
| Review git diff                    | Review the following git diff for correctness and readability:\n@diff |
| Add buffer to prompt               | @buffer                                                   |
| Add selection to prompt            | @selection                                                |

### 🧑‍🏫 Command — `require("opencode").command()`

Send a [command](https://opencode.ai/docs/keybinds):

| Command                   | Description                                              |
|---------------------------|----------------------------------------------------------|
| `session_new`             | Start a new session                                      |
| `session_share`           | Share the current session                                |
| `session_interrupt`       | Interrupt the current session                            |
| `session_compact`         | Compact the current session (reduce context size)        |
| `messages_page_up`        | Scroll messages up by one page                           |
| `messages_page_down`      | Scroll messages down by one page                         |
| `messages_half_page_up`   | Scroll messages up by half a page                        |
| `messages_half_page_down` | Scroll messages down by half a page                      |
| `messages_first`          | Jump to the first message in the session                 |
| `messages_last`           | Jump to the last message in the session                  |

### 💻 Toggle — `require("opencode").toggle()`

Toggle an embedded `opencode` terminal (requires [`snacks.nvim`](https://github.com/folke/snacks.nvim)).

`opencode.nvim` connects to *any* `opencode` inside Neovim's CWD, but provides this for convenience.

To use your own method (terminal app or plugin, multiplexer, etc.), launch `opencode` with it and optionally override `vim.g.opencode_opts.on_opencode_not_found` and `vim.g.opencode_opts.on_submit` for convenience, then use `opencode.nvim` normally.

## 🕵️ Contexts

`opencode.nvim` replaces placeholders in prompts with their corresponding [contexts](lua/opencode/config.lua#L51):

| Placeholder | Context |
| - | - |
| `@buffer` | Current buffer |
| `@buffers` | Open buffers |
| `@cursor` | Cursor position |
| `@selection` | Selected text |
| `@visible` | Visible text |
| `@diagnostics` | Current buffer diagnostics |
| `@quickfix` | Quickfix list |
| `@diff` | Git diff |
| `@grapple` | [grapple.nvim](https://github.com/cbochs/grapple.nvim) tags |

## 👀 Events

`opencode.nvim` forwards `opencode`'s Server-Sent-Events as an `OpencodeEvent` autocmd:

```lua
-- Listen for `opencode` events
vim.api.nvim_create_autocmd("User", {
  pattern = "OpencodeEvent",
  callback = function(args)
    -- See the available event types and their properties
    vim.notify(vim.inspect(args.data))
    -- Do something interesting, like show a notification when `opencode` finishes responding
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
