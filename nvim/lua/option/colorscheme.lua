-- lua_source {{{
require('kanagawa').setup({
  theme = "wave",
  undercurl = true,
  commentStyle = { italic = true },
  keywordStyle = { italic = true },
  statementStyle = { bold = true },
  transparent = true,
})
vim.cmd("colorscheme kanagawa")
-- }}}
