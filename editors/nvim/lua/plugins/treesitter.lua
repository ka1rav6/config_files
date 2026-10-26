return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Brace style and operator spacing are hand-maintained in C/C++, and the
      -- treesitter indent queries mis-indent Allman braces (notably the `{`
      -- after a bare `else`, and anything typed while the tree is still
      -- incomplete). Fall back to Neovim's native `cindent` for these two.
      opts.indent = { enable = true, disable = { "c", "cpp" } }

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
