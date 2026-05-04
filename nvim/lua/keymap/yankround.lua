-- キーマップ
vim.api.nvim_set_keymap("n", "p", "<Plug>(yankround-p)", { noremap = false, silent = true })
vim.api.nvim_set_keymap("n", "P", "<Plug>(yankround-P)", { noremap = false, silent = true })
vim.api.nvim_set_keymap("n", "<C-p>", "<Plug>(yankround-prev)", { noremap = false, silent = true })
vim.api.nvim_set_keymap("n", "<C-n>", "<Plug>(yankround-next)", { noremap = false, silent = true })

-- 履歴取得数
vim.g.yankround_max_history = 50
