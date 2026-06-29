-- file format
vim.opt.fileformat = "unix"
vim.opt.fenc = "utf-8"

-- view
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.laststatus = 3
vim.opt.clipboard:append({ "unnamed", "unnamedplus" })
vim.opt.mouse = ""
-- Whether to use actual tab characters (false) or spaces
vim.opt.expandtab = true
vim.opt.syntax = "on"

-- transparent
vim.opt.termguicolors = true
vim.opt.winblend = 0
vim.opt.pumblend = 0
-- vim.cmd [[
--   highlight Normal guibg=none
--   highlight NonText guibg=none
--   highlight Normal ctermbg=none
--   highlight NonText ctermbg=none
-- ]]

-- tabstop: When space is used, indentwidth is be controlled by this only
vim.opt.tabstop = 4
vim.opt.softtabstop = -1
vim.opt.shiftwidth = 0

-- search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- others
vim.opt.list = true
vim.opt.listchars = 'tab:▸-'

vim.g.clipboard = {
  name = "WslClipboard",
  copy = {
    ["+"] = "clip.exe",
    ["*"] = "clip.exe",
  },
  paste = {
    ["+"] = 'powershell.exe -noprofile -command [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    ["*"] = 'powershell.exe -noprofile -command [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
  },
  cache_enabled = 0,
}
