---@module 'snacks.picker'

local M = {}

---Computes context placeholder highlights for `line`.
---See `:help input()-highlight`.
---@param line string
---@return table[]
function M.highlight(line)
  local placeholders = vim.tbl_keys(require("opencode.config").opts.contexts)
  table.sort(placeholders, function(a, b)
    return #a > #b -- longest first
  end)
  local hls = {}

  local function overlaps(s1, e1, s2, e2)
    return not (e1 < s2 or s1 > e2)
  end

  for _, placeholder in ipairs(placeholders) do
    local init = 1
    while true do
      local start_pos, end_pos = line:find(placeholder, init, true)
      if not start_pos then
        break
      end
      local overlap = false
      for _, hl in ipairs(hls) do
        if overlaps(start_pos, end_pos, hl[1] + 1, hl[2]) then
          overlap = true
          break
        end
      end
      if not overlap then
        table.insert(hls, {
          start_pos - 1,
          end_pos,
          "@lsp.type.enum",
        })
      end
      init = end_pos + 1
    end
  end

  -- Must occur in-order or neovim will error
  table.sort(hls, function(a, b)
    return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
  end)

  return hls
end

return M
