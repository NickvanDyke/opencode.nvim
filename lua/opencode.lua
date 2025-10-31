---`opencode.nvim` public API.
local M = {}

M.ask = require("opencode.ui.ask").ask
M.select = require("opencode.ui.select").select

M.prompt = require("opencode.api.prompt").prompt
M.command = require("opencode.api.command").command

M.toggle = require("opencode.provider").toggle
M.start = require("opencode.provider").start
M.show = require("opencode.provider").show

return M
