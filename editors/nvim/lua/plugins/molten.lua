return {
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    build = ":UpdateRemotePlugins",

    init = function()
      vim.g.molten_auto_open_output = true
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_virt_text_output = true
    end,

    keys = {
      { "<leader>mi", "<cmd>MoltenInit<CR>", desc = "Molten Init" },
      { "<leader>ml", "<cmd>MoltenEvaluateLine<CR>", desc = "Run Line" },
      { "<leader>mv", ":MoltenEvaluateVisual<CR>", mode = "v", desc = "Run Selection" },
      { "<leader>mr", "<cmd>MoltenReevaluateCell<CR>", desc = "Re-run Cell" },
      { "<leader>mo", "<cmd>MoltenShowOutput<CR>", desc = "Show Output" },
      { "<leader>mh", "<cmd>MoltenHideOutput<CR>", desc = "Hide Output" },
    },
  },
}
