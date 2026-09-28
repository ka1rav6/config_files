-- Window behaviour: turning a tiled window into a floating one with the mouse.
--
-- Loaded from hyprland.lua BEFORE bindings.lua, which is the only consumer.
--
-- ---------------------------------------------------------------------------
-- WHAT THIS ADDS, AND WHAT IT DELIBERATELY DOES NOT TAKE AWAY
--
--   SUPER + left-drag         tiled  -> pop out to floating and follow the
--                                       pointer   (NEW)
--                             float  -> move it    (unchanged)
--   SUPER + SHIFT + left-drag tiled  -> swap tiles (the plain Hyprland
--                                       behaviour this gesture used to have,
--                                       moved one modifier across rather than
--                                       removed)
--   SUPER + right-drag        resize            (untouched)
--   SUPER + SHIFT + SPACE     float toggle      (untouched)
--   SUPER + T                 back to tiling    (NEW)
--
-- Tiling itself is not touched. Windows still open tiled, dwindle still splits
-- the way it did, and nothing here runs unless a SUPER+click happens.
--
-- ---------------------------------------------------------------------------
-- WHY THE CONFIG VALUES ARE GLOBALS AND NOT A FILE READ
--
-- This runs from a MOUSE-PRESS handler. It has to decide "float or swap" and
-- hand the pointer to Hyprland's own drag in the same breath, so there is no
-- room in it for a process spawn -- `jq` on settings.json from here would put
-- ~20 ms of fork in front of every SUPER+click, which is exactly the kind of
-- latency a drag makes visible.
--
-- So the values live in a global table with the defaults below, and
-- ~/.config/quickshell/services/WindowPolicy.qml PUSHES the user's choices in
-- with `hyprctl eval` whenever they change in Settings (and again on
-- config.reloaded, because a reload rebuilds this Lua state from scratch and
-- would otherwise silently restore these defaults).
--
-- settings.json stays the single source of truth. These are the values used
-- when nothing has pushed yet -- which is also the Quickshell-is-not-running
-- case, and the gesture has to keep working there. The compositor must never
-- depend on the shell.
-- ---------------------------------------------------------------------------

WindowBehaviour = {
    -- Mirrors Settings.windows.dragToFloat.
    drag_to_float = true,
    -- Mirrors Settings.windows.floatScale. A CEILING as a share of the
    -- monitor's logical size, never an enlargement.
    float_scale = 0.55,
    -- Floor, in logical px. Below this a popped-out window is too small to be
    -- worth having floated. Not exposed in Settings: it is a sanity bound, not
    -- a preference.
    min_width = 420,
    min_height = 300,
}

windows = {}

-- Tell the shell that a window is about to start moving, so the control cluster
-- hides instead of rubber-banding a frame behind it.
--
-- WHY THIS IS FIRE-AND-FORGET
--   `quickshell ipc call` is a process spawn, and this is a mouse press. It is
--   launched detached with its output discarded and its exit status ignored, so
--   the drag below never waits on it and a shell that is not running costs
--   nothing but a failed exec. The shell's side self-clears after 8 s, so a
--   `resume` that never arrives cannot leave the cluster hidden.
local function notify_shell(fn)
    hl.exec_cmd("exec quickshell ipc call windowcontrols " .. fn .. " >/dev/null 2>&1")
end

--- The logical geometry of a monitor, as plain numbers.
---
--- HL.Monitor reports `width`/`height` in PHYSICAL pixels and `scale`
--- separately, while window `at`/`size` are in LOGICAL layout coordinates. Mixing
--- the two is the one arithmetic mistake in this file that would look like it
--- worked on an unscaled monitor and place windows off-screen on the 1.5x
--- internal panel.
local function monitor_box(monitor)
    local scale = monitor.scale
    if scale == nil or scale <= 0 then
        scale = 1
    end

    return {
        x = monitor.x,
        y = monitor.y,
        w = monitor.width / scale,
        h = monitor.height / scale,
    }
end

--- Read a Vec2-ish field, which the Lua API hands back as either a table with
--- x/y or an array. Written once here rather than guessed at each use site.
local function vec(value)
    if value == nil then
        return nil
    end
    if value.x ~= nil and value.y ~= nil then
        return value.x, value.y
    end
    return value[1], value[2]
end

local function clamp(value, low, high)
    if high < low then
        return low
    end
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

