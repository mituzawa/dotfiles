vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = { "*.c", "*.cpp", "*.h", "*.hpp", "*.html", "*.css", "*.js", "*.md", "*.ts", "*.liquid", "*.json", "*.yaml", "*.jsx", "*.tsx", "*.lua" },
	command = "FormatWrite",
})
