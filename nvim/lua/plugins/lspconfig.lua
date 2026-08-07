-- キーマップは定義していない。Neovim 0.11 以降が組み込みで用意している
-- grn (rename) / gra (code_action) / grr (references) / gri (implementation) /
-- grt (type_definition) / grx (codelens) / gO (document_symbol) /
-- [d ]d (診断ジャンプ) / K (hover) / <C-]> (tagfunc 経由の定義ジャンプ) を使う。

-- この一連の記述で、mason.nvimでインストールしたLanguage Serverが自動的に個別にセットアップされ、利用可能になります
require("mason").setup()
require("mason-lspconfig").setup({
	automatic_enable = {
		"lua_ls",
		"vimls",
		"clangd",
		"rust_analyzer",
		"bashls",
		"pyright",
	},
})
