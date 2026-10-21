-- Scratchpads.
--
-- A "scratchpad" here is an app parked on its own hidden *special* workspace.
-- Special workspaces overlay the workspace you are on instead of replacing it,
-- so a scratchpad drops in over whatever you were doing and disappears again on
-- the same keypress -- it never takes a tile in the layout.
--
-- Everything about a scratchpad is declared exactly once, in `scratchpads.apps`
-- below. The three consumers each ask this module for the slice they need:
--
--   rules.lua     -> scratchpads.register_rules()      float / size / pin rules
--   bindings.lua  -> scratchpads.toggle("<id>")        the keybind action
--   autostart.lua -> scratchpads.ensure_prespawned()   spawn hidden at login
--
-- So adding a scratchpad is a single table entry -- nothing to edit in the
-- other three files, and no way for the class in a rule to drift out of sync
-- with the class in a lookup.
--
-- Loaded from hyprland.lua straight after defaults.lua, because the commands
-- below reference the globals that defaults.lua sets (`terminal`, `yazi`).

scratchpads = {}

-- ---------------------------------------------------------------------------
-- Window classes
-- ---------------------------------------------------------------------------
--
-- Two different APIs want the class, in two different forms:
--
--   hl.get_windows({ class = ... })  wants the *literal* app_id.
--   hl.window_rule({ match = ... })  matches its fields as *regexes*.
--
-- Declaring only the literal and generating the regex from it keeps the two
-- from ever disagreeing. Escape the regex metacharacters that really do turn up
-- in app ids (the dots in "com.yazi.ghostty" would otherwise match any char),
-- and anchor the result so a class is never matched as a substring of a longer
-- one.

local REGEX_METACHARACTERS = "[%^%$%(%)%.%[%]%*%+%?{}|\\]"

local function escape_regex(literal)
    -- `%0` is the whole match; the extra `%` escapes are Lua gsub syntax, not
    -- regex syntax.
    return (literal:gsub(REGEX_METACHARACTERS, "\\%0"))
end

--- Build one anchored regex that matches any of an app's possible classes.
--- e.g. { "crx_abc", "chrome-abc" } -> "^(crx_abc|chrome\-abc)$"
local function classes_regex(classes)
    local escaped = {}
    for index, class in ipairs(classes) do
        escaped[index] = escape_regex(class)
    end
    return "^(" .. table.concat(escaped, "|") .. ")$"
end

