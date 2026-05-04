-- ddu のグローバル設定を Lua 形式で設定
vim.fn["ddu#custom#patch_global"]({
	ui = "ff",
	uiParams = {
		ff = {
			floatingBorder = "single",
			autoResize = false,
			previewFloating = true,
			previewFloatingBorder = "single",
			previewFloatingTitle = "Preview",
			previewSplit = "vertical",
			previewHeight = "&lines - 8",
			previewWidth = "&columns / 2 - 2",
			previewRow = 1,
			previewCol = "&columns / 2 + 1",
			prompt = "> ",
			startAutoAction = true,
			autoAction = {
				delay = 0,
				name = "preview",
			},
			split = "floating",
			startFilter = true,
			updateTime = 0,
			winHeight = "&lines - 8",
			winWidth = "&columns / 2 - 2",
			winRow = 1,
			winCol = 1,
		},
	},
	sources = {
		{ name = "file", params = {} },
		{
			name = "file_rec",
			params = { ignoredDirectories = { ".git", "node_modules", "vendor", ".next", ".vscode" } },
		},
		{ name = "mr" },
		{ name = "file_point" },
		{ name = "register" },
		{ name = "buffer" },
		{ name = "colorscheme" },
	},
	sourceParams = {
		rg = {
			args = { "--column", "--no-heading", "--color", "never" },
		},
	},
	sourceOptions = {
		_ = {
			matchers = { "matcher_substring" },
			converters = {
				"converter_devicon",
			},
			ignoreCase = true,
		},
	},
	kindOptions = {
		file = {
			defaultAction = "open",
		},
		colorscheme = {
			defaultAction = "set",
		},
	},
})

-- ddu-ff ファイルタイプのときに設定を行うオートコマンドを作成
vim.api.nvim_create_autocmd("FileType", {
	pattern = "ddu-ff",
	callback = function()
		for k, v in pairs({
			["<CR>"] = "itemAction",
			q = "quit",
			["<Space>"] = "toggleSelectItem",
			i = "openFilterWindow",
			P = "togglePreview",
		}) do
			vim.api.nvim_buf_set_keymap(
				0,
				"n",
				k,
				"<Cmd>call ddu#ui#do_action('" .. v .. "')<CR>",
				{ noremap = true, silent = true }
			)
		end
	end,
})

-- ddu-ff-filter ファイルタイプのときに設定を行うオートコマンドを作成
vim.api.nvim_create_autocmd("FileType", {
	pattern = "ddu-ff-filter",
	callback = function()
		local option = { noremap = true, silent = true }
		-- インサートモードで Enter キーと Esc キーでウィンドウを閉じる
		vim.api.nvim_buf_set_keymap(0, "i", "<CR>", "<Esc><Cmd>close<CR>", option)
		vim.api.nvim_buf_set_keymap(0, "i", "<Esc>", "<Esc><Cmd>close<CR>", option)

		-- ノーマルモードで Enter キーと Esc キーでウィンドウを閉じる
		vim.api.nvim_buf_set_keymap(0, "n", "<CR>", "<Cmd>close<CR>", option)
		vim.api.nvim_buf_set_keymap(0, "n", "<Esc>", "<Cmd>close<CR>", option)
	end,
})

-- nnoremap
local opts = { noremap = true, silent = true }
for k, v in pairs({
	[",um"] = ":<C-u>Ddu mr<CR>",
	[",ub"] = ":<C-u>Ddu buffer<CR>",
	[",ur"] = ":<C-u>Ddu register<CR>",
	[",uc"] = ":<C-u>Ddu file_rec<CR>",
	[",un"] = ":<C-u>Ddu file -source-param-new -volatile<CR>",
	[",uf"] = ":<C-u>Ddu file<CR>",
	[",up"] = ":<C-u>Ddu file_point<CR>",
	[",ul"] = ":<C-u>Ddu colorscheme<CR>",
}) do
	vim.api.nvim_set_keymap("n", k, v, opts)
end
