-- 保存時フォーマット
-- pattern は "*" 固定。対応するファイルタイプの一覧は plugins/formatter.lua が唯一の情報源で、
-- 定義の無いファイルタイプは formatter.nvim 側が即 return するため無害。
-- augroup で囲っているのは ,r (init.lua 再読込) による重複登録を防ぐため。
local group = vim.api.nvim_create_augroup("format_on_save", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
	group = group,
	pattern = "*",
	command = "FormatWrite",
})
