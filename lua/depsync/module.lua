REGESTRY_DOMAIN = "https://registry.npmjs.org"

---@class CustomModule
local M = {}

local function fetch(url)
	-- Determine the operating system
	local os_name
	if package.config:sub(1, 1) == '\\' then
		os_name = "windows"
	else
		os_name = io.popen("uname"):read("*l")
	end

	-- Command to perform the GET request
	local command
	if os_name == "windows" then
		command = 'powershell -Command "(Invoke-WebRequest -Uri \'' .. url .. '\' -UseBasicParsing).Content"'
	elseif os_name == "Linux" or os_name == "Darwin" then
		command = 'curl -s ' .. url
	else
		error("Unsupported operating system: " .. tostring(os_name))
	end

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
	for k, v in pairs(deps) do
		local url = REGESTRY_DOMAIN .. "/" .. k .. "/latest"
		local res = fetch(url)
		local parsed = vim.json.decode(res)

		print(parsed.version)
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
