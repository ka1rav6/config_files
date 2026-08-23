set number


set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent

set ignorecase
set smartcase
set incsearch
set hlsearch


syntax on
set termguicolors
set background=dark
colorscheme elflord


set undofile
set backup
set writebackup
set swapfile


set splitbelow
set splitright

set scrolloff=8
set sidescrolloff=8
set nowrap
set signcolumn=yes


set cursorline
set showcmd
set ruler
set wildmenu
set mouse=a


call plug#begin('~/.vim/plugged')

Plug 'preservim/nerdtree'

call plug#end()

set clipboard=unnamedplus
