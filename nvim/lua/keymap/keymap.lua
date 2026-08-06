-- Key map

-- ,uをleaderにする
vim.keymap.set("n", ",u", "<Nop>", { noremap = true, silent = true })

-- nnoremap
local opts = { noremap = true, silent = true }
for k, v in pairs({
	[",r"] = ":lua vim.cmd('source ' .. vim.fn.stdpath('config') .. '/init.lua')<CR>",
	[",ug"] = ":LazyGit<CR>",
}) do
	vim.api.nvim_set_keymap("n", k, v, opts)
end

-- Fern
vim.keymap.set("n", ",uj", function()
	local cmd = "Fern . -drawer -toggle"
	if vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
		cmd = cmd .. " -reveal=%"
	end
	vim.cmd(cmd)
end, { silent = true, desc = "Toggle Fern drawer" })

-- Claude Code keymaps
local claude_opts = { noremap = true, silent = true }
vim.keymap.set("n", ",ua", "<cmd>ClaudeCode<cr>", vim.tbl_extend("force", claude_opts, { desc = "Toggle Claude Code" }))
vim.keymap.set("n", ",uf", "<cmd>ClaudeCodeFocus<cr>", vim.tbl_extend("force", claude_opts, { desc = "Focus Claude Code" }))
vim.keymap.set("n", ",ur", "<cmd>ClaudeCode --resume<cr>", vim.tbl_extend("force", claude_opts, { desc = "Resume Claude session" }))
vim.keymap.set("n", ",ub", "<cmd>ClaudeCodeAdd %<cr>", vim.tbl_extend("force", claude_opts, { desc = "Add buffer to Claude" }))
vim.keymap.set("v", ",us", "<cmd>ClaudeCodeSend<cr>", vim.tbl_extend("force", claude_opts, { desc = "Send selection to Claude" }))
vim.keymap.set("n", ",ut", "<cmd>ClaudeCodeTreeAdd<cr>", vim.tbl_extend("force", claude_opts, { desc = "Add file from tree" }))
