hl.config({
    input = {
        kb_layout = "us",
        kb_options = "caps:swapescape",
        repeat_rate = 40,
        repeat_delay = 250,
        follow_mouse = 1,
        scroll_factor = 1.0,
        sensitivity = 0.3,
        natural_scroll = false,
        touchpad = {
            natural_scroll = true,
            scroll_factor = 1.0,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})
