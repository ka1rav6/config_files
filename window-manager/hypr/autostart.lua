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

local function ensure_hyprtodo()
    hl.exec_cmd("pgrep -x hyprtodo >/dev/null 2>&1 || hyprctl dispatch exec '[workspace special:todo silent] hyprtodo'")
end

hl.on("config.reloaded", ensure_hyprtodo)

hl.on("hyprland.start", function()
    ensure_hyprtodo()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar &")
    hl.exec_cmd("mako")
    hl.exec_cmd("~/.local/bin/system-monitor-notify &")
    hl.exec_cmd("pgrep -f '[n]ow-playing-notify' >/dev/null 2>&1 || " .. home .. "/.local/bin/now-playing-notify &")
    hl.exec_cmd("command -v hypridle >/dev/null 2>&1 && hypridle")
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
