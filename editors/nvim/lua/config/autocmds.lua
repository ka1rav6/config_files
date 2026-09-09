-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds: https://www.lazyvim.org/configuration/autocmds
-- Add any additional autocmds here

local autocmd = vim.api.nvim_create_autocmd
local augroup = function(name)
    return vim.api.nvim_create_augroup("kairav_" .. name, { clear = true })
end

-- ==========================================
-- Autosave (write-only) + format on demand
-- ==========================================
-- Split of concerns:
--   * entering normal mode  -> plain write, NO formatting (keeps the file on
--                              disk fresh without reflowing text under the
--                              cursor while you are still working on it)
--   * `:w` / `:wq` by hand  -> normal LazyVim format-on-save
--   * closing the file      -> format, then write, so what lands on disk when
--                              you walk away is formatted
--
-- Formatting is suppressed for the autosave by flipping LazyVim's per-buffer
-- `b:autoformat` off for the duration of the write; LazyVim's BufWritePre hook
-- reads that flag, so nothing else has to change.

---@param buf integer
---@return boolean
local function writable(buf)
    if not (vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf)) then
        return false
    end
    local bo = vim.bo[buf]
    return bo.modifiable and not bo.readonly and bo.buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
end

-- Write without running any formatter.
---@param buf integer
local function write_unformatted(buf)
    local prev = vim.b[buf].autoformat
    vim.b[buf].autoformat = false
    local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
        vim.cmd("silent! write")
    end)
    vim.b[buf].autoformat = prev -- nil restores "inherit from vim.g.autoformat"
    if not ok then
        vim.notify("autosave failed: " .. tostring(err), vim.log.levels.WARN)
    end
end

-- Write *with* the usual format-on-save pipeline (`:w` semantics).
---@param buf integer
local function write_formatted(buf)
    pcall(vim.api.nvim_buf_call, buf, function()
        vim.cmd("silent! write")
    end)
end

-- ------------------------------------------
-- 1. Autosave on entering normal mode
-- ------------------------------------------
-- Only fires when entering normal mode. Nothing else writes the buffer: no
-- TextChanged, no FocusLost, no BufLeave. The short debounce coalesces the
-- burst of mode changes an operator produces (`no` -> `n` on every `dd`), and
-- the mode is re-checked at fire time so a quick hop back into insert cancels
-- the write.

local save_timer = (vim.uv or vim.loop).new_timer()

autocmd("ModeChanged", {
    group = augroup("autosave"),
    pattern = "*:n",
    callback = function(ev)
        local buf = ev.buf
        save_timer:stop()
        save_timer:start(
            200,
            0,
            vim.schedule_wrap(function()
                if vim.api.nvim_get_current_buf() ~= buf or vim.fn.mode() ~= "n" then
                    return
                end
                if writable(buf) and vim.bo[buf].modified then
                    write_unformatted(buf)
                end
            end)
        )
    end,
})

-- ------------------------------------------
-- 2. Format + write when the file is about to be closed
-- ------------------------------------------
-- QuitPre covers `:q`, `:wq`, `:x`, `ZZ`, `:qa` and closing a window; the write
-- goes through the normal BufWritePre chain, so conform/LSP formatting runs
-- synchronously before Neovim actually leaves. VimLeavePre is the safety net for
-- any other buffers still holding unformatted content at exit.

autocmd("QuitPre", {
    group = augroup("format_on_close"),
    -- `nested` is required: without it the `:write` below would not fire
    -- BufWritePre, and LazyVim's format hook would never run.
    nested = true,
    callback = function(ev)
        if writable(ev.buf) then
            write_formatted(ev.buf)
        end
    end,
})

autocmd("VimLeavePre", {
    group = augroup("format_on_exit"),
    nested = true,
    callback = function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if writable(buf) then
                write_formatted(buf)
            end
        end
    end,
})
