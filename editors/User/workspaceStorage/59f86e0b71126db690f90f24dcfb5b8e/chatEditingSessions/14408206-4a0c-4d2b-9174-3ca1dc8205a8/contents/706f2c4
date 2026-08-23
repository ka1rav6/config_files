-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds: https://www.lazyvim.org/configuration/autocmds
-- Add any additional autocmds here

local autocmd = vim.api.nvim_create_autocmd

-- ==========================================
-- Indentation
-- ==========================================

autocmd("FileType", {
  pattern = {
    "html",
    "css",
    "javascript",
    "typescript",
  },

  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = true
  end,
})

autocmd("FileType", {
  pattern = {
    "c",
    "cpp",
    "python",
    "zig",
    "java",
  },

  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = true
  end,
})

-- ==========================================
-- Autosave
-- ==========================================

autocmd({
  "InsertLeave",
  "TextChanged",
}, {
  callback = function()
    vim.cmd("silent! wall")
  end,
})
