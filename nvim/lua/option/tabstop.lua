-- local filetype_tabstop = { lua=2, markdown=2,js=4 }

-- augroup の定義
vim.api.nvim_create_augroup("typescript", { clear = true })

-- ファイルの読み込みや新規作成時のファイルタイプ設定
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
	group = "typescript",
	pattern = "*.tsx",
	callback = function()
		vim.bo.filetype = "typescript"
		vim.bo.syntax = "typescriptreact"
	end,
})

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
	group = "typescript",
	pattern = "*.ts",
	callback = function()
		vim.bo.filetype = "typescript"
		vim.bo.syntax = "javascript"
	end,
})
