local o = vim.opt

-- file format
o.fileformat = "unix"
o.enc = "utf-8"
o.fenc = "utf-8"

-- view
o.number = true
o.signcolumn = "yes"
o.laststatus = 3
o.clipboard:append({ "unnamed,unnamedplus" })
o.mouse = "a"
o.expandtab = true
o.syntax = "on"

-- transparent
o.termguicolors = true
o.winblend = 0
o.pumblend = 0
-- vim.cmd [[
--   highlight Normal guibg=none
--   highlight NonText guibg=none
--   highlight Normal ctermbg=none
--   highlight NonText ctermbg=none
-- ]]

-- tabstop
o.tabstop = 4
o.shiftwidth = 4

-- search
o.ignorecase = true
o.smartcase = true
