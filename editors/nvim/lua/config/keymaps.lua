-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps: https://www.lazyvim.org/configuration/keymaps
-- Add any additional keymaps here

local map = vim.keymap.set

-- ==========================================
-- Indentation
-- ==========================================

map("v", "<Tab>", ">gv", {
    noremap = true,
    silent = true,
})

map("v", "<S-Tab>", "<gv", {
    noremap = true,
    silent = true,
})

-- ==========================================
-- Buffers
-- ==========================================

map("n", "<Tab>", "<cmd>bnext<CR>", { silent = true, desc = "Next Buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<CR>", { silent = true, desc = "Previous Buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { silent = true, desc = "Next Buffer" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { silent = true, desc = "Previous Buffer" })

-- ==========================================
-- Duplicate Line
-- ==========================================

map("n", "<leader>d", "yyp", {
    desc = "Duplicate Line",
})

-- ==========================================
-- Git
-- ==========================================

map("n", "<leader>gs", "<cmd>Git<CR>", {
    desc = "Git Status",
})

map("n", "<leader>gc", "<cmd>Git commit<CR>", {
    desc = "Git Commit",
})

-- ==========================================
-- Move Lines
-- ==========================================

map("n", "<A-j>", ":m .+1<CR>==", {
    noremap = true,
    silent = true,
})

map("n", "<A-k>", ":m .-2<CR>==", {
    noremap = true,
    silent = true,
})

map("v", "<A-j>", ":m '>+1<CR>gv=gv", {
    noremap = true,
    silent = true,
})

map("v", "<A-k>", ":m '<-2<CR>gv=gv", {
    noremap = true,
    silent = true,
})

-- ==========================================
-- Folding
-- ==========================================

map("n", "<leader>z", "za", {
    desc = "Toggle Fold",
})

map("n", "<leader>zo", "zR", {
    desc = "Open All Folds",
})

map("n", "<leader>zc", "zM", {
    desc = "Close All Folds",
})

-- ==========================================
-- LSP
-- ==========================================
-- Intentionally empty. LazyVim already maps K / gd / gr / gI to picker-backed
-- versions that handle multiple results. Mapping bare `gr` here also shadowed
-- Neovim 0.11+'s built-in grn / gra / grr / gri.

-- ==========================================
-- Visual-mode surround
-- ==========================================
-- Press a quote or bracket while a visual selection is active: the selection
-- gets wrapped in that pair and you drop straight back to normal mode.
--
-- Trade-off: these keys lose their normal visual-mode meaning -- `"` as a
-- register prefix ("+y) and ( ) { } [ ] as sentence/paragraph/section motions.

local ESC = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)

-- 0-based byte offset just past the character starting at 1-based byte col.
local function end_byte(line, col)
    if vim.o.selection == "exclusive" then
        return math.min(col - 1, #line)
    end
    if col > #line then
        return #line
    end
    return col - 1 + vim.fn.byteidx(line:sub(col), 1)
end

local function line_at(row)
    return vim.api.nvim_buf_get_lines(0, row - 1, row, true)[1]
end

local function surround(open, close)
    return function()
        local mode = vim.fn.mode()
        local spos, epos = vim.fn.getpos("v"), vim.fn.getcurpos()
        local srow, scol = spos[2], spos[3]
        local erow, ecol = epos[2], epos[3]
        -- curswant is v:maxcol when the selection was extended with `$`.
        local to_eol = epos[5] >= vim.v.maxcol

        if srow > erow or (srow == erow and scol > ecol) then
            srow, scol, erow, ecol = erow, ecol, srow, scol
        end

        -- Leave visual mode before editing. `:normal!` is used rather than
        -- nvim_feedkeys(): feedkeys writes into the typeahead buffer, which
        -- swallows the next keystroke when the mapping runs inside a macro or
        -- :normal. `:normal!` uses its own buffer and restores state.
        vim.cmd("normal! " .. ESC)

        local set = vim.api.nvim_buf_set_text

        if mode == "V" then
            -- Linewise: wrap the whole block.
            local tail = #line_at(erow)
            set(0, erow - 1, tail, erow - 1, tail, { close })
            set(0, srow - 1, 0, srow - 1, 0, { open })
            scol = 1
        elseif mode == "\22" then
            -- Blockwise: wrap each line's slice.
            local c1, c2 = math.min(scol, ecol), math.max(scol, ecol)
            for row = srow, erow do
                local line = line_at(row)
                if #line >= c1 then
                    -- With `$` each line runs to its own end, not to c2.
                    local e = to_eol and #line or end_byte(line, c2)
                    set(0, row - 1, e, row - 1, e, { close })
                    set(0, row - 1, c1 - 1, row - 1, c1 - 1, { open })
                end
            end
            scol = c1
        else
            -- Charwise.
            local e = end_byte(line_at(erow), ecol)
            set(0, erow - 1, e, erow - 1, e, { close })
            set(0, srow - 1, scol - 1, srow - 1, scol - 1, { open })
        end

        pcall(vim.api.nvim_win_set_cursor, 0, { srow, scol - 1 })
    end
end

-- Both halves of a pair are mapped, so `(` and `)` do the same thing.
local surround_pairs = {
    ['"'] = { '"', '"' },
    ["("] = { "(", ")" },
    [")"] = { "(", ")" },
    ["["] = { "[", "]" },
    ["]"] = { "[", "]" },
    ["{"] = { "{", "}" },
    ["}"] = { "{", "}" },
}

for key, pair in pairs(surround_pairs) do
    map("x", key, surround(pair[1], pair[2]), {
        silent = true,
        desc = "Surround selection with " .. pair[1] .. pair[2],
    })
end
