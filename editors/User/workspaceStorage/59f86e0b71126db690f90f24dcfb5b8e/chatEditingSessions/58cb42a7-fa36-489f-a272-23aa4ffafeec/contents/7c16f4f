-- Main Hyprland entry point. Feature groups live in separate modules.
dofile(os.getenv("HOME") .. "/.config/hypr/defaults.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/monitors.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/looknfeel.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/input.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/rules.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/bindings.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/autostart.lua")
-- ============================================================================
-- Hyprland configuration (Lua) — migrated from hyprland.conf
-- Requires Hyprland >= 0.55 (Lua config support).
-- This file is loaded INSTEAD of hyprland.conf when present (checked once
-- at compositor startup), so log out & back in after changing between them.
-- Reload manually any time with:  hyprctl reload
--
-- API reference: https://wiki.hypr.land/Configuring/
-- LSP stubs for autocompletion: /usr/share/hypr/stubs/
-- ============================================================================

-----------------------
---- MY PROGRAMS ------
-----------------------

-- Your favorite programs, referenced by the keybinds below.
local terminal = "ghostty"

-- The main modifier key ("Windows" key). Used to build all Super combos.
local mainMod = "SUPER"

------------------------
---- MONITORS ----------
------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

-- Catch-all: any unknown/unplugged monitor uses its preferred mode,
-- auto-positioned, scale 1.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

-- Built-in laptop display: fixed 2880x1800 @ 120Hz, fractional scaling 1.5x.
hl.monitor({
    output = "eDP-1",
    mode = "2880x1800@120",
    position = "auto",
    scale = 1.5,
})

---------------------------
---- LOOK AND FEEL --------
---------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in = 5, -- inner gaps between windows (px)
        gaps_out = 10, -- outer gaps around the screen edge (px)
        border_size = 2, -- window border thickness (px)

        layout = "dwindle", -- tiling layout engine
    },

    decoration = {
        rounding = 8, -- window corner rounding radius (px)
    },

    animations = {
        enabled = true,
    },
})

-- Custom bezier curve: fast start, smooth ease-out finish.
-- Points are control points of a cubic bezier: {x, y} pairs.
hl.curve("easeOut", {
    type = "bezier",
    points = { { 0.16, 1 }, { 0.3, 1 } },
})

-- Per-element animation settings.
-- speed is in "deciseconds per animation" style units (higher = slower),
-- bezier selects which curve to use ("default" = built-in curve).
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "easeOut" }) -- windows opening/moving
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "easeOut" }) -- windows closing
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "default" }) -- border color changes
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "default" }) -- opacity fades
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeOut" }) -- workspace switches

hl.config({
    cursor = {
        no_hardware_cursors = true, -- render cursors in software (fixes glitches on some GPUs)
    },

    misc = {
        disable_hyprland_logo = false, -- keep the Hyprland logo on startup
        disable_splash_rendering = false, -- keep the splash text on startup
    },

    debug = {
        disable_logs = false, -- keep writing logs to disk
        enable_stdout_logs = true, -- also mirror logs to stdout
    },
})

--------------------------
---- INPUT ---------------
--------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Variables/

hl.config({
    input = {
        kb_layout = "us", -- keyboard layout
        kb_options = "caps:swapescape", -- swap Caps Lock and Escape

        follow_mouse = 1, -- focus follows the mouse cursor
        scroll_factor = 1.0, -- wheel scroll speed multiplier
        sensitivity = 0.3, -- pointer sensitivity (-1.0 .. 1.0)
        natural_scroll = false,

        touchpad = {
            natural_scroll = true, -- invert scrolling direction on touchpad
            scroll_factor = 1.0,
        },
    },
})

