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
    name = "floating-dialogs",
    match = { title = "^(Open|Save|Select|Choose)" },
    float = true,
    center = true,
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
