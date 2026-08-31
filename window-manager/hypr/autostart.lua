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

-- Spawn a window straight into a hidden special workspace, but only if one
-- isn't already there.
--
-- The old form shelled out to `hyprctl dispatch exec '[workspace ...] cmd'`.
-- Under the Lua config `hyprctl dispatch` evaluates Lua, so that string no
-- longer parses and the spawn silently did nothing.
local function ensure_in_special(class, workspace, command)
    if #hl.get_windows({ class = class }) > 0 then
        return
    end

    hl.dispatch(hl.dsp.exec_cmd(command, { workspace = "special:" .. workspace .. " silent" }))
end

local function ensure_hyprtodo()
    ensure_in_special("hyprtodo", "todo", "hyprtodo")
end

-- Scratchpad terminal, toggled with SUPER+ALT+T.
local function ensure_scratchpad()
    ensure_in_special("com.scratchpad.ghostty", "scratch", terminal .. " --class=com.scratchpad.ghostty")
end

hl.on("config.reloaded", ensure_hyprtodo)
hl.on("config.reloaded", ensure_scratchpad)

hl.on("hyprland.start", function()
    ensure_hyprtodo()
    ensure_scratchpad()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("pgrep -x waybar >/dev/null 2>&1 || waybar &")
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