--------------------------
---- AUTOSTART -----------
--------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Everything in this handler runs ONCE when Hyprland starts
-- (equivalent of exec-once; NOT re-run by hyprctl reload).
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper") -- wallpaper daemon (see hyprpaper.conf)
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/start-dock.sh") -- custom dock starter
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service 2>/dev/null || true") -- polkit auth agent
    hl.exec_cmd("nm-applet --indicator") -- network manager tray icon
    hl.exec_cmd("blueman-applet") -- bluetooth tray icon
end)

-----------------------------
---- WINDOW MANAGEMENT ------
-----------------------------

-- Toggle real fullscreen with Super + F.
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Move the focused window around the layout: Super + Shift + H/J/K/L.
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

-- Resize the focused window (repeats while held): Super + Ctrl + H/J/K/L.
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })

-- Toggle floating on the active window.
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))

-- Center the active window (useful when floating).
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.window.center())

--------------------------
---- KEYBINDINGS ---------
--------------------------

-- Session / window controls
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal)) -- open terminal
hl.bind(mainMod .. " + Q", hl.dsp.window.close()) -- close focused window
hl.bind(mainMod .. " + M", hl.dsp.exit()) -- quit Hyprland
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock")) -- lock screen

-- Focus movement with arrow keys
hl.bind(mainMod .. " + LEFT", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + DOWN", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + UP", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + RIGHT", hl.dsp.focus({ direction = "r" }))

-- Switch workspaces 1-9 with Super + [num];
-- move the focused window there with Super + Shift + [num].
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Hardware keys: brightness / volume.
-- `repeating` = keep firing while held (old bindel),
-- `locked`    = works even while the screen is locked (old bindl).
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 10%+"), { repeating = true, locked = true })
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { repeating = true, locked = true }
)
hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
    { repeating = true, locked = true }
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

-- Media player controls
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Screenshots (grim + slurp):
--   Print            -> select region, copy image to clipboard
--   Super + Print    -> select region, save timestamped file to ~/Pictures
--   Super + Shift+Print -> full screen, copy image to clipboard
hl.bind("PRINT", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind(
    mainMod .. " + PRINT",
    hl.dsp.exec_cmd("grim -g \"$(slurp)\" ~/Pictures/Screenshot_$(date +'%Y%m%d_%H%M%S').png")
)
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("grim - | wl-copy"))

-- ============================================================
-- APPLICATION / DESKTOP BINDINGS
-- ============================================================

-- Super + D -> show desktop (toggle special workspace named "desktop")
hl.bind(mainMod .. " + D", hl.dsp.workspace.toggle_special("desktop"))
-- Super + S -> launcher/drawer
local appLauncher = "wofi --show drun --allow-images --insensitive --hide-scroll --no-actions --term ghostty --prompt 'Launch' --width 720 --height 520 --lines 2 --columns 5 --conf ~/.config/wofi/config --style ~/.config/wofi/style.css"
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(appLauncher))
-- Super + E -> Nautilus file manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))
-- Super + C -> Chrome
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("google-chrome --new-window"))
-- Super + V -> VS Code
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("code"))
-- Super + Shift + A -> minimize current window
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/minimize-window.sh"))
-- Super + Shift + B -> restore oldest minimized window
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/restore-window.sh"))

-- Tapping Super alone (on release) also opens the drawer.
hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd(appLauncher), { release = true })

-- >>> jcode launch hotkeys (managed) >>>
-- jcode: home
hl.bind("SUPER + semicolon", hl.dsp.exec_cmd("/home/kairav/.jcode/hotkey/launch_jcode_0_cmd_semicolon.sh"))
-- jcode: last project
hl.bind("SUPER + apostrophe", hl.dsp.exec_cmd("/home/kairav/.jcode/hotkey/launch_jcode_1_cmd_quote.sh"))
-- jcode: self-dev
hl.bind("SUPER + SHIFT + apostrophe", hl.dsp.exec_cmd("/home/kairav/.jcode/hotkey/launch_jcode_2_cmd_shift_quote.sh"))
-- <<< jcode launch hotkeys (managed) <<<
