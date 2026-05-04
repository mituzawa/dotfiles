-- Function to change the current directory
local function change_current_dir(directory, bang)
	if directory == "" then
		vim.cmd("lcd %:p:h")
	else
		vim.cmd("lcd " .. directory)
	end

	if bang == "" then
		vim.cmd("pwd")
	end
end

-- Command definition for 'CD' with optional arguments and completion
vim.api.nvim_create_user_command("CD", function(opts)
	change_current_dir(opts.args, opts.bang)
end, { nargs = "?", bang = true, complete = "dir" })

-- Key mapping for '<Space>cd' to execute the 'CD' command
vim.api.nvim_set_keymap("n", "<Space>cd", ":CD<CR>", { noremap = true, silent = true })
