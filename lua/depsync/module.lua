---@class CustomModule
local M = {}

local function fetch_version(package)
	local command = "npm view " .. package .. " version"

	-- Execute the command
	local handle = io.popen(command)
	if not handle then
		error("Failed to execute command: " .. command)
	end

	local result = handle:read("*a")
	handle:close()

	return result
end

---Function to sync packages
local function check_deps(deps)
	for name, old_version in pairs(deps) do
		local latest_version = fetch_version(name)

		print(name, old_version, latest_version)
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

	local lua_table, _, err = vim.json.decode(table.concat(lines))

	if err then
		return "Error:" .. err
	else
		-- Print the parsed table
		check_deps(lua_table.dependencies)
	end

	return "Synced packages!"
end

return M
