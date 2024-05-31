---@class Utils
local M = {}

---Function to parse a package string
---@param package_string any
---@return unknown
---@return unknown
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

vim.cmd('highlight MajorTextHighlight guifg=#D2222D')
vim.cmd('highlight MinorTextHighlight guifg=#FFBF00')
vim.cmd('highlight MyVirtualTextHighlight guifg=#238823')

---Function to add virtual text to a buffer
---@param bufnr any
---@param line any
---@param text any
---@param ns_id any
---@param highlight any
M.add_virtual_text = function(bufnr, line, text, ns_id, highlight)
	vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, -1, {
		virt_text = { { text, highlight } },
		virt_text_pos = "eol", -- End of line
	})
end

---Function to split a semver string
---@param semver any
---@return number?
---@return number?
---@return number?
local function split_semver(semver)
	-- Pattern to match MAJOR.MINOR.PATCH
	local major, minor, patch = semver:match("^(%d+)%.(%d+)%.(%d+)$")
	major = tonumber(major)
	minor = tonumber(minor)
	patch = tonumber(patch)
	return major, minor, patch
end

---comment
---@param version_a any
---@param version_b any
---@return string
M.get_highlight_from_semver_cmp = function(version_a, version_b)
	local major_a, minor_a, patch_a = split_semver(version_a)
	local major_b, minor_b, patch_b = split_semver(version_b)

	if major_a ~= major_b then
		return "MajorTextHighlight"
	elseif minor_a ~= minor_b then
		return "MinorTextHighlight"
	elseif patch_a ~= patch_b then
		return "MyVirtualTextHighlight"
	else
		return "Comment"
	end
end

return M
