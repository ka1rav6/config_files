return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      zig = { "zigfmt" },
      c = { "clang_format" },
      cpp = { "clang_format" },
      python = { "ruff_format" },
    },
    formatters = {
      stylua = {
        append_args = { "--indent-type", "Spaces", "--indent-width", "4" },
      },
    },
  },
}
