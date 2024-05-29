local json = require("dkjson")

registry_domain = "https://registry.npmjs.org"

---@class CustomModule
local M = {}

---Function to sync packages
function check_deps(dependencies)
	for k, v in pairs(dependencies) do
		print(k, v)
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

	local lua_table, _, err = json.decode(table.concat(lines), 1, nil)

	if err then
		return "Error:" .. err
	else
		-- Print the parsed table
		check_deps(lua_table.dependencies)
	end

	return "Synced packages!"
end

return M
