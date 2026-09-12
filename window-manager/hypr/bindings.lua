local home = os.getenv("HOME")
local mod = mainMod
local tui = terminal .. " -e "

local function toggle_named_workspace(name, command)
    return function()
        local current = hl.get_active_workspace()
        local target = hl.get_workspace(name)

        if current.name == name then
            local previous = hl.get_last_workspace()
            if previous then
                hl.dispatch(hl.dsp.focus({ workspace = previous.name }))
            end
            return
        end

        if command and (not target or target.is_empty) then
            hl.dispatch(hl.dsp.exec_cmd(command, { workspace = "name:" .. name }))
        end

        hl.dispatch(hl.dsp.focus({ workspace = "name:" .. name }))
    end
end

-- Session and window controls.
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind(mod .. " + M", hl.dsp.exec_cmd(home .. "/.config/waybar/scripts/power-menu.sh"))
-- Lock lives on ESCAPE, not SHIFT+L. SUPER+L is focus-right, so the old bind
-- was one slipped finger away from locking the session mid-thought.
-- Caps Lock sends Escape here (caps:swapescape), so SUPER + CapsLock locks too.
hl.bind(mod .. " + ESCAPE", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
-- Maximize: fills the monitor but keeps gaps, borders and the bar visible.
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
-- Throw the focused window at the next monitor (wraps, so it round-trips).
hl.bind(mod .. " + SHIFT + M", hl.dsp.window.move({ monitor = "+1" }))
hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + C", hl.dsp.window.center())

-- Focus windows. hjkl covers all four directions; the arrows only cover up and
-- down, because LEFT and RIGHT now slide between workspaces (see below).
hl.bind(mod .. " + DOWN", hl.dsp.focus({ direction = "d" }))
hl.bind(mod .. " + UP", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))

