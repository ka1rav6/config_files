local home = os.getenv("HOME")

local function ensure_hyprtodo()
    hl.exec_cmd("pgrep -x hyprtodo >/dev/null 2>&1 && hyprctl dispatch movetoworkspacesilent special:todo,class:^(hyprtodo)$ || hyprctl dispatch exec '[workspace special:todo silent] hyprtodo'")
end

hl.on("config.reloaded", ensure_hyprtodo)

hl.on("hyprland.start", function()
    ensure_hyprtodo()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar &")
    hl.exec_cmd("swaync")
    hl.exec_cmd("mako")
    hl.exec_cmd("~/.local/bin/now-playing-notify")
    hl.exec_cmd("command -v hypridle >/dev/null 2>&1 && hypridle")
    hl.exec_cmd("command -v wlsunset >/dev/null 2>&1 && wlsunset -t 4000")
    hl.exec_cmd(
        "command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1 && wl-paste --type text --watch cliphist store"
    )
    hl.exec_cmd(
        "command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1 && wl-paste --type image --watch cliphist store"
    )
    hl.exec_cmd(home .. "/.config/hypr/scripts/start-dock.sh")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service 2>/dev/null || true")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
end)
