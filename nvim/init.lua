if not vim.g.vscode then

-- vim.load enable.
--if vim.loader then
--	vim.loader.enable()
--end

-- option
require("option/option")
--require("option/cd")

-- dark powerd vim settings.
require("darkpowerd/dpp")
--require("darkpowerd/ddu")

-- keymaps
require("keymap/keymap")
--require("keymap/yankround")

-- plugins
require("plugins/lspconfig")
require("plugins/formatter")
require("plugins/nvim-tree")
-- require("plugins/autocmd")

end
