---@class Utils
local M = {}

---@param package_string string
---@return string, string
M.parse_package_string = function(package_string)
	-- Pattern to match the package name and semver version
	local pattern = '"([^"]+)":%s*"([^"]+)"'
	local package_name, semver_version = package_string:match(pattern)

	-- Remove the ^ character from the semver version if it exists
	if semver_version then
		semver_version = semver_version:gsub("^%s*^", "")
	end

	return package_name, semver_version
end

---@param package_name string
---@return string
M.fetch_version = function(package_name)
	local command = "npm view " .. package_name .. " version"

	-- Execute the command
	local handle = io.popen(command)
	if not handle then
		error("Failed to execute command: " .. command)
	end

	local version = handle:read("*a")
	handle:close()

	return version
end

M.add_virtual_text = function(bufnr, line, text, ns_id)
	-- Set up the virtual text

	-- Add virtual text
	vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, -1, {
		virt_text = { { text, "Comment" } },
		virt_text_pos = "eol", -- End of line
	})
end

return M

