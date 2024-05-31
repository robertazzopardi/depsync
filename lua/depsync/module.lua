local utils = require("depsync.util")
local luv = require("luv")

---@class MainModule
local M = {}

-- Array of all package.json dependency fields
local dep_fields = {
	"dependencies",
	"devDependencies",
	"peerDependencies",
	"optionalDependencies",
}

local function in_dep_fields(line)
	for _, field in ipairs(dep_fields) do
		if string.match(line, '"' .. field .. '":') then
			return true
		end
	end

	return false
end

-- Modified handle_package function to return results
local function handle_package(line_no, line)
	local package_name, current_version = utils.parse_package_string(line)
	local latest_version = utils.fetch_version(package_name)
	return current_version, latest_version
end

-- Modified sync_packages function to run handle_package in parallel
local function sync_packages(buf, lines)
	local in_deps = false

	local ns_id = vim.api.nvim_create_namespace("depsync")
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

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
			-- Create a coroutine for each handle_package call
			local co = coroutine.create(function()
				return handle_package(i, line)
			end)

			-- Resume the coroutine and process its result immediately
			local success, current_version, latest_version = coroutine.resume(co)
			if success then
				if not string.match(latest_version, current_version) then
					utils.add_virtual_text(buf, i - 1, "Outdated: " .. latest_version, ns_id)
				end
			end
		end

		::continue::
	end
end

---@return string
M.my_first_function = function()
	local buf = vim.api.nvim_get_current_buf()
	local buf_name = vim.api.nvim_buf_get_name(buf)

	if not string.find(buf_name, "package.json") then
		return "Not a package.json file"
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	sync_packages(buf, lines)

	return "Synced packages!"
end

return M
