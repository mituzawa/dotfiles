" ------------------------------------------------------------
" General Settings
" ------------------------------------------------------------
" Clipboard integration with system clipboard
set clipboard=unnamedplus

" Character encoding
set fenc=utf-8
set encoding=utf-8
scriptencoding utf-8

" Line ending format
set fileformat=unix

" Fix display issues with ambiguous-width characters (□, ○, etc.)
set ambiwidth=double

" Disable backup and swap files
set nobackup
set noswapfile

" Automatically reload file when changed outside of Vim
set autoread

" Allow switching buffers without saving
set hidden

" Show incomplete commands in the status line
set showcmd

" Speed up terminal connection
set ttyfast

" ------------------------------------------------------------
" Appearance
" ------------------------------------------------------------
" Show relative line numbers
" set number
set relativenumber

" Extend cursor to one character past end of line
set virtualedit=onemore

" Enable smart indentation
set smartindent

" Highlight matching brackets
set showmatch

" Always show the status line
set laststatus=2

" Enable command-line completion with wildmenu
set wildmenu
set wildmode=full

" Enable syntax highlighting
syntax enable

" ------------------------------------------------------------
" Tab / Indentation
" ------------------------------------------------------------
" Display invisible characters (tab shown as ▸-)
set list
set listchars=tab:▸-

" Whether to use actual tab characters (noexpandtab) or spaces
set noexpandtab

" When space is used, indentwidth is be controlled by this only
set tabstop=8

" softtabstop follows shiftwidth
set softtabstop=-1

" indentwidth follows tabstop
set shiftwidth=0

" Start scrolling 5 lines before the edge of the window
set scrolloff=5

" ------------------------------------------------------------
" Search
" ------------------------------------------------------------
" Case-insensitive search by default
set ignorecase

" Override ignorecase when query contains uppercase letters
set smartcase

" Incremental search (highlight as you type)
set incsearch

" Wrap search around end of file
set wrapscan

" Highlight search results
set hlsearch

" Clear search highlights with double Esc
nmap <Esc><Esc> :nohlsearch<CR><Esc>

" ------------------------------------------------------------
" Key Mappings
" ------------------------------------------------------------
" Use Space as the leader key
let mapleader = "\<Space>"

" Move by display line (useful with wrapping)
nnoremap j gj
nnoremap k gk

" Exit insert mode with jk
inoremap <silent> jk <ESC>

" ------------------------------------------------------------
" Completion
" ------------------------------------------------------------
" Show completion menu; do not auto-insert
set completeopt=menuone,noinsert

" Confirm completion with Enter without inserting a newline
inoremap <expr><CR> pumvisible() ? "<C-y>" : "<CR>"

" ------------------------------------------------------------
" File Type
" ------------------------------------------------------------
filetype on
filetype indent on
filetype plugin on

" ------------------------------------------------------------
" Trailing Whitespace
" ------------------------------------------------------------
augroup SpaceDelete
  autocmd!
  " Remove trailing whitespace on save (currently disabled)
  " autocmd BufWritePre * :%s/\s\+$//ge
augroup END

" ------------------------------------------------------------
" Full-width Space Highlight
" ------------------------------------------------------------
highlight ZenkakuSpace cterm=underline ctermfg=lightblue guibg=#666666
au BufNewFile,BufRead * match ZenkakuSpace /　/

" ------------------------------------------------------------
" Color Scheme
" ------------------------------------------------------------
colorscheme tender
