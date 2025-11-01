# opencode.nvim

Integrate the [opencode](https://github.com/sst/opencode) AI assistant with Neovim — streamline editor-aware research, reviews, and requests. 

https://github.com/user-attachments/assets/4dd19151-89e4-4272-abac-6710dbc6edc1

## ✨ Features

- Auto-connect to *any* `opencode` running inside Neovim's CWD, or toggle an embedded instance.
- Input prompts with completions, highlights, and normal-mode support.
- Select prompts from a library and define your own.
- Inject relevant editor context (buffer, cursor, selection, diagnostics, ...).
- Control `opencode` with commands.
- Auto-reload buffers edited by `opencode` in real-time.
- Respond to `opencode` permission requests.
- Statusline component.
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
    vim.keymap.set({ "n", "t" }, "<C-.>",   function() require("opencode").toggle() end, { desc = "Toggle opencode" })
    vim.keymap.set("n", "<S-C-u>", function() require("opencode").command("session.half.page.up") end, { desc = "opencode half page up" })
    vim.keymap.set("n", "<S-C-d>", function() require("opencode").command("session.half.page.down") end, { desc = "opencode half page down" })
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
      -- Called by `require("opencode").toggle()`.
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

Send a prompt to `opencode`.

#### Contexts

Replaces placeholders in the prompt with the corresponding context:

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

#### Prompts

Reference a prompt by name to review, explain, and improve your code:

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

### ✍️ Ask — `require("opencode").ask()`

Input a prompt to send to `opencode`.

- Highlights placeholders.
- Completes placeholders.
  - Press `<Tab>` to trigger built-in completion.
  - When using `blink.cmp` and `snacks.input`, registers `opts.auto_register_cmp_sources`.
- Press `<Up>` to browse recent inputs.

### 🧑‍🏫 Command — `require("opencode").command()`

Send a command to `opencode`:

| Command                 | Description                                              |
|-------------------------|----------------------------------------------------------|
| `session.list`          | List sessions                                            |
| `session.new`             | Start a new session                                      |
| `session.share`           | Share the current session                                |
| `session.interrupt`       | Interrupt the current session                            |
| `session.compact`         | Compact the current session (reduce context size)        |
| `session.page.up`        | Scroll messages up by one page                           |
| `session.page.down`      | Scroll messages down by one page                         |
| `session.half.page.up`   | Scroll messages up by half a page                        |
| `session.half.page.down` | Scroll messages down by half a page                      |
| `session.first`          | Jump to the first message in the session                 |
| `session.last`           | Jump to the last message in the session                  |
| `session.undo` | Undo the last action in the current session |
| `session.redo` | Redo the last undone action in the current session |
| `prompt.submit`             | Submit the TUI input                                      |
| `prompt.clear`             | Clear the TUI input                                      |
| `agent.cycle`             | Cycle the selected agent                                 |

### 📝 Select — `require("opencode").select()`

A single entrypoint to all `opencode.nvim` functionality 😄

- Prompt library (`opts.prompts`)
- Command library (`opts.commands`)
- Manage provider (`opts.provider`)

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

### Edits

When `opencode` edits a file, `opencode.nvim` automatically reloads the corresponding buffer.

### Permissions

When `opencode` requests a permission, `opencode.nvim` waits for idle to ask you to approve or deny it.

### Statusline

[lualine](https://github.com/nvim-lualine/lualine.nvim):

```lua
require("lualine").setup({
  sections = {
    lualine_z = {
      {
        require("opencode").statusline,
      },
    }
  }
})

```

## 🙏 Acknowledgments

- Inspired by [nvim-aider](https://github.com/GeorgesAlkhouri/nvim-aider), [neopencode.nvim](https://github.com/loukotal/neopencode.nvim), and [sidekick.nvim](https://github.com/folke/sidekick.nvim).
- Uses `opencode`'s TUI for simplicity — see [sudo-tee/opencode.nvim](https://github.com/sudo-tee/opencode.nvim) for a Neovim frontend.
- [mcp-neovim-server](https://github.com/bigcodegen/mcp-neovim-server) may better suit you, but it lacks customization and tool calls are slow and unreliable.
