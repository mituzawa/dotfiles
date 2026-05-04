local on_attach = function(client, bufnr)
	-- LSPが持つフォーマット機能を無効化する
	-- →例えばtsserverはデフォルトでフォーマット機能を提供しますが、利用したくない場合はコメントアウトを解除してください
	--client.server_capabilities.documentFormattingProvider = false

	-- 下記ではデフォルトのキーバインドを設定しています
	-- ほかのLSPプラグインを使う場合（例：Lspsaga）は必要ないこともあります

	local set = vim.keymap.set
	set("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>")
	set("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>")
	set("n", "<C-m>", "<cmd>lua vim.lsp.buf.signature_help()<CR>")
	set("n", "gy", "<cmd>lua vim.lsp.buf.type_definition()<CR>")
	set("n", "rn", "<cmd>lua vim.lsp.buf.rename()<CR>")
	set("n", "ma", "<cmd>lua vim.lsp.buf.code_action()<CR>")
	set("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>")
	set("n", "<space>e", "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>")
	set("n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>")
	set("n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>")
end


-- この一連の記述で、mason.nvimでインストールしたLanguage Serverが自動的に個別にセットアップされ、利用可能になります
require("mason").setup()
require("mason-lspconfig").setup({
    automatic_enable = {
        "lua_ls",
        "vimls"
    }
})
