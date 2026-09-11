return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          -- --log=error: clangd's default level logs every request to stderr,
          -- and Neovim copies all LSP stderr into ~/.local/state/nvim/lsp.log.
          -- That was 99% of a 115 MB log (439k of 444k lines).
          cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=never", "--log=error" },
        },
        pyright = {},
        ruff = {},
        ts_ls = {},

        zls = {
          on_attach = function(client)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
        },
      },
    },
  },
}
