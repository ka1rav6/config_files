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
        -- Do NOT conjure workspace 11 when a swipe runs off the end of 10.
        -- Keys 1..9 and 0 cover exactly workspaces 1..10 (bindings.lua), so a
        -- swipe-born 11th is somewhere you can get to but never get back to,
        -- and it only vanishes once its last window is gone.
        workspace_swipe_create_new = false,
    },
})

-- ---------------------------------------------------------------------------
-- Touchpad gestures
-- ---------------------------------------------------------------------------
--
-- NO TAP GESTURES EXIST. Hyprland's gesture system reads libinput swipe and
-- pinch streams only (see dirForString in TrackpadGestures.cpp) -- there is no
-- direction for a tap, single or double, so "three finger double tap" cannot be
-- bound here at all. A three-finger tap is already a middle click, handled by
-- libinput below the compositor and not retargetable either. Mute therefore
-- lives on the three-finger pinch, the other quick three-finger gesture.
--
-- Hyprland starts looking for a gesture after FIVE pixels of finger travel and
-- then fires it on release, so a one-shot action bound with a plain `action`
-- function goes off on any stray three-finger wobble. The callback-table form
-- is used instead, purely so the distance can be checked here -- which is the
-- same reason workspace_swipe_distance above is 350 rather than the default.
local function on_swipe(action, threshold)
    local travel = 0
    return {
        start = function() travel = 0 end,
        update = function(e)
            local d = e and e.delta
            if d then travel = travel + math.abs(d.x or 0) + math.abs(d.y or 0) end
        end,
        finish = function(e)
            if e and e.cancelled then return end
            if travel < (threshold or 120) then return end
            action()
        end,
    }
end

local function exec(cmd)
    return function() hl.dispatch(hl.dsp.exec_cmd(cmd)) end
end

local scripts = os.getenv("HOME") .. "/.config/hypr/scripts/"

-- The scratchpad terminal gets a swipe each way instead of one toggle, so the
-- gesture never depends on remembering what is currently on screen.
-- scratchpads.lua only exposes a toggle -- and the respawn-if-it-died logic
-- lives inside it -- so each direction looks first and leaves the toggle alone
-- when the scratchpad is already where that direction wants it.
--
-- Only the FOCUSED monitor is inspected, because that is the only one
-- toggle_special acts on: checking every monitor would make an up-swipe a no-op
-- while the scratchpad sits on the other screen, where you cannot see it.
local function scratchpad(id, want_shown)
    local toggle = scratchpads.toggle(id)
    local special = "special:" .. scratchpads.by_id[id].workspace

    return function()
        local monitor = hl.get_active_monitor()
        local showing = monitor and monitor.active_special_workspace
        if (showing ~= nil and showing.name == special) ~= want_shown then
            toggle()
        end
    end
end

-- Three fingers horizontally slides between workspaces. The workspace tracks
-- the fingers directly, so the settings above decide how the swipe feels; the
-- animation it lands on afterwards lives in looknfeel.lua.
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-- Three up / down: pull the scratchpad terminal (SUPER + `) up onto the screen,
-- push it back down out of the way.
hl.gesture({
    fingers = 3,
    direction = "up",
    action = on_swipe(scratchpad("terminal", true)),
})
hl.gesture({
    fingers = 3,
    direction = "down",
    action = on_swipe(scratchpad("terminal", false)),
})

-- Three-finger pinch, either way: mute. Stands in for the double tap that
-- Hyprland cannot see. Pinch needs a 10% scale change to register, so it is
-- deliberate enough not to need the distance guard the swipes use.
hl.gesture({
    fingers = 3,
    direction = "pinch",
    action = exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
})

-- Four fingers. Three is where the muscle memory is, so four gets the things
-- done TO a window rather than the places you go.
--
--   down  -> stash the focused window away      (half of SUPER + SHIFT + A)
--   up    -> hand the last one back              (the other half)
--   left  -> drag this window a workspace left   (SUPER + SHIFT + LEFT)
--   right -> ... and right                       (SUPER + SHIFT + RIGHT)
--
-- The stash is a LIFO toggle on the keybind, which is wrong for a gesture: one
-- swipe would have to mean both halves and you would have to know which. The
-- script has carried explicit `stash` and `restore` subcommands since the
-- Quickshell minimize button needed them, and they are exactly the two halves,
-- scoped per workspace and no-ops when there is nothing to do.
--
-- Four-finger pinch is left free on purpose; nothing here is worth a gesture
-- that is awkward to perform on a laptop touchpad.
hl.gesture({
    fingers = 4,
    direction = "down",
    action = on_swipe(exec(scripts .. "toggle-minimize.sh stash")),
})
hl.gesture({
    fingers = 4,
    direction = "up",
    action = on_swipe(exec(scripts .. "toggle-minimize.sh restore")),
})
hl.gesture({
    fingers = 4,
    direction = "left",
    action = on_swipe(function() hl.dispatch(hl.dsp.window.move({ workspace = "e-1" })) end),
})
hl.gesture({
    fingers = 4,
    direction = "right",
    action = on_swipe(function() hl.dispatch(hl.dsp.window.move({ workspace = "e+1" })) end),
})
