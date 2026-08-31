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

-- Three fingers horizontally slides between workspaces. The workspace tracks
-- the fingers directly, so these settings decide how the swipe feels; the
-- animation it lands on afterwards lives in looknfeel.lua.
hl.config({
    gestures = {
        -- Finger travel for a full workspace of movement. Higher than the
        -- 300 default so short thumb-twitches no longer skate a workspace by.
        workspace_swipe_distance = 350,
        -- Commit at 30% instead of the 50% default: past a third of the way
        -- across, release lands on the next workspace rather than snapping back.
        workspace_swipe_cancel_ratio = 0.3,
        -- A fast flick still switches even if it never covered that 30%.
        workspace_swipe_min_speed_to_force = 15,
        -- Ignore vertical drift once the swipe has picked a direction.
        workspace_swipe_direction_lock = true,
        -- Keep swiping through several workspaces without lifting the fingers.
        workspace_swipe_forever = true,
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})