-- ---------------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------------
--
-- An array rather than a keyed table, so window rules are always registered in
-- the order written here (Lua does not promise an iteration order for string
-- keys). `scratchpads.by_id` below indexes it for lookups.
--
-- Fields
--   id         what bindings.lua passes to scratchpads.toggle()
--   workspace  special workspace name; becomes "special:<workspace>"
--   classes    every app_id the window may report. More than one entry is only
--              needed where the same app reports differently on Wayland vs
--              XWayland (see `music`).
--   command    the shell command that spawns it
--   float      true  -> float the window, so it overlays as a panel
--              false -> let it fill its special workspace normally
--   size       "WIDTH HEIGHT", pixels. The Lua rule API does NOT parse
--              percentages. Only meaningful alongside float = true.
--   prespawn   true -> autostart.lua starts it hidden at login, so the very
--              first toggle is instant rather than a cold start
--
scratchpads.apps = {
    -- SUPER + `  -- the scratchpad terminal.
    {
        id = "terminal",
        workspace = "scratch",
        classes = { "com.scratchpad.ghostty" },
        -- Its own class purely so the rules and lookups here can single it out
        -- without catching every other Ghostty window.
        command = terminal .. " --class=com.scratchpad.ghostty",
        float = true,
        size = "1200 800",
        prespawn = true,
    },

    -- SUPER + E  -- yazi as a scratchpad, same shape as the terminal above.
    -- SUPER + ALT + E is the *tiled* yazi instead; that one is a plain window
    -- with no special workspace, so it lives in defaults.lua as `fileBrowser`.
    {
        id = "files",
        workspace = "files",
        classes = { "com.yazi.ghostty" },
        command = terminal .. " --class=com.yazi.ghostty --title=yazi -e " .. yazi,
        float = true,
        size = "1400 850",
        prespawn = true,
    },

    -- SUPER + Y  -- the YouTube Music PWA.
    {
        id = "music",
        workspace = "music",
        -- Chrome apps report `chrome-<app-id>-<Profile>` natively on Wayland,
        -- but `crx_<app-id>` (the .desktop file's StartupWMClass) when they
        -- fall back to XWayland. Match both so the toggle cannot lose track of
        -- the window and spawn a duplicate.
        classes = {
            "chrome-cinhimbnkkaeohfgghhklpknlkffjgod-Profile_1",
            "crx_cinhimbnkkaeohfgghhklpknlkffjgod",
        },
        command = '/opt/google/chrome/google-chrome --profile-directory="Profile 1"'
            .. " --app-id=cinhimbnkkaeohfgghhklpknlkffjgod",
        float = true,
        size = "1300 850",
        -- Deliberately not pre-spawned: a Chrome process per login costs real
        -- memory, and the toggle below cold-starts it on first press anyway.
        -- Flip to true if you would rather trade the RAM for an instant first
        -- open.
        prespawn = false,
    },

    -- SUPER + O  -- WhatsApp Web, as a Chrome app. Same shape as `music`:
    -- a PWA that is wanted on top of whatever you are doing, not as a tile.
    {
        id = "whatsapp",
        workspace = "whatsapp",
        -- Same dual-class story as `music`: Chrome apps report
        -- `chrome-<app-id>-<Profile>` on Wayland and `crx_<app-id>` when they
        -- fall back to XWayland. Match both so the toggle cannot lose the
        -- window and spawn a second copy.
        classes = {
            "chrome-hnpfjngllnobngcgfapefoaidbinmjnm-Profile_1",
            "crx_hnpfjngllnobngcgfapefoaidbinmjnm",
        },
        command = '/opt/google/chrome/google-chrome --profile-directory="Profile 1"'
            .. " --app-id=hnpfjngllnobngcgfapefoaidbinmjnm",
        float = true,
        size = "1200 850",
        -- Not pre-spawned, for the same reason as `music`: a Chrome process
        -- per login is real memory, and the toggle cold-starts it on first
        -- press.
        prespawn = false,
    },

    -- SUPER + SHIFT + H  -- the todo list. Not floated: it gets its special
    -- workspace to itself and is happy filling it.
    {
        id = "todo",
        workspace = "todo",
        classes = { "hyprtodo" },
        command = "hyprtodo",
        -- NOT pre-spawned. Measured at 155 MB resident -- the second-largest
        -- process on this machine after the shell itself -- to save a cold
        -- start on a list that gets opened a few times a day. The same
        -- reasoning already applied to `music` and `whatsapp` below; this
        -- entry was simply the one that predated it.
        prespawn = false,
    },
}

--- id -> entry, so toggle() is a lookup rather than a scan.
scratchpads.by_id = {}
for _, app in ipairs(scratchpads.apps) do
    scratchpads.by_id[app.id] = app
end

-- ---------------------------------------------------------------------------
-- Internals
-- ---------------------------------------------------------------------------

--- The mark scratchpads.promote() puts on a window it has handed to the layout.
---
--- WHY A HYPRLAND WINDOW TAG AND NOT A LUA TABLE OF ADDRESSES
---   The mark has to outlive this file. `hyprctl reload` re-runs scratchpads.lua
---   against the same Lua state and rebuilds `scratchpads` from `{}` at the top,
---   so a set parked on the module -- or on a local -- would be thrown away on
---   every reload and every promoted window would quietly become adoptable
---   again. A tag lives on the window inside the compositor instead: it survives
---   reload, needs no bookkeeping, and disappears when the window closes.
---
--- (The same reload hazard is why the event subscription at the bottom of this
--- file is held in a global rather than on `scratchpads`.)
local PROMOTED_TAG = "scratchpad-promoted"

--- True if `window` was handed to the layout by scratchpads.promote().
local function is_promoted(window)
    -- Defensive about the type rather than trusting the field: this is called
    -- for every window of every class on every toggle, and a nil `tags` would
    -- throw inside ipairs and take the toggle -- not just the check -- with it.
    local tags = window.tags
    if type(tags) ~= "table" then
        return false
    end

    for _, tag in ipairs(tags) do
        if tag == PROMOTED_TAG then
            return true
        end
    end

    return false
end

--- Every live window belonging to this scratchpad, across all of its classes.
---
--- Promoted windows are deliberately NOT included, and that single exclusion is
--- what makes the rest of this file behave correctly around them. Every caller
--- is asking the same question -- "is this scratchpad's own window there?" --
--- and a promoted window is no longer an answer to it:
---
---   toggle()            must still spawn when the only window of the class is
---                       one you promoted, instead of flashing an empty
---                       workspace;
---   adopt_strays()      must not drag it back onto the special workspace and
---                       re-float it, which is precisely what it does to a
---                       window that merely wandered off;
---   ensure_prespawned() must not count it as the login instance.
local function windows_of(app)
    local found = {}
    for _, class in ipairs(app.classes) do
        for _, window in ipairs(hl.get_windows({ class = class })) do
            if not is_promoted(window) then
                found[#found + 1] = window
            end
        end
    end
    return found
end

--- Pull any window of this app that is not on its special workspace back onto
--- it, and hand it the float / size / centre treatment by hand.
---
--- Window rules only fire when a window is first *mapped*, so any window that
--- was already open before its scratchpad existed -- the YouTube Music PWA you
--- had running when this config landed, say -- keeps sitting wherever it was.
--- The toggle would then find a live window, skip the spawn, and flash an empty
--- special workspace at you. Adopting strays on toggle makes that self-healing,
--- and equally undoes it if you ever move a scratchpad out with SUPER+SHIFT+N.
local function adopt_strays(app)
    local target = "special:" .. app.workspace

    for _, window in ipairs(windows_of(app)) do
        if not (window.workspace and window.workspace.name == target) then
            -- silent: relocate the window without dragging focus after it.
            hl.dispatch(hl.dsp.window.move({ window = window, workspace = target, silent = true }))

            if app.float then
                hl.dispatch(hl.dsp.window.float({ window = window, action = "enable" }))

                -- `size` is the "WIDTH HEIGHT" string the window rule uses;
                -- the resize dispatcher wants two numbers.
                local width, height = tostring(app.size or ""):match("^(%d+)%s+(%d+)$")
                if width then
                    hl.dispatch(hl.dsp.window.resize({
                        window = window,
                        x = tonumber(width),
                        y = tonumber(height),
                    }))
                end

                hl.dispatch(hl.dsp.window.center({ window = window }))
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Spawn de-duplication
-- ---------------------------------------------------------------------------
--
-- A spawn is not instant -- ghostty takes a beat, a cold Chrome PWA takes
-- several seconds -- and until the window actually maps, windows_of() correctly
-- reports that the scratchpad has no window. So every keypress in that gap
-- spawns ANOTHER one, and you end up with three terminals stacked on
-- special:scratch and no way to tell which is which.
--
-- This was always latent (quit the scratchpad, then mash its key) but
-- scratchpads.promote() turns it from the odd case into the normal one:
-- promoting always leaves the app with no window of its own for as long as the
-- replacement takes to start, and the key you press next is the one that opens
-- it. Measured on ghostty: three windows from three toggles inside two seconds.
--
-- So remember which apps have a spawn in flight. The flag is cleared by the
-- window.open subscription at the bottom of this file, the moment the window
-- really maps -- exact, and no polling or guessing at start-up times.
--
-- A global, for the same reason as the subscription handle below: `hyprctl
-- reload` rebuilds `scratchpads` from `{}` at the top of this file, so a flag
-- parked on the module would be lost mid-spawn. `or {}` keeps the table a
-- reload inherited instead of resetting it.
_scratchpad_pending_spawns = _scratchpad_pending_spawns or {}

-- Escape hatch, NOT the mechanism. A spawn that never produces a window at all
-- -- a command that is not installed, an app that crashes on start -- would
-- leave its flag set forever and the scratchpad could never be respawned. A
-- flag this old is therefore treated as gone. Deliberately far longer than any
-- app here takes to start, because window.open is what clears it in every
-- normal case; this only has to beat "never".
local PENDING_SPAWN_TIMEOUT = 30

--- True while a spawn for this app is on its way and has not timed out.
local function spawn_pending(app)
    local started = _scratchpad_pending_spawns[app.id]
    if started == nil then
        return false
    end

    -- os.time() is only second-resolution. That is useless for measuring a
    -- start-up and entirely adequate for a 30 s sanity bound, which is all it
    -- is being asked to do.
    if os.time() - started > PENDING_SPAWN_TIMEOUT then
        _scratchpad_pending_spawns[app.id] = nil
        return false
    end

    return true
end

--- Spawn the app directly onto its hidden special workspace. `silent` keeps
--- focus where it is, so a login-time spawn never steals the screen.
local function spawn(app)
    _scratchpad_pending_spawns[app.id] = os.time()
    hl.dispatch(hl.dsp.exec_cmd(app.command, { workspace = "special:" .. app.workspace .. " silent" }))
end

--- The scratchpad currently in your way on the focused monitor, as
--- `app, monitor`, or nil when there is none.
---
--- Two ways a scratchpad can be the thing in your way, and both matter:
---
---   1. it owns the focused window  -- the normal case, because pressing a key
---      about a scratchpad means you were using it a moment ago;
---   2. it is merely *showing* on the focused monitor without being focused.
---
--- (2) is the load-bearing one for window placement: Hyprland puts a new window
--- on the active workspace, and a shown special workspace is the active one
--- whether or not it holds focus. Checking only (1) left the editor opening onto
--- the scratchpad again in that case.
---
--- The monitor comes back alongside the app because both callers need the REAL
--- workspace behind the scratchpad, and only the monitor knows which one that is.
local function active_scratchpad()
    local window = hl.get_active_window()
    if window and window.workspace then
        local app = scratchpads.by_workspace_name(window.workspace.name)
        if app then
            return app, window.monitor
        end
    end

    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.focused and monitor.active_special_workspace then
            local app = scratchpads.by_workspace_name(monitor.active_special_workspace.name)
            if app then
                return app, monitor
            end
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Keybind action: show the scratchpad, or hide it if it is already showing.
--- Returns a function, so it is used as `hl.bind(key, scratchpads.toggle("id"))`.
function scratchpads.toggle(id)
    local app = assert(scratchpads.by_id[id], "scratchpads.toggle: no scratchpad named " .. tostring(id))

    return function()
        -- Quitting the app (exiting the shell, `q` in yazi, closing the PWA
        -- window) destroys the window, and nothing respawns it until the next
        -- login -- so without this the toggle would just flash an empty
        -- workspace. Respawn on demand instead; the window rules registered
        -- below drop the new window straight back onto the right workspace.
        if #windows_of(app) > 0 then
            adopt_strays(app)
        elseif not spawn_pending(app) then
            spawn(app)
        end
        -- The third case -- no window, but a spawn already on its way -- does
        -- nothing on purpose. Toggling the still-empty workspace below is the
        -- right thing anyway: the window drops onto it the moment it maps.

        hl.dispatch(hl.dsp.workspace.toggle_special(app.workspace))
    end
end

--- The scratchpad owning a "special:<name>" workspace, or nil for anything else
--- (a real workspace, a special workspace we do not manage, or nil).
function scratchpads.by_workspace_name(name)
    if not name then
        return nil
    end

    for _, app in ipairs(scratchpads.apps) do
        if name == "special:" .. app.workspace then
            return app
        end
    end

    return nil
end

--- Hide whichever scratchpad currently owns the focused window.
---
--- Called from outside the compositor, by
--- ~/.config/hypr/scripts/open-file.py, which yazi's `o` bind runs:
---
---   hyprctl eval 'scratchpads.dismiss_active()'
---
--- Two things want this. The obvious one: once you have told yazi to open a
--- file, the file browser has done its job and should get out of the way, the
--- same as pressing its key again.
---
--- The load-bearing one: Hyprland places a newly mapped window on the focused
--- monitor's *active* workspace, and while a special workspace is showing that
--- IS the special workspace. So a terminal spawned from inside the scratchpad
--- opens hidden, tiled next to yazi, and disappears with it on the next toggle.
--- Dismissing first hands focus back to the real workspace, so the new window
--- maps where you are actually looking.
---
--- A no-op (returning false) when the focused window is not in a scratchpad at
--- all -- the tiled yazi on SUPER+ALT+E, say -- so callers can fire it blindly.
function scratchpads.dismiss_active()
    local app = active_scratchpad()
    if not app then
        return false
    end

    hl.dispatch(hl.dsp.workspace.toggle_special(app.workspace))
    return true
end

--- Keybind action (SUPER + ALT + T): hand the showing scratchpad's window to the
--- layout as an ordinary tile, and spawn a fresh scratchpad hidden in its place.
---
--- WHY THIS EXISTS
---   A scratchpad is for the thing you are about to stop doing. Sometimes it
---   turns out to be the thing you are now doing -- the quick `tail -f` in the
---   SUPER+` terminal becomes the build you watch for an hour -- and then an
---   overlay is exactly the wrong shape: you want it NEXT to the window you are
---   watching it for, not on top of it. Dragging it out of the special workspace
---   and tiling it by hand (SUPER+T) half-works and then costs you the
---   scratchpad, because adopt_strays() treats that window as a stray and the
---   next SUPER+` shows you it again rather than a clean terminal. This does
---   both halves: the window joins the layout, and the keybind you have the
---   muscle memory for still opens a scratchpad.
---
--- Returns false and touches nothing when no scratchpad is showing, so the bind
--- in bindings.lua can fall through to the plain "tile this" of windows.tile().
function scratchpads.promote()
    local app, monitor = active_scratchpad()
    if app == nil then
        return false
    end

    -- Where it is going: the real workspace behind the scratchpad, on the
    -- monitor the scratchpad is showing on. Bail rather than guess if that is
    -- not a real workspace -- parking the window somewhere you are not looking
    -- would read as the scratchpad having simply vanished.
    local destination = monitor and monitor.active_workspace
    if destination == nil or destination.special then
        return false
    end

    -- Which of its windows. The focused one when the scratchpad holds focus,
    -- which is the normal case; otherwise its first, because a scratchpad that
    -- is merely showing has exactly one window to show.
    local target
    local focused = hl.get_active_window()
    if focused and focused.workspace and focused.workspace.name == "special:" .. app.workspace then
        target = focused
    else
        target = windows_of(app)[1]
    end

    if target == nil then
        return false
    end

    -- Read this BEFORE the window starts moving, while the handle is certainly
    -- still describing the window we looked at.
    --
    -- It matters for the non-floating scratchpads (`todo`), which fill their
    -- special workspace and can be left fullscreen there: a fullscreen window
    -- keeps its fullscreen box after unfloating, so it would take the whole
    -- monitor instead of a tile.
    local was_fullscreen = target.fullscreen ~= nil and target.fullscreen ~= 0

    -- Mark it before it moves. From this dispatch on, windows_of() no longer
    -- returns it: adopt_strays() cannot reclaim it on the next toggle, and the
    -- replacement spawned below is seen as the scratchpad's only window.
    hl.dispatch(hl.dsp.window.tag({ window = target, tag = PROMOTED_TAG, action = "add" }))

    -- The same three-step hand-over as scratchpads.evict_stray() below, in the
    -- same order and for the same reason: move it out SILENTLY while the real
    -- workspace is still hidden, get the scratchpad out of the way, and only
    -- then take focus -- so focus lands on a workspace you can actually see.
    hl.dispatch(hl.dsp.window.move({ window = target, workspace = destination.id, silent = true }))
    hl.dispatch(hl.dsp.workspace.toggle_special(app.workspace))
    hl.dispatch(hl.dsp.focus({ window = target }))

    -- Untiling comes LAST, and with no window selector, because the fullscreen
    -- and float dispatchers act on the ACTIVE window on 0.56.2 -- see the note
    -- in windows.lua, verified against the same version. The focus() above is
    -- what makes "the active window" the right one, which is also why this
    -- cannot be done before the move.
    if was_fullscreen then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset" }))
    end
    hl.dispatch(hl.dsp.window.float({ action = "unset" }))

    -- The replacement, hidden on the workspace just vacated. The window rules
    -- from register_rules() put it on the right workspace, floated and sized,
    -- exactly as at login.
    --
    -- Spawned unconditionally, `prespawn` notwithstanding: `prespawn = false`
    -- means "do not pay for this at every login" (`music`, `whatsapp`, `todo`),
    -- which is a statement about logins, not about now. Pressing this key is you
    -- asking for the scratchpad back by hand.
    spawn(app)
    return true
end

--- Called once at compositor start (and on reload) by autostart.lua: bring up
--- every `prespawn` scratchpad that is not already running, hidden.
function scratchpads.ensure_prespawned()
    -- spawn_pending as well as the window count, because this runs on every
    -- `hyprctl reload` too, not only at login -- and a reload a second after
    -- logging in would otherwise spawn a second copy of every prespawned
    -- scratchpad, while the first ones were still starting.
    for _, app in ipairs(scratchpads.apps) do
        if app.prespawn and #windows_of(app) == 0 and not spawn_pending(app) then
            spawn(app)
        end
    end
end

--- Called by rules.lua: pin each scratchpad to its workspace, and float/size
--- the ones that asked for it. Keys are only set when the entry defines them,
--- so a non-floating scratchpad gets a bare workspace rule.
function scratchpads.register_rules()
    for _, app in ipairs(scratchpads.apps) do
        hl.window_rule({
            name = "scratchpad-" .. app.id,
            match = { class = classes_regex(app.classes) },
            workspace = "special:" .. app.workspace,
            float = app.float or nil,
            size = app.size,
            -- Centring only means anything for a floating window.
            center = app.float or nil,
        })
    end
end

-- ---------------------------------------------------------------------------
-- Stray windows opened from inside a scratchpad
-- ---------------------------------------------------------------------------
--
-- Hyprland maps a new window onto the focused monitor's *active* workspace, and
-- while a scratchpad is showing that IS the special workspace. So anything you
-- launch from the scratchpad terminal -- `ghostwriter`, a browser, an editor --
-- opens onto special:scratch: it tiles there, which on an otherwise-floating
-- special workspace means it covers the whole monitor, and it vanishes with the
-- scratchpad on the next toggle because it genuinely lives there.
--
-- scratchpads.dismiss_active() already solves this, but only where a caller
-- remembers to invoke it -- today just yazi's `o` bind. That cannot cover a
-- command you typed yourself, so catch it at the compositor instead: when a
-- window opens on a scratchpad's workspace and is not that scratchpad's own
-- window, it was never meant to be there.
--
-- Evicting it means three things, in order: move it out to the real workspace
-- behind the scratchpad, hide the scratchpad (you asked for the app, not the
-- terminal), and focus what you just launched.

--- True if `window` is one of `app`'s own windows rather than a stray.
---
--- initial_class as well as class because some toolkits set their final app_id
--- a beat after mapping, and a scratchpad misread as a stray would get evicted
--- out of its own workspace.
local function belongs_to(app, window)
    for _, class in ipairs(app.classes) do
        if window.class == class or window.initial_class == class then
            return true
        end
    end
    return false
end

--- Clear the in-flight spawn flag for whichever scratchpad just opened a window.
---
--- This is the half of the de-duplication above that makes it event-driven: the
--- flag is dropped because the window genuinely appeared, not because a timer
--- guessed that it should have by now.
---
--- Matches on class rather than on the workspace the window landed on, so it
--- still fires for a window that a rule or a race put somewhere unexpected --
--- the point is "this app has a window again", wherever it is.
local function clear_pending_spawn(window)
    if window == nil then
        return
    end

    for _, app in ipairs(scratchpads.apps) do
        if belongs_to(app, window) then
            _scratchpad_pending_spawns[app.id] = nil
            return
        end
    end
end

--- Move a window that opened on a scratchpad workspace out to the real one.
function scratchpads.evict_stray(window)
    if window == nil or window.workspace == nil then
        return
    end

    local app = scratchpads.by_workspace_name(window.workspace.name)
    if app == nil or belongs_to(app, window) then
        return
    end

    -- The real workspace behind the scratchpad, on the window's own monitor.
    local monitor = window.monitor
    local destination = monitor and monitor.active_workspace
    if destination == nil or destination.special then
        return
    end

    -- silent: place it without dragging focus onto a workspace that is still
    -- hidden behind the scratchpad. Focus is handed over below, once the
    -- scratchpad is out of the way.
    hl.dispatch(hl.dsp.window.move({ window = window, workspace = destination.id, silent = true }))
    hl.dispatch(hl.dsp.workspace.toggle_special(app.workspace))
    hl.dispatch(hl.dsp.focus({ window = window }))
end

-- `hyprctl reload` re-runs this file against the same Lua state, so drop the
-- previous subscription rather than stacking a second handler on every reload.
--
-- Held in a global of its own, NOT a field on `scratchpads`: the table is
-- rebuilt from scratch at the top of this file, so a handle parked on it would
-- be thrown away on reload and the old subscription would be left running,
-- unreachable and undismissable, forever. The global also keeps the
-- subscription rooted against garbage collection.
-- pcall: a subscription that was already removed by hand (debugging from
-- `hyprctl eval`, say) throws on a second remove, and an uncaught throw here
-- would abort the rest of this file and take the scratchpads with it.
if _scratchpad_stray_subscription then
    pcall(function()
        _scratchpad_stray_subscription:remove()
    end)
end

_scratchpad_stray_subscription = hl.on("window.open", function(window)
    -- Before evict_stray, because a stray eviction moves the window and this
    -- only cares that it exists -- and because a scratchpad's OWN window, which
    -- is the one being waited for, is exactly the case evict_stray returns early
    -- on.
    clear_pending_spawn(window)
    scratchpads.evict_stray(window)
end)
