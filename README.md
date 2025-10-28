# opencode.nvim

Integrate the [opencode](https://github.com/sst/opencode) AI assistant with Neovim — streamline editor-aware research, reviews, and requests. 

https://github.com/user-attachments/assets/4dd19151-89e4-4272-abac-6710dbc6edc1

## ✨ Features

- Auto-connect to *any* `opencode` running inside Neovim's CWD, or toggle an embedded instance.
- Input prompts with completions, highlights, and normal-mode support.
- Select prompts from a library and define your own.
- Inject relevant editor context (buffer, cursor, selection, diagnostics, ...).
- Control `opencode` with commands.
- Respond to `opencode` permission requests.
- Auto-reload buffers edited by `opencode` in real-time.
- Forward `opencode`'s Server-Sent-Events as Neovim autocmds for automation.
- Sensible defaults with well-documented, flexible configuration and API to fit your workflow.

## 📦 Setup

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "NickvanDyke/opencode.nvim",
  dependencies = {
    -- Recommended for `ask()` and `select()`.
    -- Required for default `toggle()` implementation.
    { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
  },
  config = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
    }

    -- Required for `opts.auto_reload`.
    vim.o.autoread = true

    -- Recommended/example keymaps.
    vim.keymap.set({ "n", "x" }, "<C-a>", function() require("opencode").ask("@this: ", { submit = true }) end, { desc = "Ask opencode" })
    vim.keymap.set({ "n", "x" }, "<C-x>", function() require("opencode").select() end, { desc = "Execute opencode action…" })
    vim.keymap.set({ "n", "x" }, "ga",    function() require("opencode").prompt("@this") end, { desc = "Add to opencode" })
    vim.keymap.set("n", "<S-C-u>", function() require("opencode").command("messages_half_page_up") end, { desc = "opencode half page up" })
    vim.keymap.set("n", "<S-C-d>", function() require("opencode").command("messages_half_page_down") end, { desc = "opencode half page down" })
    -- You may want these if you stick with the opinionated "<C-a>" and "<C-x>" above — otherwise consider "<leader>o".
    vim.keymap.set('n', '+', '<C-a>', { desc = 'Increment', noremap = true })
    vim.keymap.set('n', '-', '<C-x>', { desc = 'Decrement', noremap = true })
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

> [!TIP]
> Run `:checkhealth opencode` after installation.

## ⚙️ Configuration

`opencode.nvim` provides a rich and reliable default experience — see all available options and their defaults [here](./lua/opencode/config.lua).

### Provider

`opencode.nvim` auto-connects to *any* `opencode` running inside Neovim's CWD — you can manually launch `opencode` however you like (terminal plugin, multiplexer, app, ...), but consider configuring `opencode.nvim` to manage it on your behalf:

```lua
vim.g.opencode_opts = {
  ---@type opencode.Provider
  provider = {
    toggle = function(self)
      -- Called by `require("opencode").toggle()`
    end,
    start = function(self)
      -- Called when sending a prompt or command to `opencode` but no process was found.
      -- `opencode.nvim` will poll for a couple seconds waiting for one to appear.
    end,
    show = function(self)
      -- Called when a prompt or command is sent to `opencode`,
      -- *and* this provider's `toggle` or `start` has previously been called
      -- (so as to not interfere when `opencode` was started externally).
    end
  }
}
```

By default, `opencode.nvim` will use [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md) (if available) when `opencode` isn't already running:

```lua
vim.g.opencode_opts = {
  provider = {
    enabled = "snacks",
    ---@type opencode.provider.Snacks
    snacks = {
      -- Customize `snacks.terminal` to your liking.
    }
  }
}
```

> [!TIP]
> I only use `snacks.terminal`, but welcome PRs adding your custom method as a built-in provider 🙂

## 🚀 Usage

### 🗣️ Prompt — `require("opencode").prompt()` | `:[range]OpencodePrompt`

Send a prompt.

Replaces placeholders with the corresponding context:

| Placeholder | Context |
| - | - |
| `@buffer` | Current buffer |
| `@buffers` | Open buffers |
| `@cursor` | Cursor position |
| `@selection` | Visual selection |
| `@this` | Visual selection if any, else cursor position |
| `@visible` | Visible text |
| `@diagnostics` | Current buffer diagnostics |
| `@quickfix` | Quickfix list |
| `@diff` | Git diff |
| `@grapple` | [grapple.nvim](https://github.com/cbochs/grapple.nvim) tags |

### ✍️ Ask — `require("opencode").ask()`

Input a prompt.

- Highlights placeholders.
- Completes placeholders.
  - Press `<Tab>` to trigger built-in completion.
  - When using `blink.cmp` and `snacks.input`, registers `opts.auto_register_cmp_sources`.
- Press `<Up>` to browse recent inputs.

### 🧑‍🏫 Command — `require("opencode").command()`

Send a [command](https://opencode.ai/docs/keybinds) to control `opencode`:

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
| `messages_copy`           | Copy the last message in the session                     |
| `messages_undo`           | Undo the last message in the session                     |
| `messages_redo`           | Redo the last message in the session                     |
| `input_clear`             | Clear the TUI input                                      |
| `agent_cycle`             | Cycle the selected agent                                 |

> Supports *all* commands — these are just the most useful ones.

### 💻 Toggle — `require("opencode").toggle()`

Toggle `opencode` via `opts.provider.toggle`. Usually not explicitly needed — `opencode.nvim` automatically starts and shows `opencode` via `opts.provider.start` and `opts.provider.show` when you send a prompt or command.

### 📝 Select — `require("opencode").select()`

A single entrypoint to all `opencode.nvim` functionality 😄

#### Prompt

Select from `opts.prompts` to review, explain, and improve your code:

| Name                               | Prompt                                                    |
|------------------------------------|-----------------------------------------------------------|
| `ask`         | *...*                                                             |
| `explain`     | Explain `@this` and its context                                   |
| `optimize`    | Optimize `@this` for performance and readability                  |
| `document`    | Add comments documenting `@this`                                  |
| `test`        | Add tests for `@this`                                             |
| `review`      | Review `@this` for correctness and readability                    |
| `diagnostics` | Explain `@diagnostics`                                            |
| `fix`         | Fix `@diagnostics`                                                |
| `diff`        | Review the following git diff for correctness and readability: `@diff`         |
| `buffer`  | `@buffer`                                                             |
| `this`    | `@this`                                                               |

#### Command

Select from `opts.commands` to control `opencode`:

| Command                   | Description                                              |
|---------------------------|----------------------------------------------------------|
| `session_new`             | Start a new session                                      |
| `session_share`           | Share the current session                                |
| `session_interrupt`       | Interrupt the current session                            |
| `session_compact`         | Compact the current session (reduce context size)        |
| `messages_copy`           | Copy the last message in the session                     |
| `messages_undo`           | Undo the last message in the session                     |
| `messages_redo`           | Redo the last message in the session                     |
| `agent_cycle`             | Cycle the selected agent                                 |

#### Provider

Manage `opts.provider`:

| Name | Function |
|------|----------|
| `toggle` | Toggle `opencode` |
| `start` | Start `opencode` |
| `show` | Show `opencode` |

## 👀 Events

`opencode.nvim` forwards `opencode`'s Server-Sent-Events as an `OpencodeEvent` autocmd:

```lua
-- Listen for `opencode` events
vim.api.nvim_create_autocmd("User", {
  pattern = "OpencodeEvent",
  callback = function(args)
    -- See the available event types and their properties
    vim.notify(vim.inspect(args.data.event))
    -- Do something useful
    if args.data.event.type == "session.idle" then
      vim.notify("`opencode` finished responding")
    end
  end,
})
```

## 🙏 Acknowledgments

- Inspired by [nvim-aider](https://github.com/GeorgesAlkhouri/nvim-aider), [neopencode.nvim](https://github.com/loukotal/neopencode.nvim), and [sidekick.nvim](https://github.com/folke/sidekick.nvim).
- Uses `opencode`'s TUI for simplicity — see [sudo-tee/opencode.nvim](https://github.com/sudo-tee/opencode.nvim) for a Neovim frontend.
- [mcp-neovim-server](https://github.com/bigcodegen/mcp-neovim-server) may better suit you, but it lacks customization and tool calls are slow and unreliable.
