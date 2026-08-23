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
hl.bind(mod .. " + M", hl.dsp.exit())
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + C", hl.dsp.window.center())

-- Focus and move windows.
hl.bind(mod .. " + LEFT", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + DOWN", hl.dsp.focus({ direction = "d" }))
hl.bind(mod .. " + UP", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + RIGHT", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

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
hl.bind(mod .. " + H", hl.dsp.focus({ workspace = "-1" }))
hl.bind(mod .. " + L", hl.dsp.focus({ workspace = "+1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move and resize floating windows with the mouse.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Cycle windows without leaving the keyboard.
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())

-- Named application workspaces.
hl.bind(mod .. " + SHIFT + RETURN", toggle_named_workspace("tmux", "ghostty --title=tmux -e tmux new -A -s default"))
hl.bind(mod .. " + SHIFT + N", toggle_named_workspace("nvim", tui .. "nvim"))
hl.bind(mod .. " + SHIFT + T", toggle_named_workspace("top", tui .. "btop --utf-force"))
hl.bind(mod .. " + D", hl.dsp.workspace.toggle_special("desktop"))
hl.bind(mod .. " + SHIFT + D", toggle_named_workspace("debug"))

-- Applications and utilities.
hl.bind(mod .. " + S", hl.dsp.exec_cmd(launcher))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("google-chrome --new-window"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("code"))
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/minimize-window.sh"))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/restore-window.sh"))
hl.bind(mod .. " + SUPER_L", hl.dsp.exec_cmd(launcher), { release = true })
hl.bind(mod .. " + ALT + SPACE", hl.dsp.exec_cmd("waybar &"))

-- Jcode launch hotkeys.
hl.bind("SUPER + semicolon", hl.dsp.exec_cmd(home .. "/.jcode/hotkey/launch_jcode_0_cmd_semicolon.sh"))
hl.bind("SUPER + apostrophe", hl.dsp.exec_cmd(home .. "/.jcode/hotkey/launch_jcode_1_cmd_quote.sh"))
hl.bind("SUPER + SHIFT + apostrophe", hl.dsp.exec_cmd(home .. "/.jcode/hotkey/launch_jcode_2_cmd_shift_quote.sh"))

-- Hardware, media, and screenshots.
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 10%+"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true, locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("PRINT", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd("grim -g \"$(slurp)\" ~/Pictures/Screenshot_$(date +'%Y%m%d_%H%M%S').png"))
hl.bind(mod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("grim - | wl-copy"))
