local o = vim.opt

-- file format
o.fileformat = "unix"
o.enc = "utf-8"
o.fenc = "utf-8"

-- view
--o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.laststatus = 3
o.clipboard:append({ "unnamed", "unnamedplus" })
o.mouse = ""
-- Whether to use actual tab characters (false) or spaces
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

-- tabstop: When space is used, indentwidth is be controlled by this only
o.tabstop = 4
o.softtabstop = -1
o.shiftwidth = 0

-- search
o.ignorecase = true
o.smartcase = true

-- others
o.list = true
o.listchars = 'tab:▸-'
