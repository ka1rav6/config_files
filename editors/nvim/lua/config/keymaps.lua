-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps: https://www.lazyvim.org/configuration/keymaps
-- Add any additional keymaps here

local map = vim.keymap.set

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

map("n", "<Tab>", "<cmd>bnext<CR>", { silent = true, desc = "Next Buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<CR>", { silent = true, desc = "Previous Buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { silent = true, desc = "Next Buffer" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { silent = true, desc = "Previous Buffer" })

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
-- Intentionally empty. LazyVim already maps K / gd / gr / gI to picker-backed
-- versions that handle multiple results. Mapping bare `gr` here also shadowed
-- Neovim 0.11+'s built-in grn / gra / grr / gri.
