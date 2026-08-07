local M = {}

local utf8_char_pattern = "[%z\1-\127\194-\244][\128-\191]*"

function M.utf8_len(str)
  local len = 0
  for _ in str:gmatch(utf8_char_pattern) do
    len = len + 1
  end
  return len
end

function M.utf8_sub(str, start_char, end_char)
  local result = {}
  local char_index = 0

  for char in str:gmatch(utf8_char_pattern) do
    char_index = char_index + 1
    if char_index >= start_char and (not end_char or char_index <= end_char) then
      table.insert(result, char)
    end
  end

  return table.concat(result)
end

function M.sha1(str)
  local h0, h1, h2, h3, h4 = 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0

  local msg = str .. "\128"
  local len = #str * 8

  local zero_bytes = (56 - (#msg % 64)) % 64
  msg = msg .. string.rep("\0", zero_bytes)

  msg = msg .. string.pack(">I8", len)

  local chunk_size = 64
  for i = 1, #msg, chunk_size do
    local chunk = string.sub(msg, i, i + chunk_size - 1)
    local words = {}

    for j = 1, 16 do
      words[j] = string.unpack(">I4", chunk, (j - 1) * 4 + 1)
    end

    for j = 17, 80 do
      local w = words[j - 3] ~ words[j - 8] ~ words[j - 14] ~ words[j - 16]
      words[j] = (w << 1 | w >> 31) & 0xFFFFFFFF
    end

    local a, b, c, d, e = h0, h1, h2, h3, h4

    for j = 1, 80 do
      local f, k
      if j <= 20 then
        f = (b & c) | ((~b) & d)
        k = 0x5A827999
      elseif j <= 40 then
        f = b ~ c ~ d
        k = 0x6ED9EBA1
      elseif j <= 60 then
        f = (b & c) | (b & d) | (c & d)
        k = 0x8F1BBCDC
      else
        f = b ~ c ~ d
        k = 0xCA62C1D6
      end

      local temp = ((a << 5 | a >> 27) + f + e + k + words[j]) & 0xFFFFFFFF
      e = d
      d = c
      c = (b << 30 | b >> 2) & 0xFFFFFFFF
      b = a
      a = temp
    end

    h0 = (h0 + a) & 0xFFFFFFFF
    h1 = (h1 + b) & 0xFFFFFFFF
    h2 = (h2 + c) & 0xFFFFFFFF
    h3 = (h3 + d) & 0xFFFFFFFF
    h4 = (h4 + e) & 0xFFFFFFFF
  end

  return string.pack(">I4I4I4I4I4", h0, h1, h2, h3, h4)
end

function M.base64_encode(str)
  local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local result = {}
  local padding = ""

  for i = 1, #str, 3 do
    local b1 = string.byte(str, i)
    local b2 = string.byte(str, i + 1) or 0
    local b3 = string.byte(str, i + 2) or 0

    local n = b1 * 65536 + b2 * 256 + b3

    local c1 = math.floor(n / 262144) % 64
    local c2 = math.floor(n / 4096) % 64
    local c3 = math.floor(n / 64) % 64
    local c4 = n % 64

    table.insert(result, string.sub(b64chars, c1 + 1, c1 + 1))
    table.insert(result, string.sub(b64chars, c2 + 1, c2 + 1))

    if i + 1 <= #str then
      table.insert(result, string.sub(b64chars, c3 + 1, c3 + 1))
    else
      table.insert(result, "=")
    end

    if i + 2 <= #str then
      table.insert(result, string.sub(b64chars, c4 + 1, c4 + 1))
    else
      table.insert(result, "=")
    end
  end

  return table.concat(result)
end

function M.parse_http_headers(request)
  local headers = {}
  local lines = vim.split(request, "\r\n")

  for i, line in ipairs(lines) do
    if i > 1 and line ~= "" then
      local key, value = line:match("^([^:]+):%s*(.+)$")
      if key and value then
        headers[key:lower()] = value
      end
    end
  end

  return headers
end

function M.constant_time_compare(a, b)
  if type(a) ~= "string" or type(b) ~= "string" then
    return false
  end

  if #a ~= #b then
    return false
  end

  local result = 0
  for i = 1, #a do
    result = result | (string.byte(a, i) ~ string.byte(b, i))
  end

  return result == 0
end

return M
