-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds: https://www.lazyvim.org/configuration/autocmds
-- Add any additional autocmds here

local autocmd = vim.api.nvim_create_autocmd

-- ==========================================
-- Autosave (+ autoformat, via format-on-save)
-- ==========================================
-- Only fires when entering normal mode. Nothing else writes the buffer: no
-- TextChanged, no FocusLost, no BufLeave. The short debounce coalesces the
-- burst of mode changes an operator produces (`no` -> `n` on every `dd`), and
-- the mode is re-checked at fire time so a quick hop back into insert cancels
-- the write instead of formatting under the cursor mid-keystroke.

local save_timer = (vim.uv or vim.loop).new_timer()

autocmd("ModeChanged", {
  pattern = "*:n",
  callback = function(ev)
    local buf = ev.buf
    save_timer:stop()
    save_timer:start(
      200,
      0,
      vim.schedule_wrap(function()
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        if vim.api.nvim_get_current_buf() ~= buf or vim.fn.mode() ~= "n" then
          return
        end
        local bo = vim.bo[buf]
        if bo.modified and bo.modifiable and bo.buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
          vim.api.nvim_buf_call(buf, function()
            vim.cmd("silent! write")
          end)
        end
      end)
    )
  end,
})
