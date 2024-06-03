local utils = require("depsync.util")
local Job = require("plenary.job")

---@class MainModule
local M = {}

---Sync packages in package.json file
---@return string
M.sync = function()
	local buf = vim.api.nvim_get_current_buf()
	local buf_name = vim.api.nvim_buf_get_name(buf)

	if not string.find(buf_name, "package.json") then
		return "Not a package.json file"
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	utils.sync_packages(buf, lines)

	return "Synced packages!"
end

---comment
M.update = function()
end

return M
