hl.window_rule({
    name = "floating-audio-controls",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "floating-network-editor",
    match = { class = "^nm-connection-editor$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "floating-blueman",
    match = { class = "^(Blueman-manager|blueman-manager)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "floating-swaync",
    match = { class = "^swaync-control-center$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "floating-calculator",
    match = { class = "^(org.gnome.Calculator|galculator|qalculate-gtk)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "skip-focus-applets",
    match = { class = "^(nm-applet|blueman-applet)$" },
    no_focus = true,
})

hl.window_rule({
    name = "floating-dialogs",
    match = { title = "^(Open|Save|Select|Choose)" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "scratchpad-terminal",
    match = { class = "^com\\.scratchpad\\.ghostty$" },
    workspace = "special:scratch",
    float = true,
    -- Percentages are not parsed by the Lua rule API; pixels are.
    size = "1200 800",
    center = true,
})

hl.window_rule({
    name = "floating-yazi",
    match = { class = "^com\\.yazi\\.ghostty$" },
    float = true,
    -- Percentages are not parsed by the Lua rule API; pixels are.
    size = "1400 850",
    center = true,
})

hl.window_rule({
    name = "hyprtodo-special-workspace",
    match = { class = "^hyprtodo$" },
    workspace = "special:todo",
})

-- Don't let hypridle lock the session while anything is fullscreen.
hl.window_rule({
    name = "no-idle-when-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

-- wlogout draws on the overlay layer. Blurring it and dimming what's behind
-- separates the menu from the desktop, so a keypress that powers the machine
-- off never reads as part of the window you were just working in.
--
-- The namespace is "gtk-layer-shell", not "wlogout" -- wlogout 1.1.1 never
-- sets one of its own, so it inherits gtk-layer-shell's default. Checked
-- against `hyprctl layers`; nwg-drawer registers under its own name, so this
-- does not catch the launcher.
hl.layer_rule({
    name = "wlogout-overlay",
    match = { namespace = "^gtk-layer-shell$" },
    blur = true,
    dim_around = true,
})
