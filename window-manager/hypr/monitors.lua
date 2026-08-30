local home = os.getenv("HOME")
local EXTERNAL = "HDMI-A-1"
local INTERNAL = "eDP-1"

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.monitor({
    output = INTERNAL,
    mode = "2880x1800@120",
    position = "auto-right",
    scale = 1.5,
})

hl.monitor({
    output = EXTERNAL,
    mode = "preferred",
    position = "0x0",
    scale = "auto",
})

-- Default docked layout; sync-workspaces.sh reassigns on monitor hotplug.
for ws = 1, 7 do
    hl.workspace_rule({ workspace = tostring(ws), monitor = EXTERNAL })
end

for ws = 8, 10 do
    hl.workspace_rule({ workspace = tostring(ws), monitor = INTERNAL })
end

local function sync_workspace_monitors()
    hl.exec_cmd(home .. "/.config/hypr/scripts/sync-workspaces.sh")
end

hl.on("hyprland.start", sync_workspace_monitors)
hl.on("monitor.added", sync_workspace_monitors)
hl.on("monitor.removed", sync_workspace_monitors)
