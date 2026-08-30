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
    no_focus = true,
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
