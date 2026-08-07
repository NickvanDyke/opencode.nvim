# OpenCode.nvim Live Context Implementation

## Overview

This implementation adds real-time WebSocket-based live context broadcasting to opencode.nvim, enabling OpenCode TUI to track the current file/selection in Neovim.

## Architecture

### Components

1. **WebSocket Server** (`lua/opencode/editor/`)
   - `init.lua` - Main server module with start/stop/broadcast functions
   - `tcp.lua` - TCP server using `vim.uv`
   - `frame.lua` - WebSocket frame encoder/decoder (RFC 6455)
   - `handshake.lua` - WebSocket upgrade handshake with auth
   - `client.lua` - Client connection management
   - `utils.lua` - Pure Lua utilities (SHA-1, base64, UTF-8)

2. **Selection Tracking** (`lua/opencode/editor/selection.lua`)
   - Autocommands for CursorMoved, ModeChanged, BufEnter, TextChanged
   - Debounced updates (100ms)
   - Visual selection and cursor position capture

3. **Lockfile Manager** (`lua/opencode/editor/lockfile.lua`)
   - Creates `~/.claude/ide/[port].lock`
   - Compatible with Claude Code lockfile format
   - Atomic file creation
   - Auto-cleanup of stale lockfiles

### Protocol

**JSON-RPC 2.0 Messages:**

```json
// Selection Changed (Neovim -> OpenCode)
{
  "jsonrpc": "2.0",
  "method": "selection_changed",
  "params": {
    "text": "selected text",
    "filePath": "/path/to/file",
    "fileUrl": "file:///path/to/file",
    "selection": {
      "start": { "line": 10, "character": 5 },
      "end": { "line": 15, "character": 20 },
      "isEmpty": false
    }
  }
}

// At-Mentioned (Neovim -> OpenCode)
{
  "jsonrpc": "2.0",
  "method": "at_mentioned",
  "params": {
    "filePath": "/path/to/file",
    "lineStart": 10,
    "lineEnd": 20
  }
}
```

## Usage

### Configuration

```lua
vim.g.opencode_opts = {
  live_context = {
    enabled = true,  -- Auto-start on VimEnter
    port = 0,        -- 0 for random port
    auth_token = nil -- Optional: set to string or true to generate
  }
}
```

### Commands

- `:OpenCodeLiveContextStart` - Start WebSocket server
- `:OpenCodeLiveContextStop` - Stop WebSocket server
- `:'<,'>OpenCodeAttach` - Attach visual selection (no submit)

### API

```lua
local opencode = require("opencode")

-- Start live context
opencode.start_live_context({ port = 0, auth_token = nil })

-- Stop live context
opencode.stop_live_context()

-- Attach current selection without submitting
opencode.attach_context()
```

### Keymaps (Recommended)

```lua
vim.keymap.set("n", "<leader>ol", function()
  require("opencode").start_live_context()
end, { desc = "Start OpenCode live context" })

vim.keymap.set("x", "<leader>oa", function()
  require("opencode").attach_context()
end, { desc = "Attach selection to OpenCode" })
```

## OpenCode TUI Integration

OpenCode TUI automatically discovers the WebSocket server via:

1. **Lockfile** at `~/.claude/ide/[port].lock`
   ```json
   {
     "pid": 12345,
     "workspaceFolders": ["/path/to/project"],
     "ideName": "Neovim",
     "transport": "ws",
     "authToken": "optional-token"
   }
   ```

2. **Environment Variable**: `OPENCODE_EDITOR_SSE_PORT` or `CLAUDE_CODE_SSE_PORT`

## Implementation Notes

### No External Dependencies

All WebSocket code is pure Lua using Neovim's `vim.uv` (libuv) - no external Lua packages required.

### Compatibility

- Compatible with Claude Code's WebSocket protocol
- Uses same lockfile location and format
- Can share environment variables for discovery

### Performance

- Debounced updates (100ms) prevent excessive broadcasts
- Lightweight frame encoding without heavy abstraction
- Connection cleanup on Neovim exit

### Future Enhancements

1. **MCP Tools**: Expose tools that OpenCode can invoke
   - `openFile` - Open file in Neovim
   - `getCurrentSelection` - Get current selection
   - `openDiff` - Show diff view

2. **Bidirectional Communication**
   - Handle tool calls from OpenCode
   - Progress notifications for long operations

3. **Multi-client Support**
   - Connect multiple OpenCode TUI instances
   - Per-client selection state

## Files Created

```
lua/opencode/editor/
├── init.lua          # WebSocket server
├── tcp.lua           # TCP server
├── frame.lua         # WebSocket frames
├── handshake.lua     # WebSocket handshake
├── client.lua        # Client management
├── utils.lua         # Utilities
├── selection.lua     # Selection tracking
└── lockfile.lua      # Lockfile manager

plugin/
└── live-context.lua  # User commands
```

## Testing

```bash
# Start OpenCode TUI
opencode

# In Neovim (another terminal)
nvim
:OpenCodeLiveContextStart

# OpenCode TUI should show "Connected to editor: Neovim"
# Move cursor in Neovim - TUI shows current file/line
```
