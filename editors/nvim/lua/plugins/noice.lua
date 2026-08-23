return {
  {
    "folke/noice.nvim",
    opts = {
      routes = {
        {
          filter = {
            event = "lsp",
            kind = "progress",
          },
          opts = {
            skip = true,
          },
        },
      },
    },
  },
}
