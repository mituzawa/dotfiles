require("formatter").setup({
	-- 通常の保存は無音のまま、整形に失敗したときだけ通知する
	logging = true,
	log_level = vim.log.levels.ERROR,
	filetype = {
		c = {
			require("formatter.filetypes.c").clangformat,
		},
		cpp = {
			require("formatter.filetypes.cpp").clangformat,
		},
		html = {
			-- formatter.filetypes.html は djlint を持たない（prettier 系と tidy のみ）ので
			-- defaults から直接取る。nil を入れると「No formatter defined」になる
			require("formatter.defaults").djlint,
		},
		css = {
			require("formatter.filetypes.css").prettierd,
		},
		javascript = {
			require("formatter.filetypes.javascript").biome,
		},
		markdown = {
			function()
				return {
					exe = "mdformat",
					-- 末尾の "-" が無いと mdformat は標準入力を読まず、
					-- 警告を stderr に出して終了コード 0 で終わる（＝無反応になる）
					args = { "--wrap", "80", "-" },
					stdin = true,
				}
			end,
		},
		typescript = {
			require("formatter.filetypes.typescript").biome,
		},
		liquid = {
			function()
				return {
					exe = "djlint",
					args = { "--reformat", "-" },
					stdin = true,
				}
			end,
		},
		json = {
			function()
				return {
					exe = "jq",
					args = { "." },
					stdin = true,
				}
			end,
		},
		yaml = {
			function()
				return {
					exe = "yamlfix",
					args = { "-" },
					stdin = true,
				}
			end,
		},
		-- .jsx / .tsx の filetype は javascriptreact / typescriptreact
		javascriptreact = {
			require("formatter.filetypes.javascriptreact").biome,
		},
		typescriptreact = {
			require("formatter.filetypes.typescriptreact").biome,
		},
		-- .sh / .bashrc / .profile はいずれも filetype=sh になるのでこの1つで足りる
		sh = {
			function()
				-- formatter.filetypes.sh.shfmt は vim.opt.shiftwidth:get() をそのまま渡すため、
				-- shiftwidth=0（tabstop に追従させる設定）だと -i 0 = タブ整形になってしまう。
				-- 実効値を返す vim.fn.shiftwidth() を使う
				-- -ci: case のパターンをインデントしたままにする（既存スクリプトの書き方に合わせる）
				return {
					exe = "shfmt",
					args = { "-ci", "-i", vim.bo.expandtab and vim.fn.shiftwidth() or 0 },
					stdin = true,
				}
			end,
		},
		lua = {
			function()
				return {
					exe = "stylua",
					args = { "--stdin-filepath", vim.api.nvim_buf_get_name(0), "--", "-" },
					stdin = true,
				}
			end,
		},
	},
})
