local home = os.getenv("HOME")

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.monitor({
    output = "eDP-1",
    mode = "2880x1800@120",
    position = "auto",
    scale = 1.5,
})

hl.monitor({
    output = "HDMI-A-1",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})
