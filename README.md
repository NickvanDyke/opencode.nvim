# opencode.nvim

Integrate the [opencode](https://github.com/sst/opencode) AI assistant with Neovim — streamline editor-aware research, reviews, and requests. 

https://github.com/user-attachments/assets/4dd19151-89e4-4272-abac-6710dbc6edc1

## ✨ Features

- Auto-connect to *any* `opencode` inside Neovim's CWD, or toggle an embedded instance.
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

    -- Required for `vim.g.opencode_opts.auto_reload`.
    vim.o.autoread = true

    -- Recommended/example keymaps.
    vim.keymap.set({ "n", "x" }, "<leader>oa", function() require("opencode").ask("@this: ", { submit = true }) end, { desc = "Ask about this" })
    vim.keymap.set({ "n", "x" }, "<leader>os", function() require("opencode").select() end, { desc = "Select prompt" })
    vim.keymap.set({ "n", "x" }, "<leader>o+", function() require("opencode").prompt("@this") end, { desc = "Add this" })
    vim.keymap.set("n", "<leader>ot", function() require("opencode").toggle() end, { desc = "Toggle embedded" })
    vim.keymap.set("n", "<leader>oc", function() require("opencode").command() end, { desc = "Select command" })
    vim.keymap.set("n", "<leader>on", function() require("opencode").command("session_new") end, { desc = "New session" })
    vim.keymap.set("n", "<leader>oi", function() require("opencode").command("session_interrupt") end, { desc = "Interrupt session" })
    vim.keymap.set("n", "<leader>oA", function() require("opencode").command("agent_cycle") end, { desc = "Cycle selected agent" })
    vim.keymap.set("n", "<S-C-u>",    function() require("opencode").command("messages_half_page_up") end, { desc = "Messages half page up" })
    vim.keymap.set("n", "<S-C-d>",    function() require("opencode").command("messages_half_page_down") end, { desc = "Messages half page down" })
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


By default, `opencode.nvim` will use [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md) (if available) to launch and manage an embedded `opencode` when one isn't already running:

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

Replaces placeholders with the corresponding [contexts](lua/opencode/config.lua#L53):

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

### 📝 Select — `require("opencode").select()`

Select from [prompts](lua/opencode/config.lua#68) to review, explain, and improve your code:

| Description                        | Prompt                                                    |
|------------------------------------|-----------------------------------------------------------|
| `ask`         | *(user input required)*                                           |
| `explain`     | Explain `@this` and its context                                   |
| `optimize`    | Optimize `@this` for performance and readability                  |
| `document`    | Add comments documenting `@this`                                  |
| `test`        | Add tests for `@this`                                             |
| `review`      | Review `@this` for correctness and readability                    |
| `diagnostics` | Explain `@diagnostics`                                            |
| `fix`         | Fix `@diagnostics`                                                |
| `diff`        | Review the following git diff for correctness and readability: `@diff`         |
| `buffer`  | `@buffer`                                                         |
| `this`    | `@this`                                                           |

> [!TIP]
> Create keymaps for your favorite prompts:
> ```lua
> vim.keymap.set({ "n", "x" }, "<leader>oe", function()
>   local explain = require("opencode.config").opts.prompts.explain
>   require("opencode").prompt(explain.prompt, explain)
> end, { desc = "Explain this" })
> ```

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
| `messages_copy`           | Copy the last message in the session                     |
| `messages_undo`           | Undo the last message in the session                     |
| `messages_redo`           | Redo the last message in the session                     |
| `input_clear`             | Clear the TUI input                                      |
| `agent_cycle`             | Cycle the selected agent                                 |

> Supports *all* commands — these are just the most useful ones.

### 💻 Toggle — `require("opencode").toggle()`

Toggle `opencode` via `vim.g.opencode_opts.provider`.

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
