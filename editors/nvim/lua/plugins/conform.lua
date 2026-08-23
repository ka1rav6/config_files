return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      zig = { "zigfmt" },
    },
    formatters = {
      stylua = {
        append_args = { "--indent-type", "Spaces", "--indent-width", "4" },
      },
    },
  },
}
