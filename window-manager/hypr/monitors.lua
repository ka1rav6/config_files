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
    position = "2560x0",
    scale = 1.5,
})

hl.monitor({
    output = "HDMI-A-1",
    mode = "preferred",
    position = "0x0",
    scale = "auto",
})

for ws = 1, 10 do
    hl.workspace_rule({ workspace = tostring(ws), monitor = "HDMI-A-1" })
end
