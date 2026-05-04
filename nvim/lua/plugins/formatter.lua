require("formatter").setup({
	logging = false,
	filetype = {
		html = {
			require("formatter.filetypes.html").djlint,
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
					args = { "--wrap", "80" },
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
		jsx = {
			require("formatter.filetypes.javascriptreact").biome,
		},
		tsx = {
			require("formatter.filetypes.typescriptreact").biome,
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
