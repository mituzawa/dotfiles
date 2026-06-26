-- Key map

-- ,uをleaderにする
local ug_map = {}
ug_map.nop = function() end
vim.api.nvim_set_keymap("n", ",u", ":lua ug_map.nop()<CR>", { noremap = true, silent = true })

-- nnoremap
local opts = { noremap = true, silent = true }
for k, v in pairs({
	[",uj"] = ":<C-u>Fern . -reveal=% -drawer<CR>",
	[",r"] = ":lua vim.cmd('source ' .. vim.fn.stdpath('config') .. '/init.lua')<CR>",
    [",ug"] = ":LazyGit<CR>",
}) do
	vim.api.nvim_set_keymap("n", k, v, opts)
end

-- Claude Code keymaps
local claude_opts = { noremap = true, silent = true }
vim.keymap.set("n", ",ua", "<cmd>ClaudeCode<cr>", vim.tbl_extend("force", claude_opts, { desc = "Toggle Claude Code" }))
vim.keymap.set("n", ",uf", "<cmd>ClaudeCodeFocus<cr>", vim.tbl_extend("force", claude_opts, { desc = "Focus Claude Code" }))
vim.keymap.set("n", ",ur", "<cmd>ClaudeCode --resume<cr>", vim.tbl_extend("force", claude_opts, { desc = "Resume Claude session" }))
vim.keymap.set("n", ",ub", "<cmd>ClaudeCodeAdd %<cr>", vim.tbl_extend("force", claude_opts, { desc = "Add buffer to Claude" }))
vim.keymap.set("v", ",us", "<cmd>ClaudeCodeSend<cr>", vim.tbl_extend("force", claude_opts, { desc = "Send selection to Claude" }))
vim.keymap.set("n", ",ut", "<cmd>ClaudeCodeTreeAdd<cr>", vim.tbl_extend("force", claude_opts, { desc = "Add file from tree" }))