-- Move windows on ALT so the cluster stops colliding with the lock bind and
-- the named-workspace toggles; left now has a bind at all.
hl.bind(mod .. " + ALT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + ALT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(mod .. " + ALT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + ALT + L", hl.dsp.window.move({ direction = "r" }))

-- Continuous keyboard resizing.
local function resize(x, y)
    return function()
        hl.dispatch(hl.dsp.window.resize({ x = x, y = y, relative = true }))
    end
end

hl.bind(mod .. " + CTRL + H", resize(-50, 0), { repeating = true })
hl.bind(mod .. " + CTRL + J", resize(0, 50), { repeating = true })
hl.bind(mod .. " + CTRL + K", resize(0, -50), { repeating = true })
hl.bind(mod .. " + CTRL + L", resize(50, 0), { repeating = true })
hl.bind(mod .. " + equal", resize(10, 0), { repeating = true })
hl.bind(mod .. " + minus", resize(-10, 0), { repeating = true })
hl.bind(mod .. " + SHIFT + equal", resize(0, 10), { repeating = true })
hl.bind(mod .. " + SHIFT + minus", resize(0, -10), { repeating = true })

-- Resize mode: tap SUPER+R once, then resize with bare hjkl / arrows until
-- ESCAPE or RETURN.
hl.define_submap("resize", function()
    hl.bind("H", resize(-50, 0), { repeating = true })
    hl.bind("J", resize(0, 50), { repeating = true })
    hl.bind("K", resize(0, -50), { repeating = true })
    hl.bind("L", resize(50, 0), { repeating = true })
    hl.bind("LEFT", resize(-50, 0), { repeating = true })
    hl.bind("DOWN", resize(0, 50), { repeating = true })
    hl.bind("UP", resize(0, -50), { repeating = true })
    hl.bind("RIGHT", resize(50, 0), { repeating = true })
    hl.bind("ESCAPE", hl.dsp.submap("reset"))
    hl.bind("RETURN", hl.dsp.submap("reset"))
end)

hl.bind(mod .. " + R", hl.dsp.submap("resize"))

-- Workspace count, switching, and moving.
for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind("SUPER + TAB", function()
    local previous = hl.get_last_workspace()
    if previous then
        hl.dispatch(hl.dsp.focus({ workspace = previous }))
    end
end)
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Keyboard equivalent of the 3-finger swipe: same workspaces, same slide.
-- Not marked repeating, so holding the arrow down cannot stack up a queue of
-- switches that outruns the animation.
hl.bind(mod .. " + LEFT", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + RIGHT", hl.dsp.focus({ workspace = "e+1" }))
-- And carry the focused window along with the slide.
hl.bind(mod .. " + SHIFT + LEFT", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mod .. " + SHIFT + RIGHT", hl.dsp.window.move({ workspace = "e+1" }))

-- Move and resize floating windows with the mouse.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Cycle windows without leaving the keyboard.
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())

-- Named application workspaces, behind a SUPER + W leader.
--
-- These used to sit on SUPER+SHIFT+{RETURN,N,T,G,R,D} -- six letters of prime
-- real estate for something pressed a handful of times a day. Tapping SUPER+W
-- now arms a one-shot submap; the next key picks the workspace and the submap
-- releases itself immediately, so it never swallows the keystroke after it.
--
-- (The resize submap on SUPER+R is deliberately the opposite: it *stays* armed,
-- because resizing is something you repeat.)
local named_workspaces = {
    { key = "T", name = "tmux", command = "ghostty --title=tmux -e tmux new -A -s default" },
    { key = "RETURN", name = "tmux", command = "ghostty --title=tmux -e tmux new -A -s default" },
    { key = "N", name = "nvim", command = tui .. "nvim" },
    { key = "M", name = "top", command = tui .. "btop --utf-force" },
    { key = "G", name = "chrome", command = "google-chrome --new-window" },
    { key = "B", name = "brave", command = "brave-browser --new-window" },
    { key = "C", name = "claude", command = "claude-desktop" },
    { key = "D", name = "debug" },
}

-- Wrap an action so it runs and then drops straight back out of the submap.
local function once(action)
    return function()
        action()
        hl.dispatch(hl.dsp.submap("reset"))
    end
end

hl.define_submap("workspaces", function()
    for _, entry in ipairs(named_workspaces) do
        hl.bind(entry.key, once(toggle_named_workspace(entry.name, entry.command)))
    end

    -- Ways out that do nothing else.
    hl.bind("ESCAPE", hl.dsp.submap("reset"))
    hl.bind("Q", hl.dsp.submap("reset"))

    -- Safety net. Without this, a key that means nothing here is passed
    -- straight through to the focused window while the submap stays armed --
    -- so a mistyped letter would land in your editor AND leave the next
    -- keystroke hijacked. catchall makes any other key a silent way out.
    hl.bind("catchall", hl.dsp.submap("reset"))
end)

hl.bind(mod .. " + W", hl.dsp.submap("workspaces"))

hl.bind(mod .. " + D", hl.dsp.workspace.toggle_special("desktop"))

-- Scratchpads: apps parked on a hidden special workspace that overlay whatever
-- you are on. Each entry -- its class, command, size and whether it is spawned
-- at login -- is declared in scratchpads.lua; all that is left here is the key.
--
-- SUPER + ` sits where SUPER + ALT + T used to, freeing up the ALT cluster and
-- putting the scratchpad on a key you can hit without leaving the home row.
hl.bind(mod .. " + grave", scratchpads.toggle("terminal"))
hl.bind(mod .. " + Y", scratchpads.toggle("music"))
hl.bind(mod .. " + SHIFT + H", scratchpads.toggle("todo"))

-- Display layout. X toggles duplicate/extended; CTRL+SHIFT+arrows move the
-- external monitor around the laptop panel (default: to its left).
local display = home .. "/.config/hypr/scripts/display-layout.sh "
hl.bind(mod .. " + SHIFT + X", hl.dsp.exec_cmd(display .. "toggle-mirror"))
hl.bind(mod .. " + CTRL + SHIFT + LEFT", hl.dsp.exec_cmd(display .. "place left"))
hl.bind(mod .. " + CTRL + SHIFT + RIGHT", hl.dsp.exec_cmd(display .. "place right"))
hl.bind(mod .. " + CTRL + SHIFT + UP", hl.dsp.exec_cmd(display .. "place up"))
hl.bind(mod .. " + CTRL + SHIFT + DOWN", hl.dsp.exec_cmd(display .. "place down"))

-- Panel recovery. If the screen is black after a resume but the session is
-- still alive, this re-enables the output -- it is the only thing that does
-- (see the note in hypridle.conf). Worth knowing by feel, since by definition
-- you cannot see the screen when you need it.
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- Applications and utilities.
hl.bind(mod .. " + S", hl.dsp.exec_cmd(launcher))

-- File browsing, three ways.
--
-- The plain SUPER + E is the scratchpad yazi: one long-lived instance on its
-- own special workspace, floating and centred, toggled in and out exactly like
-- the SUPER + ` terminal. It keeps whatever directory you left it in, and it
-- never disturbs the tiling.
hl.bind(mod .. " + E", scratchpads.toggle("files"))
-- ALT + E is the tiled yazi: a fresh, ordinary window that takes a tile, for
-- when you want a file manager *in* the layout rather than over it.
hl.bind(mod .. " + ALT + E", hl.dsp.exec_cmd(fileBrowser))
-- Nautilus keeps the SHIFT variant, for the times a GTK file chooser or a
-- thumbnail grid is genuinely the better tool.
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("google-chrome --new-window"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("code"))
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/minimize-window.sh"))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/restore-window.sh"))
hl.bind(mod .. " + ALT + SPACE", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/toggle-waybar.sh"))
hl.bind(mod .. " + CTRL + N", hl.dsp.exec_cmd("makoctl restore"))
hl.bind(mod .. " + N", hl.dsp.exec_cmd("ghostty -e ~/.local/bin/mako-fzf-history"))

-- Jcode launch hotkeys.
hl.bind("SUPER + semicolon", hl.dsp.exec_cmd(home .. "/.jcode/hotkey/launch_jcode_0_cmd_semicolon.sh"))
hl.bind("SUPER + apostrophe", hl.dsp.exec_cmd(home .. "/.jcode/hotkey/launch_jcode_1_cmd_quote.sh"))
hl.bind("SUPER + SHIFT + apostrophe", hl.dsp.exec_cmd(home .. "/.jcode/hotkey/launch_jcode_2_cmd_shift_quote.sh"))

-- Hardware, media, and screenshots.
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
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
-- Screenshots. screenshot.sh has supported `full` and `full-save` all along;
-- neither had a key until now.
--
--   plain   -> pick a region      SHIFT -> save to ~/Pictures/Screenshots
--   ALT     -> whole screen       (no modifier) -> copy to the clipboard
local screenshot = home .. "/.config/hypr/scripts/screenshot.sh "
hl.bind(mod .. " + P", hl.dsp.exec_cmd(screenshot .. "region"))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd(screenshot .. "region-save"))
hl.bind(mod .. " + ALT + P", hl.dsp.exec_cmd(screenshot .. "full"))
hl.bind(mod .. " + ALT + SHIFT + P", hl.dsp.exec_cmd(screenshot .. "full-save"))
-- Kept: the old muscle memory for "save a region".
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot .. "region-save"))

-- Eyedropper. hyprpicker was already installed but had never been bound;
-- -a copies straight to the clipboard, -r gives the raw hex with no "#".
hl.bind(mod .. " + I", hl.dsp.exec_cmd("hyprpicker -a"))

-- Window groups (tabs). Stack several windows into one tile and page through
-- them, instead of spending a whole workspace on windows you only glance at.
hl.bind(mod .. " + G", hl.dsp.group.toggle())
hl.bind(mod .. " + ALT + G", hl.dsp.group.lock({ action = "toggle" }))
hl.bind(mod .. " + bracketleft", hl.dsp.group.prev())
hl.bind(mod .. " + bracketright", hl.dsp.group.next())
