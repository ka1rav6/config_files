return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          -- --log=error: clangd's default level logs every request to stderr,
          -- and Neovim copies all LSP stderr into ~/.local/state/nvim/lsp.log.
          -- That was 99% of a 115 MB log (439k of 444k lines).
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=never",
            "--log=error",
            -- Without this, clangd guesses system include paths from its own
            -- builtins. With it, clangd runs the driver a compile_commands.json
            -- actually names and asks it, so a g++-15 project gets libstdc++-15
            -- headers instead of whatever clangd would have picked.
            "--query-driver=/usr/bin/g++*,/usr/bin/gcc*,/usr/bin/clang*,/usr/bin/*-g++-*,/usr/bin/*-gcc-*",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            -- Preambles are ~10 MB per TU here; keeping them in RAM avoids
            -- writing them to $TMPDIR on every reparse.
            "--pch-storage=memory",
          },
          -- The -std=c++23 baseline lives in ~/.config/clangd/config.yaml so it
          -- applies to any clangd client, not just Neovim.
        },
        pyright = {},
        ruff = {},
        ts_ls = {},

        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              -- Silences "file not included in the module tree" for scratch/
              -- standalone .rs files that no crate root declares a `mod` for.
              diagnostics = { disabled = { "unlinked-file" } },
            },
          },
        },

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
