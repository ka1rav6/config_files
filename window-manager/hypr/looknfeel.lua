hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        -- new
        -- Gradients are tables here, not the "c1 c2 45deg" string the .conf
        -- parser takes -- see HL.Gradient in /usr/share/hypr/stubs/hl.meta.lua.
        ["col.active_border"] = { colors = { "rgba(8ee3c1ee)", "rgba(f4c47baa)" }, angle = 45 },
        ["col.inactive_border"] = "rgba(1c212788)",
        -- old
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },

    decoration = {
        rounding = 8,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 0.94,
        -- Unfocused windows sit back a little. Deliberately gentle: this
        -- stacks on top of inactive_opacity above, and the two together at
        -- default strength (0.5) would black out half the screen.
        dim_inactive = true,
        dim_strength = 0.08,
        -- Special workspaces (the scratchpads) dim what is behind them, so an
        -- overlay reads as an overlay rather than as another tile.
        dim_special = 0.3,

        shadow = {
            enabled = true,
            -- Shadow cost scales with the area it is drawn over, i.e. with the
            -- square of the range -- 14 -> 10 is roughly half the work for a
            -- difference you have to look for.
            range = 10,
            render_power = 3,
            offset = { 0, 3 },
            color = "rgba(0d211bcc)",
        },

        -- Blur is the single most expensive thing the compositor does, so it is
        -- scoped down to the only windows that actually show it: Ghostty, which
        -- runs at background-opacity 0.65. See the blur rules in rules.lua --
        -- everything else carries no_blur, so nothing is blurred behind a
        -- window you cannot see through anyway.
        blur = {
            enabled = true,
            size = 4,
            -- Was 2. Passes multiply the cost more or less linearly, and at
            -- size 4 the second pass is not something you can pick out.
            passes = 1,
            -- Keeps blur cached for regions that are not changing -- most of
            -- the time, that is the whole bar and a still terminal.
            new_optimizations = true,
            -- Was true, which meant "blur behind this window even if it is
            -- fully opaque" -- i.e. render a blur nobody can see. With it off,
            -- blur only happens where something is actually translucent.
            ignore_opacity = false,
            -- Don't blur behind menus and tooltips; they are small, short-lived
            -- and land on top of an already-blurred surface half the time.
            popups = false,
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

        -- Swallowing: when a terminal launches a GUI app, the terminal hides
        -- itself until that app exits, instead of sitting there as a dead tile.
        --
        -- The regex is deliberately ONLY the default Ghostty class. The
        -- scratchpads run under com.scratchpad.ghostty and com.yazi.ghostty, so
        -- they are excluded automatically -- a scratchpad that swallowed itself
        -- would vanish off its special workspace and be very confusing to get
        -- back.
        enable_swallow = true,
        swallow_regex = "^com\\.mitchellh\\.ghostty$",

        -- Safety net for the lock screen. If hyprlock ever dies while holding
        -- the session lock -- a crash, an OOM kill, a bad config flag -- the
        -- session stays locked with no app drawing on it, and you get
        -- Hyprland's blue "lockscreen app died" fallback with no password
        -- prompt. Recovering that normally means switching to another TTY.
        --
        -- With this on, a freshly launched hyprlock can take over the orphaned
        -- lock, so `hyprlock` from a terminal is enough to get a prompt back.
        allow_session_lock_restore = true,
    },

    debug = {
        -- Was false. The log lives in /run (tmpfs, i.e. RAM) and was growing at
        -- roughly 3.3 MB every 3 hours -- about 26 MB a day of RAM plus the
        -- formatting cost, for output that is only ever read when something has
        -- already gone wrong. Flip back to false while debugging.
        disable_logs = true,
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
