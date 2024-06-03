vim.api.nvim_create_user_command("DepSync", require("depsync").sync, {})
vim.api.nvim_create_user_command("DepSyncUpdate", require("depsync").update, {})
