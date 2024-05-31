local utils = require("depsync.util")
local Job = require("plenary.job")

---@class MainModule
local M = {}

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
	local package_name, current_version = utils.parse_package_string(line)

	Job:new({
		command = 'npm',
		args = { 'view', package_name, 'version' },
		on_exit = vim.schedule_wrap(function(j, return_val)
			local latest_version = j:result()[1]

			if not string.match(latest_version, current_version) then
				local highlight = utils.get_highlight_from_semver_cmp(current_version,
					latest_version)
				utils.add_virtual_text(buf, i - 1, "Outdated: " .. latest_version, ns_id,
					highlight)
			end
		end),
	}):start()
end

---Modified sync_packages function to run handle_package in parallel
---@param buf any
---@param lines any
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
			handle_package(buf, i, ns_id, line)
		end

		::continue::
	end
end

---Sync packages in package.json file
---@return string
M.sync = function()
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
