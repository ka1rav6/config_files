-- =============================================================================
-- nvim's half of theme-switch.
-- =============================================================================
-- nvim was the one application on this desktop that visibly did not follow a
-- theme switch: everything else -- ghostty, waybar, wofi, mako, btop, tmux, the
-- window borders, the shell -- repainted, and the editor sitting in the middle
-- of the screen kept its old colours until it was restarted.
--
-- IT DRIVES tokyonight, IT DOES NOT REPLACE IT
--   theme-switch writes the nine house colours to ~/.local/state/nvim/
--   theme-palette.lua. This file turns those into tokyonight overrides. It
--   deliberately overrides only the NEUTRALS (backgrounds, borders, text) and
--   the THREE HOUSE ACCENTS, and leaves blue / cyan / purple / magenta as
--   tokyonight tuned them.
--
--   That restraint is the whole design. tokyonight spreads its hues across
--   ~500 highlight groups; rebuilding all of them from three accent colours
--   would turn every theme into the same scheme in three colours, which reads
--   worse than not following the theme at all. What changes here is the
--   furniture -- float and statusline backgrounds, the selection, the gutter,
--   borders -- plus green/yellow/red. Syntax keeps its shape.
--
-- THE OFF SWITCH
--   `appearance.nvimTheme` in ~/.config/quickshell/settings.json, exposed as
--   "Theme nvim too" in the settings panel (SUPER + comma -> Appearance).
--   Turn it off and this file returns stock tokyonight, byte for byte what
--   ~/.config/nvim/lua/plugins/theme.lua asked for before any of this existed.
--   Nothing is left half-applied: the whole palette is dropped, not blended.
--
-- LIVE RELOAD
--   Both files are watched with libuv, so a theme switch or a flip of the
--   toggle repaints every running nvim. That is the same arrangement
--   Quickshell uses for theme.json -- theme-switch writes, consumers watch --
--   and it is why reload_all() in theme-switch has no nvim entry.
-- =============================================================================

local M = {}

local uv = vim.uv or vim.loop

local PALETTE_DIR = vim.fn.stdpath("state")
local PALETTE_NAME = "theme-palette.lua"
local PALETTE = PALETTE_DIR .. "/" .. PALETTE_NAME

local SETTINGS_DIR = os.getenv("HOME") .. "/.config/quickshell"
local SETTINGS_NAME = "settings.json"
local SETTINGS = SETTINGS_DIR .. "/" .. SETTINGS_NAME

-- Default ON: the palette file only exists because theme-switch wrote it, so
-- its presence already means the user opted in. A missing settings.json, an
-- unparseable one, or a missing key must therefore NOT read as off.
--
-- `~= false` rather than a truthiness test, deliberately: `nil` (key absent)
-- has to mean on, and a stored `false` has to survive. Written as `x and y`
-- this returns nil for a missing section and swallows a real `false` the same
-- way -- the two outcomes that must not be confused.
local function enabled()
    local f = io.open(SETTINGS, "r")
    if not f then
        return true
    end
    local raw = f:read("a")
    f:close()
    local ok, decoded = pcall(vim.json.decode, raw)
    if not ok or type(decoded) ~= "table" or type(decoded.appearance) ~= "table" then
        return true
    end
    return decoded.appearance.nvimTheme ~= false
end

---@return table|nil  the nine house colours, or nil for stock tokyonight
local function palette()
    if not enabled() then
        return nil
    end
    local ok, p = pcall(dofile, PALETTE)
    -- `p.bg` is the sentinel for a complete file: dofile on a half-written one
    -- either errors (caught) or returns a table missing its colours.
    if ok and type(p) == "table" and type(p.bg) == "string" then
        return p
    end
    return nil
end

--- Options for the tokyonight spec. Also the single source used on reload.
function M.opts()
    local p = palette()
    if not p then
        return { transparent = true }
    end

    return {
        transparent = true,
        -- `day` is tokyonight's only light style. Which one to use cannot be
        -- worked out from a hex string without the WCAG luminance helpers, so
        -- theme-switch decides and writes `mode`.
        style = p.mode == "light" and "day" or "night",
        on_colors = function(c)
            c.bg = p.bg
            c.bg_dark = p.bg
            -- Floats, popups, the sidebar and the statusline are the surfaces
            -- that stay opaque under `transparent = true`, so these are the
            -- overrides actually visible most of the time.
            c.bg_float = p.surface
            c.bg_popup = p.surface
            c.bg_sidebar = p.surface
            c.bg_statusline = p.surface
            c.bg_highlight = p.surface2
            c.bg_visual = p.surface2
            c.border = p.border
            c.border_highlight = p.border
            c.fg = p.text
            c.fg_dark = p.muted
            c.fg_sidebar = p.muted
            c.fg_gutter = p.muted
            c.comment = p.muted
            -- The three house accents, and only those. a1 is the primary
            -- (green-ish by convention), a2 the warm one, a3 the alert one.
            c.green = p.a1
            c.teal = p.a1
            c.yellow = p.a2
            c.orange = p.a2
            c.red = p.a3
        end,
    }
end

--- Re-apply the colorscheme from the current palette, in a running instance.
function M.reload()
    local ok, err = pcall(function()
        require("tokyonight").setup(M.opts())
        vim.cmd.colorscheme("tokyonight")
    end)
    if not ok then
        vim.notify("theme reload failed: " .. tostring(err), vim.log.levels.WARN)
    end
end

-- Watch the DIRECTORY, not the file: a watcher cannot be started on a path
-- that does not exist yet, and theme-palette.lua is absent until the first
-- theme switch after this was installed. Watching the parent and filtering on
-- the name is one code path that works before and after that point. (It also
-- survives a write that replaces the inode rather than truncating it, which a
-- file watcher does not.)
local function watch(dir, name)
    local handle = uv.new_fs_event()
    if not handle then
        return
    end
    local ok = handle:start(dir, {}, function(err, filename)
        if err or filename ~= name then
            return
        end
        vim.schedule(M.reload)
    end)
    if not ok then
        handle:close()
    end
end

-- Runs once: Lua's module cache is the guard, so requiring this file from the
-- plugin spec cannot start a second pair of watchers.
watch(PALETTE_DIR, PALETTE_NAME)
watch(SETTINGS_DIR, SETTINGS_NAME)

return M
