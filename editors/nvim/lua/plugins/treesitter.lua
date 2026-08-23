return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "c",
        "cpp",
        "lua",
        "python",
        "zig",
        "javascript",
        "typescript",
      })
    end,
  },
}
