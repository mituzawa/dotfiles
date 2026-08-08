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

-- nvim-tree
vim.keymap.set("n", ",uj", function()
	-- 実ファイルのバッファならそのファイルを reveal しつつ開閉する
	if vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
		vim.cmd("NvimTreeFindFileToggle")
	else
		vim.cmd("NvimTreeToggle")
	end
end, { silent = true, desc = "Toggle nvim-tree" })

-- Claude Code keymaps
-- ,a を prefix にする（,u は ddu 用なので衝突させない）
local claude_opts = { noremap = true, silent = true }
vim.keymap.set("n", ",ac", "<cmd>ClaudeCode<cr>", vim.tbl_extend("force", claude_opts, { desc = "Toggle Claude Code" }))
vim.keymap.set("n", ",af", "<cmd>ClaudeCodeFocus<cr>", vim.tbl_extend("force", claude_opts, { desc = "Focus Claude Code" }))
-- ,ar は一覧から選択、,ak はこのリポジトリの最新セッションを即再開
vim.keymap.set("n", ",ar", "<cmd>ClaudeCode --resume<cr>", vim.tbl_extend("force", claude_opts, { desc = "Resume Claude session (pick)" }))
vim.keymap.set("n", ",ak", "<cmd>ClaudeCode --continue<cr>", vim.tbl_extend("force", claude_opts, { desc = "Continue last Claude session" }))
vim.keymap.set("n", ",ab", "<cmd>ClaudeCodeAdd %<cr>", vim.tbl_extend("force", claude_opts, { desc = "Add buffer to Claude" }))
vim.keymap.set("v", ",as", "<cmd>ClaudeCodeSend<cr>", vim.tbl_extend("force", claude_opts, { desc = "Send selection to Claude" }))
vim.keymap.set("n", ",at", "<cmd>ClaudeCodeTreeAdd<cr>", vim.tbl_extend("force", claude_opts, { desc = "Add file from tree" }))
-- ,al は Claude ペインで流れて見えなくなった部分を読み返す用（lua/plugins/claude_transcript.lua）
vim.keymap.set("n", ",al", "<cmd>ClaudeLog<cr>", vim.tbl_extend("force", claude_opts, { desc = "Open Claude transcript" }))
