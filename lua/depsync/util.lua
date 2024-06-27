---@class Utils
local M = {}

local npm = "package.json"
local cargo = "cargo.toml"

local supported_package_files = {
	npm,
	cargo,
}

---Function to check if the buffer is a package file
---@param buffer_name any
---@return boolean
M.is_package_file = function(buffer_name)
	for _, file in ipairs(supported_package_files) do
		if string.find(string.lower(buffer_name), file) then
			return true
		end
	end
	return false
end

---Function to parse a package string
---@param package_string string
---@param buf_name string
---@return string
---@return string
local function parse_package_string(package_string, buf_name)
	-- Pattern to match the package name and semver version
	local pattern
	if buf_name:sub(- #npm) == npm then
		pattern = '"([^"]+)":%s*"([^"]+)"'
	elseif buf_name:sub(- #cargo) == cargo then
		pattern = '([%w_]+)%s*=%s*"(.-)"'
	end

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

---Function to get the highlight group based on semver comparison
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
	'"dependencies":',
	'"devDependencies":',
	'"peerDependencies":',
	'"optionalDependencies":',
	"[dependencies]",
	"[build-dependencies]",
	"[dev-dependencies]"
}

---Check if the line is a dependency field
---@param line string
---@return boolean
local function in_dep_fields(line)
	for _, field in ipairs(dep_fields) do
		if line:find(field, 1, true) ~= nil then
			return true
		end
	end

	return false
end

---Get the dependency search command
---@param buf_name string
---@param package_name string
---@return string?
local function get_dep_search_cmd(buf_name, package_name)
	if buf_name:sub(- #npm) == npm then
		return "npm view " .. package_name .. " version"
	elseif buf_name:sub(- #cargo) == cargo then
		return "cargo search --limit 1 " .. package_name
	end
	return nil
end

---Modified handle_package function to return results
---@param buf any
---@param buf_name string
---@param i integer
---@param ns_id any
---@param line string
local function handle_package(buf, buf_name, i, ns_id, line)
	local package_name, current_version = parse_package_string(line, buf_name)

	local add_version = function(_, data)
		if data then
			local version_data = data[1]
			local short_semver_pattern = '%d+%.%d+%.%d+'
			local long_semver_pattern = '%d+%.%d+%.%d+[-%w%.]*%+?[%w%.]*'
			local short_latest_version = version_data:match(short_semver_pattern)
			local long_latest_version = version_data:match(long_semver_pattern)

			if long_latest_version ~= current_version then
				local highlight = get_highlight_from_semver_cmp(current_version, short_latest_version)
				add_virtual_text(buf, i - 1, "Outdated: " .. long_latest_version, ns_id, highlight)
			end
		end
	end

	if package_name == nil or current_version == nil then
		return
	end

	local cmd = get_dep_search_cmd(buf_name, package_name)
	if cmd ~= nil then
		vim.fn.jobstart(cmd, {
			stdout_buffered = true,
			on_stdout = add_version,
		})
	end
end

---Handle updating packages
---@param buf any
---@param buf_name string
---@param i integer
---@param line string
local function handle_package_update(buf, buf_name, i, line)
	local package_name, current_version = parse_package_string(line, buf_name)

	local handle_version = function(_, data)
		if data then
			local version_data = data[1]
			local long_semver_pattern = '%d+%.%d+%.%d+[-%w%.]*%+?[%w%.]*'
			local long_latest_version = version_data:match(long_semver_pattern)

			if long_latest_version ~= current_version then
				local new_line = string.gsub(line, current_version, long_latest_version)
				vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { new_line })
			end
		end
	end

	if package_name == nil or current_version == nil then
		return
	end

	local cmd = get_dep_search_cmd(buf_name, package_name)
	if cmd ~= nil then
		vim.fn.jobstart(cmd, {
			stdout_buffered = true,
			on_stdout = handle_version,
		})
	end
end

local comment_chars = { "#", "//" };

---Check if the line starts with a commend
---@param line string
---@return boolean
local function is_comment(line)
	for _, char in ipairs(comment_chars) do
		if string.match(line, "^%s*" .. char) then
			return true
		end
	end
	return false
end

---Modified sync_packages function to run handle_package in parallel
---@param buf any
---@param buf_name string
---@param lines string[]
M.sync_packages = function(buf, buf_name, lines)
	local ns_id = vim.api.nvim_create_namespace("depsync")
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	local in_deps = false
	for i, line in ipairs(lines) do
		if in_dep_fields(line) then
			in_deps = true
			goto continue
		end

		if in_deps and (string.match(line, "}") or string.sub(line, 1, 1) == "[") then
			in_deps = false
			goto continue
		end

		if in_deps and not is_comment(line) then
			handle_package(buf, buf_name, i, ns_id, line)
		end

		::continue::
	end
end

---parse args
---@param args_str string
---@return string[]
local function parse_args(args_str)
	local args = {}
	for arg in args_str:gmatch("%S+") do
		table.insert(args, arg)
	end
	return args
end

---check if args are valid or not
---@param args string[]
---@param line string
---@return boolean
local function is_valid_args(args, line)
	if #args == 0 then
		return true
	end

	for _, arg in ipairs(args) do
		if string.match(line, arg) then
			return true
		end
	end

	return false
end

---handle updating packages
---@param buf any
---@param buf_name string
---@param lines string[]
---@param args_str string
M.update_packages = function(buf, buf_name, lines, args_str)
	local ns_id = vim.api.nvim_create_namespace("depsync")
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	local args = parse_args(args_str)

	local in_deps = false
	for i, line in ipairs(lines) do
		if in_dep_fields(line) then
			in_deps = true
			goto continue
		end

		if in_deps and (string.match(line, "}") or string.sub(line, 1, 1) == "[") then
			in_deps = false
			goto continue
		end

		if in_deps and is_valid_args(args, line) then
			handle_package_update(buf, buf_name, i, line)
		end

		::continue::
	end
end

return M
