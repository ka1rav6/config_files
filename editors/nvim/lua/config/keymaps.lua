-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps: https://www.lazyvim.org/configuration/keymaps

local map = vim.keymap.set

-- ==========================================
-- File Explorer
-- ==========================================

map("n", "<C-b>", "<cmd>NERDTreeToggle<CR>", {
  desc = "Toggle NERDTree",
})

-- ==========================================
-- Indentation
-- ==========================================

map("v", "<Tab>", ">gv", {
  noremap = true,
  silent = true,
})

map("v", "<S-Tab>", "<gv", {
  noremap = true,
  silent = true,
})

-- ==========================================
-- Buffers
-- ==========================================

map("n", "<Tab>", "<cmd>bnext<CR>", {
  silent = true,
})

map("n", "<S-Tab>", "<cmd>bprevious<CR>", {
  silent = true,
})

-- ==========================================
-- Duplicate Line
-- ==========================================

map("n", "<leader>d", "yyp", {
  desc = "Duplicate Line",
})

-- ==========================================
-- Git
-- ==========================================

map("n", "<leader>gs", "<cmd>Git<CR>", {
  desc = "Git Status",
})

map("n", "<leader>gc", "<cmd>Git commit<CR>", {
  desc = "Git Commit",
})

-- ==========================================
-- Move Lines
-- ==========================================

map("n", "<A-j>", ":m .+1<CR>==", {
  noremap = true,
  silent = true,
})

map("n", "<A-k>", ":m .-2<CR>==", {
  noremap = true,
  silent = true,
})

map("v", "<A-j>", ":m '>+1<CR>gv=gv", {
  noremap = true,
  silent = true,
})

map("v", "<A-k>", ":m '<-2<CR>gv=gv", {
  noremap = true,
  silent = true,
})

-- ==========================================
-- Folding
-- ==========================================

map("n", "<leader>z", "za", {
  desc = "Toggle Fold",
})

map("n", "<leader>zo", "zR", {
  desc = "Open All Folds",
})

map("n", "<leader>zc", "zM", {
  desc = "Close All Folds",
})

-- ==========================================
-- LSP
-- ==========================================

map("n", "K", vim.lsp.buf.hover)

map("n", "gd", vim.lsp.buf.definition)

map("n", "gr", vim.lsp.buf.references)

map("i", "<C-k>", vim.lsp.buf.signature_help)
