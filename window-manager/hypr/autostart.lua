local home = os.getenv("HOME")

-- PATH for everything Hyprland spawns (waybar, applets, launchers).
-- GDM doesn't source ~/.profile/.zshenv before starting the session, and
-- Hyprland's env keyword does NOT expand $VARS, so list dirs explicitly.
hl.env(
    "PATH",
    home
        .. "/.cargo/bin:"
        .. home
        .. "/.local/bin:"
        .. "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
)

-- Toolkit hints. Without these, Electron apps (VS Code, Cursor, Claude,
-- Obsidian, Antigravity) fall back to XWayland and get upscaled from 1x onto
-- the 1.5x-scaled internal panel, which reads as blurry text.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("XCURSOR_THEME", "Yaru")
hl.env("XCURSOR_SIZE", "24")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- Pre-spawned scratchpads.
--
-- scratchpads.ensure_prespawned() walks the registry in scratchpads.lua and
-- brings up every entry marked `prespawn`, hidden on its own special workspace,
-- skipping any that is already running. Which apps those are is decided there,
-- not here.
--
-- Note for anyone editing this: the spawn deliberately goes through
-- hl.dsp.exec_cmd with a workspace rule rather than shelling out to
-- `hyprctl dispatch exec '[workspace ...] cmd'`. Under the Lua config
-- `hyprctl dispatch` evaluates Lua, so that older string form no longer parses
-- and the spawn silently did nothing.

-- `config.reloaded` also fires once while the config is parsed for the very
-- first time, well before the compositor has finished coming up, so acting on
-- it there spawned the pre-spawned scratchpads a second time at every login, on
-- top of the hyprland.start block below.
--
-- A plain "have we started yet" flag can't separate the two: `hyprctl reload`
-- re-executes this file from a fresh Lua state and drops the old
-- subscriptions, so the flag would read false on every reload and these would
-- never run again. Monitors do survive that - none exist during the first
-- parse, at least one does by the time any later reload runs - so gate on
-- those instead.
local function compositor_is_up()
    local ok, monitors = pcall(hl.get_monitors)
    return ok and #monitors > 0
end

local function on_reload(fn)
    return function()
        if compositor_is_up() then
            fn()
        end
    end
end

hl.on("config.reloaded", on_reload(scratchpads.ensure_prespawned))

hl.on("hyprland.start", function()
    scratchpads.ensure_prespawned()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("pgrep -x waybar >/dev/null 2>&1 || waybar &")
    hl.exec_cmd("mako")
    hl.exec_cmd("~/.local/bin/system-monitor-notify &")
    hl.exec_cmd("pgrep -f '[n]ow-playing-notify' >/dev/null 2>&1 || " .. home .. "/.local/bin/now-playing-notify &")
    hl.exec_cmd("command -v hypridle >/dev/null 2>&1 && hypridle")
    -- Drops the internal panel to 60 Hz on battery and restores 120 Hz on AC.
    -- Event-driven off udev, so it idles at zero cost. See the script.
    hl.exec_cmd("pgrep -f '[p]ower-refresh.sh watch' >/dev/null 2>&1 || " .. home .. "/.config/hypr/scripts/power-refresh.sh watch &")
    hl.exec_cmd("command -v wlsunset >/dev/null 2>&1 && wlsunset -t 4000")
    hl.exec_cmd(
        "command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1 && wl-paste --type text --watch "
            .. home
            .. "/.config/hypr/scripts/cliphist-store.sh"
    )
    hl.exec_cmd(
        "command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1 && wl-paste --type image --watch "
            .. home
            .. "/.config/hypr/scripts/cliphist-store.sh"
    )
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service 2>/dev/null || true")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
end)
