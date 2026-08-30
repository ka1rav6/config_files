return {
  -- NERDTree and lazygit.nvim removed: LazyVim already ships neo-tree
  -- (<leader>e) and snacks' lazygit integration (<leader>gg).
  { "tpope/vim-fugitive", cmd = { "Git", "G", "Gdiffsplit", "Gread", "Gwrite", "Gclog" } },
  { "ThePrimeagen/vim-be-good", cmd = "VimBeGood" },
}
