local cache_path = vim.fn.stdpath("cache") .. "/dpp/repos/github.com"
local dppSrc = cache_path .. "/Shougo/dpp.vim"
local denopsSrc = cache_path .. "/vim-denops/denops.vim"

-- Add path to runtimepath
vim.opt.runtimepath:prepend(dppSrc)

-- check repository exists.
local function ensure_repo_exists(repo_url, dest_path)
	if not vim.loop.fs_stat(dest_path) then
		vim.fn.system({ "git", "clone", "https://github.com/" .. repo_url, dest_path })
	end
end

ensure_repo_exists("vim-denops/denops.vim.git", denopsSrc)
ensure_repo_exists("Shougo/dpp.vim.git", dppSrc)

local dpp = require("dpp")

local dppBase = vim.fn.stdpath("cache") .. "/dpp"
local dppConfig = vim.fn.stdpath("config") .. "/config.ts"

-- option.
local extension_urls = {
	"Shougo/dpp-ext-installer.git",
	"Shougo/dpp-ext-toml.git",
	"Shougo/dpp-protocol-git.git",
	"Shougo/dpp-ext-lazy.git",
	"Shougo/dpp-ext-local.git",
}

-- Ensure each extension is installed and add to runtimepath
for _, url in ipairs(extension_urls) do
	local ext_path = cache_path .. "/" .. string.gsub(url, ".git", "")
	ensure_repo_exists(url, ext_path)
	vim.opt.runtimepath:append(ext_path)
end

-- vim.g.denops_server_addr = "127.0.0.1:41979"
-- vim.g["denops#debug"] = 1

if dpp.load_state(dppBase) then
	vim.opt.runtimepath:prepend(denopsSrc)
	vim.api.nvim_create_augroup("ddp", {})

	vim.api.nvim_create_autocmd("User", {
		pattern = "DenopsReady",
		callback = function()
			dpp.make_state(dppBase, dppConfig)
		end,
	})
end

vim.api.nvim_create_autocmd("User", {
	pattern = "Dpp:makeStatePost",
	callback = function()
		vim.notify("dpp make_state() is done")
	end,
})

if vim.fn["dpp#min#load_state"](dppBase) then
	vim.opt.runtimepath:prepend(denopsSrc)

	vim.api.nvim_create_autocmd("User", {
		pattern = "DenopsReady",
		callback = function()
			dpp.make_state(dppBase, dppConfig)
		end,
	})
end

vim.cmd("filetype indent plugin on")
vim.cmd("syntax on")

-- install
vim.api.nvim_create_user_command("DppInstall", "call dpp#async_ext_action('installer', 'install')", {})

-- update
vim.api.nvim_create_user_command("DppUpdate", function(opts)
	local args = opts.fargs
	vim.fn["dpp#async_ext_action"]("installer", "update", { names = args })
end, { nargs = "*" })
