# opencode.nvim

Integrate the [opencode](https://github.com/sst/opencode) AI assistant with Neovim — streamline editor-aware research, reviews, and requests. 

https://github.com/user-attachments/assets/01e4e2fc-bbfa-427e-b9dc-c1c1badaa90e

## ✨ Features

- Auto-connects to *any* `opencode` running inside Neovim's CWD, or provides an integrated instance.
- Input prompts with completions, highlights, and normal-mode support.
- Select prompts from a library and define your own.
- Inject relevant editor context (buffer, cursor, selection, diagnostics, etc.).
- Control `opencode` with commands.
- Respond to `opencode` permission requests.
- Monitor state via statusline component.
- Auto-reloads buffers edited by `opencode` in real-time.
- Forwards `opencode`'s Server-Sent-Events as autocmds for automation.
- Sensible defaults with well-documented, flexible configuration and API to fit your workflow.

## 📦 Setup

> [!TIP]
> Run `:checkhealth opencode` after setup.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "NickvanDyke/opencode.nvim",
  dependencies = {
    -- Recommended for `ask()` and `select()`.
    -- Required for `snacks` provider.
    ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
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
    vim.keymap.set({ "n", "x" }, "<C-x>", function() require("opencode").select() end,                          { desc = "Execute opencode action…" })
    vim.keymap.set({ "n", "x" },    "ga", function() require("opencode").prompt("@this") end,                   { desc = "Add to opencode" })
    vim.keymap.set({ "n", "t" }, "<C-.>", function() require("opencode").toggle() end,                          { desc = "Toggle opencode" })
    vim.keymap.set("n",        "<S-C-u>", function() require("opencode").command("session.half.page.up") end,   { desc = "opencode half page up" })
    vim.keymap.set("n",        "<S-C-d>", function() require("opencode").command("session.half.page.down") end, { desc = "opencode half page down" })
    -- You may want these if you stick with the opinionated "<C-a>" and "<C-x>" above — otherwise consider "<leader>o".
    vim.keymap.set('n', '+', '<C-a>', { desc = 'Increment', noremap = true })
    vim.keymap.set('n', '-', '<C-x>', { desc = 'Decrement', noremap = true })
  end,
}
```

### [nixvim](https://github.com/nix-community/nixvim)

```nix
programs.nixvim = {
  extraPlugins = [
    pkgs.vimPlugins.opencode-nvim
  ];
};
```

## ⚙️ Configuration

`opencode.nvim` provides a rich and reliable default experience — see all available options and their defaults [here](./lua/opencode/config.lua).

### Provider

You can manually run `opencode` inside Neovim's CWD however you like and `opencode.nvim` will find it!

If `opencode.nvim` can't find an existing `opencode`, it uses the configured provider (defaulting based on availability) to `toggle`, `start`, and `show` one when appropriate.

#### [snacks.terminal](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md)

```lua
vim.g.opencode_opts = {
  provider = {
    enabled = "snacks", -- Default when `snacks.terminal` is enabled.
    snacks = {
      -- Customize `snacks.terminal` to your liking.
    }
  }
}
```

#### [tmux](https://github.com/tmux/tmux)

```lua
vim.g.opencode_opts = {
  provider = {
    enabled = "tmux", -- Default when running inside a `tmux` session.
    tmux = {
      options = "-h", -- options to pass to `tmux split-window`
    }
  }
}
```

#### Custom

Integrate your custom method for convenience!

```lua
vim.g.opencode_opts = {
  provider = {
    toggle = function(self)
      -- ...
    end,
    start = function(self)
      -- ...
    end,
    show = function(self)
      -- ...
    end
  }
}
```

Please submit PRs adding new providers! 🙂

## 🚀 Usage

### ✍️ Ask — `require("opencode").ask()`

Input a prompt to send to `opencode`.
- Press `<Up>` to browse recent asks.
- Highlights contexts and `opencode` subagents.
- Completes contexts and `opencode` subagents.
  - Press `<Tab>` to trigger built-in completion.
  - When using `blink.cmp` and `snacks.input`, registers `opts.ask.blink_cmp_sources`.

<img width="800" alt="image" src="https://github.com/user-attachments/assets/8591c610-4824-4480-9e6d-0c94e9c18f3a" />

### 📝 Select — `require("opencode").select()`

Select from all `opencode.nvim` functionality.
- Fetches custom commands from `opencode`.

<img width="800" alt="image" src="https://github.com/user-attachments/assets/afd85acd-e4b3-47d2-b92f-f58d25972edb" />

### 🗣️ Prompt — `require("opencode").prompt()` | `:[range]OpencodePrompt`

Send a prompt to `opencode`.

#### Contexts

Replaces placeholders in the prompt with the corresponding context:

| Placeholder | Context |
| - | - |
| `@this` | Visual selection if any, else cursor position |
| `@buffer` | Current buffer |
| `@buffers` | Open buffers |
| `@visible` | Visible text |
| `@diagnostics` | Current buffer diagnostics |
| `@quickfix` | Quickfix list |
| `@diff` | Git diff |
| `@grapple` | [grapple.nvim](https://github.com/cbochs/grapple.nvim) tags |

#### Prompts

Reference a prompt by name to review, explain, and improve your code:

| Name                               | Prompt                                                    |
|------------------------------------|-----------------------------------------------------------|
| `explain`     | Explain `@this` and its context                                   |
| `optimize`    | Optimize `@this` for performance and readability                  |
| `document`    | Add comments documenting `@this`                                  |
| `test`        | Add tests for `@this`                                             |
| `review`      | Review `@this` for correctness and readability                    |
| `diagnostics` | Explain `@diagnostics`                                            |
| `fix`         | Fix `@diagnostics`                                                |
| `diff`        | Review the following git diff for correctness and readability: `@diff`         |

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

<img width="800" alt="image" src="https://github.com/user-attachments/assets/643681ca-75db-4621-8a4a-e744c03c4b4f" />

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
