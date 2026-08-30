-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds: https://www.lazyvim.org/configuration/autocmds
-- Add any additional autocmds here

local autocmd = vim.api.nvim_create_autocmd

-- ==========================================
-- Autosave
-- ==========================================
-- Debounced, current-buffer-only. The previous version ran `wall` directly on
-- TextChanged, which wrote every modified buffer on nearly every edit and
-- re-triggered format-on-save and any external file watchers mid-keystroke.

local save_timer = (vim.uv or vim.loop).new_timer()

autocmd({ "InsertLeave", "TextChanged", "FocusLost", "BufLeave" }, {
  callback = function(ev)
    local buf = ev.buf
    save_timer:stop()
    save_timer:start(
      1000,
      0,
      vim.schedule_wrap(function()
        if not vim.api.nvim_buf_is_valid(buf) then
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
