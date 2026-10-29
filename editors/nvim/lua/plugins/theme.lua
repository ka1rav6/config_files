-- The palette comes from theme-switch; lua/config/theme.lua decides how much
-- of tokyonight it is allowed to override, and holds the off switch.
--
-- `function(_, opts)` rather than a plain table so LazyVim's own tokyonight
-- options survive -- this merges into them instead of replacing them.
return {
    {
        "folke/tokyonight.nvim",
        opts = function(_, opts)
            return vim.tbl_deep_extend("force", opts or {}, require("config.theme").opts())
        end,
    },
}
