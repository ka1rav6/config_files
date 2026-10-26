-- VS Code-style multiple cursors.
--
-- Unlike vim-visual-multi this plugin has no separate "multi-cursor mode" to
-- learn: once extra cursors exist, normal / insert / visual mode all behave as
-- usual and every cursor runs the same command. That is what makes it feel
-- like VS Code rather than like a vim plugin.
--
-- Key choices (see the table in the chat answer for the VS Code equivalents):
--   * <C-d> is NOT taken -- it stays half-page scroll (neoscroll). <C-n> and
--     <C-S-d> both do VS Code's Ctrl+D job instead.
--   * <C-A-Down>/<C-A-Up> (VS Code's add-cursor-below/above) is swallowed by
--     Ghostty's goto_split, so <C-Down>/<C-Up> are used.
--   * The <C-S-*> bindings need the kitty keyboard protocol, which Ghostty +
--     Neovim 0.12 negotiate automatically. Over plain SSH or in a terminal
--     without it they collapse onto their unshifted twin -- if <C-S-d> ever
--     page-scrolls, that is why; drop that line and use <C-n>.
--   * <C-Space> (not <C-CR>, which never arrived) is the Alt+Click stand-in.
--     Neovim keeps <C-Space> distinct from the NUL byte a pre-CSI-u terminal
--     actually sends, so <C-@> is bound to the same command as a fallback.
return {
    {
        "brenton-leighton/multiple-cursors.nvim",
        -- main, not a tag: MultipleCursorsAddDelete (the keyboard stand-in for
        -- VS Code's Alt+Click, bound to <C-Space> below) was merged after v0.15.
        branch = "main",
        opts = {
            -- VS Code's "select all occurrences" searches the whole file, not
            -- just the part that happens to be on screen.
            match_visible_only = false,

            pre_hook = function()
                -- cursorline and matchparen both follow the real cursor only,
                -- so they actively mislead once there are several.
                vim.opt.cursorline = false
                vim.cmd("NoMatchParen")
                -- mini.pairs would insert a closing pair per cursor.
                vim.g.minipairs_disable = true
                -- blink.cmp popups fight the per-cursor insert handling.
                vim.b.completion = false
                -- smear animates one cursor between positions; with several it
                -- draws trails between unrelated cursors.
                local ok, smear = pcall(require, "smear_cursor")
                if ok then
                    smear.enabled = false
                end
            end,

            post_hook = function()
                vim.opt.cursorline = true
                vim.cmd("DoMatchParen")
                vim.g.minipairs_disable = false
                vim.b.completion = nil
                local ok, smear = pcall(require, "smear_cursor")
                if ok then
                    smear.enabled = true
                end
            end,
        },

        keys = {
            -- VS Code Ctrl+D: add a cursor here, jump to the next occurrence
            -- of the word under the cursor (or of the visual selection).
            {
                "<C-n>",
                "<Cmd>MultipleCursorsAddJumpNextMatch<CR>",
                mode = { "n", "x" },
                desc = "Multicursor: add cursor, next match",
            },
            {
                "<C-S-d>",
                "<Cmd>MultipleCursorsAddJumpNextMatch<CR>",
                mode = { "n", "x" },
                desc = "Multicursor: add cursor, next match",
            },
            -- VS Code Ctrl+K Ctrl+D: skip this occurrence.
            {
                "<C-S-k>",
                "<Cmd>MultipleCursorsJumpNextMatch<CR>",
                mode = { "n", "x" },
                desc = "Multicursor: skip to next match",
            },
            -- VS Code Ctrl+Shift+L: every occurrence in the file at once.
            {
                "<C-S-l>",
                "<Cmd>MultipleCursorsAddMatches<CR>",
                mode = { "n", "x" },
                desc = "Multicursor: all matches in file",
            },

            -- VS Code Ctrl+Alt+Down / Ctrl+Alt+Up: a column of cursors.
            {
                "<C-Down>",
                "<Cmd>MultipleCursorsAddDown<CR>",
                mode = { "n", "i", "x" },
                desc = "Multicursor: add cursor below",
            },
            {
                "<C-Up>",
                "<Cmd>MultipleCursorsAddUp<CR>",
                mode = { "n", "i", "x" },
                desc = "Multicursor: add cursor above",
            },

            -- The keyboard replacement for VS Code's Alt+Click: drop a cursor
            -- where you are, move anywhere with ordinary motions, drop another.
            -- Pressing it on an existing cursor removes that one.
            {
                "<C-Space>",
                "<Cmd>MultipleCursorsAddDelete<CR>",
                mode = "n",
                desc = "Multicursor: pin/unpin cursor here",
            },
            -- Terminals without the kitty keyboard protocol send NUL for
            -- Ctrl+Space, which reaches Neovim as <C-@> -- a separate keycode
            -- from <C-Space>, so both have to be bound. Normal mode only, so
            -- insert-mode i_CTRL-@ and blink.cmp's <C-Space> are untouched.
            {
                "<C-@>",
                "<Cmd>MultipleCursorsAddDelete<CR>",
                mode = "n",
                desc = "Multicursor: pin/unpin cursor here",
            },

            -- VS Code Alt+Click, plus the plugin's own <C-LeftMouse>. Clicking
            -- an existing cursor removes it. Needs mouse != "" (LazyVim sets
            -- mouse = "a"), otherwise the clicks go to Ghostty instead.
            -- <A-LeftMouse> is free: Hyprland drags windows with SUPER, not ALT.
            -- <C-LeftMouse> displaces Neovim's built-in click-to-jump-to-tag,
            -- which LazyVim's LSP `gd` already supersedes.
            {
                "<C-LeftMouse>",
                "<Cmd>MultipleCursorsMouseAddDelete<CR>",
                mode = { "n", "i" },
                desc = "Multicursor: add/remove cursor at click",
            },
            {
                "<A-LeftMouse>",
                "<Cmd>MultipleCursorsMouseAddDelete<CR>",
                mode = { "n", "i" },
                desc = "Multicursor: add/remove cursor at click",
            },

            -- VS Code Shift+Alt+I: one cursor per line of the selection.
            {
                "<leader>m",
                "<Cmd>MultipleCursorsAddVisualArea<CR>",
                mode = "x",
                desc = "Multicursor: cursor per selected line",
            },
        },
    },

    -- which-key's `v` operator hint makes the start of a visual area land in
    -- the wrong place when a motion follows within timeoutlen while multiple
    -- cursors are active. Drop just that one preset entry (which-key v3 stores
    -- the presets as a list, so the plugin README's `operators["v"] = nil` does
    -- not apply here).
    {
        "folke/which-key.nvim",
        opts = function(_, opts)
            local operators = require("which-key.plugins.presets").operators
            for i, spec in ipairs(operators) do
                if spec[1] == "v" then
                    table.remove(operators, i)
                    break
                end
            end
            return opts
        end,
    },
}