--- SUPER + left-drag.
---
--- Floating window, or the feature turned off -> hand straight to Hyprland's
--- own drag, which is byte-for-byte what this key did before.
---
--- Tiled window -> shrink it around the pointer, float it there, then hand it
--- to the same drag so the pointer keeps carrying it. The order matters:
--- Hyprland's drag grabs whatever is under the cursor at the moment it starts,
--- so the window has to be BOTH floating and still under the pointer before it
--- is called. That is the whole reason the new position is computed from the
--- cursor rather than simply centring the window.
function windows.drag()
    local drag = hl.dsp.window.drag()

    if not WindowBehaviour.drag_to_float then
        hl.dispatch(drag)
        return
    end

    local window = hl.get_active_window()
    if window == nil or window.floating then
        hl.dispatch(drag)
        return
    end

    -- Maximized or fullscreen: leave that state first, or the float lands
    -- underneath it and the window appears not to move at all.
    if window.fullscreen ~= nil and window.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset" }))
    end

    -- The monitor UNDER THE CURSOR, not the window's own. They are the same
    -- here (the press just focused this window), and asking about the cursor is
    -- what guarantees the clamping below keeps the window on the output the
    -- pointer is actually on -- which is what stops a pop-out on the external
    -- monitor from landing on the laptop panel.
    local monitor = hl.get_monitor_at_cursor() or window.monitor
    if monitor == nil then
        hl.dispatch(drag)
        return
    end

    local box = monitor_box(monitor)
    local cursor = hl.get_cursor_pos()
    local cx, cy = vec(cursor)
    local ox, oy = vec(window.at)
    local ow, oh = vec(window.size)

    if cx == nil or ox == nil or ow == nil or ow <= 0 or oh <= 0 then
        hl.dispatch(drag)
        return
    end

    -- Target size: a share of the monitor, never bigger than the window already
    -- is, never below the sanity floor, never bigger than the monitor.
    local scale = WindowBehaviour.float_scale or 0.55
    local tw = math.floor(math.min(ow, box.w * scale))
    local th = math.floor(math.min(oh, box.h * scale))
    tw = math.floor(clamp(tw, math.min(WindowBehaviour.min_width, box.w), box.w))
    th = math.floor(clamp(th, math.min(WindowBehaviour.min_height, box.h), box.h))

    -- Shrink AROUND THE CURSOR: keep the pointer over the same relative point
    -- in the window, so the window contracts under your finger instead of
    -- jumping out from under it. This is the part that makes the gesture feel
    -- like picking the window up rather than like a command that ran.
    local fx = (cx - ox) / ow
    local fy = (cy - oy) / oh
    local tx = math.floor(cx - fx * tw)
    local ty = math.floor(cy - fy * th)

    -- Keep it on this monitor. Clamped to the output box rather than to the
    -- usable area on purpose: a floating window is allowed under the bar, and
    -- refusing that would make a pop-out near the top edge jump downwards.
    tx = math.floor(clamp(tx, box.x, box.x + box.w - tw))
    ty = math.floor(clamp(ty, box.y, box.y + box.h - th))

    notify_shell("suspend")

    -- One ordered burst. float first (a tiled window ignores an exact resize),
    -- then size, then position, then the drag.
    --
    -- All four act on the ACTIVE window and take no window selector -- verified
    -- against 0.56.2, where hl.window.move answers "unrecognized arguments.
    -- Expected one of: direction, x+y(+relative), workspace, into_group,
    -- out_of_group". The active window is the one the press just focused, which
    -- is why this is correct here and would not be correct from a script.
    hl.dispatch(hl.dsp.window.float({ action = "set" }))
    hl.dispatch(hl.dsp.window.resize({ x = tw, y = th, relative = false }))
    hl.dispatch(hl.dsp.window.move({ x = tx, y = ty, relative = false }))
    hl.dispatch(drag)
end

--- Release half of the drag. Only tells the shell the interaction is over --
--- Hyprland ends its own drag on button release without being asked.
function windows.drag_release()
    notify_shell("resume")
end

--- The way back: put the focused window into the layout.
---
--- Deliberately `unset` rather than `toggle`. SUPER + SHIFT + SPACE is already
--- the toggle; a second key that does the same thing is not worth a keybind,
--- whereas an idempotent "tile this" is -- it means the key can be pressed
--- twice without undoing itself, which is what you want on the way out of a
--- pile of floating windows.
function windows.tile()
    local window = hl.get_active_window()
    if window == nil then
        return
    end

    if window.fullscreen ~= nil and window.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset" }))
    end

    if window.floating then
        hl.dispatch(hl.dsp.window.float({ action = "unset" }))
    end
end
