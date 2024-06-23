local utils = require("depsync.util")

---@class MainModule
local M = {}

---Sync packages in package.json file
---@return string
M.sync = function()
	local buf = vim.api.nvim_get_current_buf()
	local buf_name = vim.api.nvim_buf_get_name(buf)

	if not utils.is_package_file(buf_name) then
		return buf_name .. " Not supported"
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	utils.sync_packages(buf, lines)

	return "Syncing packages!"
end

---comment
M.update = function(args_str)
	local buf = vim.api.nvim_get_current_buf()
	local buf_name = vim.api.nvim_buf_get_name(buf)

	if not utils.is_package_file(buf_name) then
		return buf_name .. " Not supported"
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	utils.update_packages(buf, lines, args_str)

	return "Updating packages!"
end

return M
