-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Pin the Python provider so molten-nvim keeps working when nvim is launched
-- from inside an activated venv that lacks pynvim.
vim.g.python3_host_prog = "/usr/bin/python3"

-- UI
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.showmode = false
vim.opt.ruler = false
vim.opt.signcolumn = "yes"

-- Wrapping: keep breaks on word boundaries and preserve indent.
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.showbreak = "↳ "

-- Indentation
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Show whitespace that actually matters (trailing / tabs / nbsp).
vim.opt.list = true
vim.opt.listchars = {
    tab = "→ ",
    trail = "·",
    nbsp = "␣",
    extends = "›",
    precedes = "‹",
}

-- Completion
vim.opt.completeopt = {
    "menu",
    "menuone",
    "noinsert",
    "noselect",
}

-- Folding
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"

vim.opt.foldenable = true
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldcolumn = "1"

vim.opt.fillchars = {
    foldopen = "",
    foldclose = "",
    fold = " ",
}
