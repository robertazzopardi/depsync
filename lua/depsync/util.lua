local Job = require("plenary.job")

---@class Utils
local M = {}

---Function to parse a package string
---@param package_string any
---@return unknown
---@return unknown
local function parse_package_string(package_string)
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
local function add_virtual_text(bufnr, line, text, ns_id, highlight)
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
local function get_highlight_from_semver_cmp(version_a, version_b)
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

-- Array of all package.json dependency fields
local dep_fields = {
	"dependencies",
	"devDependencies",
	"peerDependencies",
	"optionalDependencies",
}

---Check if the line is a dependency field
---@param line any
---@return boolean
local function in_dep_fields(line)
	for _, field in ipairs(dep_fields) do
		if string.match(line, '"' .. field .. '":') then
			return true
		end
	end

	return false
end

---Modified handle_package function to return results
---@param buf any
---@param i any
---@param ns_id any
---@param line any
local function handle_package(buf, i, ns_id, line)
	local package_name, current_version = parse_package_string(line)

	Job:new({
		command = 'npm',
		args = { 'view', package_name, 'version' },
		on_exit = vim.schedule_wrap(function(j, return_val)
			local latest_version = j:result()[1]

			if not string.match(latest_version, current_version) then
				local highlight = get_highlight_from_semver_cmp(current_version,
					latest_version)
				add_virtual_text(buf, i - 1, "Outdated: " .. latest_version, ns_id,
					highlight)
			end
		end),
	}):start()
end

local function handle_package_update(buf, i, line)
	local package_name, current_version = parse_package_string(line)

	Job:new({
		command = 'npm',
		args = { 'view', package_name, 'version' },
		on_exit = vim.schedule_wrap(function(j, return_val)
			local latest_version = j:result()[1]

			if not string.match(latest_version, current_version) then
				local new_line = string.gsub(line, current_version, latest_version)

				vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { new_line })
			end
		end),
	}):start()
end

---Modified sync_packages function to run handle_package in parallel
---@param buf any
---@param lines any
M.sync_packages = function(buf, lines)
	local ns_id = vim.api.nvim_create_namespace("depsync")
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	local in_deps = false
	for i, line in ipairs(lines) do
		if in_dep_fields(line) then
			in_deps = true
			goto continue
		end

		if in_deps and string.match(line, "}") then
			in_deps = false
			goto continue
		end

		if in_deps then
			handle_package(buf, i, ns_id, line)
		end

		::continue::
	end
end

---parse args
---@param args_str string
---@return table
local function parse_args(args_str)
	local args = {}
	for arg in args_str:gmatch("%S+") do
		table.insert(args, arg)
	end
	return args
end

---check if args are valid or not
---@param args table
---@param line string
---@return boolean
local function is_valid_args(args, line)
	if #args == 0 then
		return true
	end

	for i, arg in ipairs(args) do
		-- print(i, arg)
		if string.match(line, arg) then
			return true
		end
	end

	return false
end

---handle updating packages
---@param buf any
---@param lines table
---@param args_str string
M.update_packages = function(buf, lines, args_str)
	local ns_id = vim.api.nvim_create_namespace("depsync")
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	local args = parse_args(args_str)

	local in_deps = false
	for i, line in ipairs(lines) do
		if in_dep_fields(line) then
			in_deps = true
			goto continue
		end

		if in_deps and string.match(line, "}") then
			in_deps = false
			goto continue
		end

		if in_deps and is_valid_args(args, line) then
			handle_package_update(buf, i, line)
		end

		::continue::
	end
end

return M
