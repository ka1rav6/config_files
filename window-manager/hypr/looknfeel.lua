hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },

    decoration = {
        rounding = 8,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 0.94,
        shadow = {
            enabled = true,
            range = 10,
            render_power = 3,
            offset = { 0, 2 },
            color = "rgba(0, 0, 0, 0.35)",
        },
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
            new_optimizations = true,
            ignore_opacity = true,
        },
    },

    -- workspace_wraparound: sliding off the last workspace animates as a
    -- short wrap to the first instead of a long rewind across every one.
    animations = { enabled = true, workspace_wraparound = true },

    dwindle = { preserve_split = true },

    master = { new_status = "master" },

    scrolling = { fullscreen_on_one_column = true },

    cursor = { no_hardware_cursors = false, default_monitor = "HDMI-A-1" },

    misc = {
        disable_hyprland_logo = false,
        disable_splash_rendering = false,
    },

    debug = {
        disable_logs = false,
        enable_stdout_logs = false,
    },
})

hl.curve("easeOut", {
    type = "bezier",
    points = { { 0.16, 1 }, { 0.3, 1 } },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
-- Ease-out for the workspace slide: covers most of the distance early, then
-- settles. Deliberately no overshoot -- overshooting a workspace slide pulls
-- the empty seam between workspaces on screen.
hl.curve("workspaceSlide", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 8, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1, bezier = "default", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 4, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "default", style = "fade" })
-- Workspace sliding, driven by the 3-finger swipe and by SUPER + LEFT/RIGHT.
--
-- workspacesIn and workspacesOut must stay identical. They used to run at
-- speed 1 and 2, so the incoming and outgoing halves of a switch travelled at
-- different rates and visibly came apart mid-slide.
--
-- "slidefade <percent>" is a travelling slide with a cross-fade layered on.
-- The percent is how far the workspaces travel: held under 100% the outgoing
-- workspace lags and dims behind the incoming one, and that parallax plus the
-- window shadows is what gives the switch a sense of depth. Lower it (70, 50)
-- for more of that; set it to 100% for a flat one-to-one pan.
local function slide_workspaces(leaf)
    hl.animation({
        leaf = leaf,
        enabled = true,
        speed = 3.5,
        bezier = "workspaceSlide",
        style = "slidefade 80%",
    })
end

slide_workspaces("workspaces")
slide_workspaces("workspacesIn")
slide_workspaces("workspacesOut")
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })
