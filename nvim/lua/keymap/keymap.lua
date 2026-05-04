-- Key map

-- ,uをleaderにする
local ug_map = {}
ug_map.nop = function() end
vim.api.nvim_set_keymap("n", ",u", ":lua ug_map.nop()<CR>", { noremap = true, silent = true })

-- nnoremap
local opts = { noremap = true, silent = true }
for k, v in pairs({
	[",uj"] = ":<C-u>Fern . -reveal=% -drawer<CR>",
	[",r"] = ":lua vim.cmd('source ' .. vim.fn.stdpath('config') .. '/init.lua')<CR>",
    [",ug"] = ":LazyGit<CR>",
}) do
	vim.api.nvim_set_keymap("n", k, v, opts)
end
