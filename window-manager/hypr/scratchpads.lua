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
        command = "/opt/google/chrome/google-chrome --profile-directory=\"Profile 1\""
            .. " --app-id=cinhimbnkkaeohfgghhklpknlkffjgod",
        float = true,
        size = "1300 850",
        -- Deliberately not pre-spawned: a Chrome process per login costs real
        -- memory, and the toggle below cold-starts it on first press anyway.
        -- Flip to true if you would rather trade the RAM for an instant first
        -- open.
        prespawn = false,
    },

    -- SUPER + SHIFT + H  -- the todo list. Not floated: it gets its special
    -- workspace to itself and is happy filling it.
    {
        id = "todo",
        workspace = "todo",
        classes = { "hyprtodo" },
        command = "hyprtodo",
        prespawn = true,
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

--- Every live window belonging to this scratchpad, across all of its classes.
local function windows_of(app)
    local found = {}
    for _, class in ipairs(app.classes) do
        for _, window in ipairs(hl.get_windows({ class = class })) do
            found[#found + 1] = window
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

--- Spawn the app directly onto its hidden special workspace. `silent` keeps
--- focus where it is, so a login-time spawn never steals the screen.
local function spawn(app)
    hl.dispatch(hl.dsp.exec_cmd(app.command, { workspace = "special:" .. app.workspace .. " silent" }))
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
        if #windows_of(app) == 0 then
            spawn(app)
        else
            adopt_strays(app)
        end

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
--- ~/.config/hypr/scripts/open-in-terminal.sh, which yazi's `o` bind runs:
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
    -- Two ways a scratchpad can be the thing in your way, and both matter:
    --
    --   1. it owns the focused window  -- the normal case, because pressing `o`
    --      means you were typing into yazi a moment ago;
    --   2. it is merely *showing* on the focused monitor without being focused.
    --
    -- (2) is the load-bearing one for window placement: Hyprland puts a new
    -- window on the active workspace, and a shown special workspace is the
    -- active one whether or not it holds focus. Checking only (1) left the
    -- editor opening onto the scratchpad again in that case.
    local target

    local window = hl.get_active_window()
    if window and window.workspace then
        target = window.workspace.name
    end

    if not scratchpads.by_workspace_name(target) then
        for _, monitor in ipairs(hl.get_monitors()) do
            if monitor.focused and monitor.active_special_workspace then
                target = monitor.active_special_workspace.name
                break
            end
        end
    end

    local app = scratchpads.by_workspace_name(target)
    if not app then
        return false
    end

    hl.dispatch(hl.dsp.workspace.toggle_special(app.workspace))
    return true
end

--- Called once at compositor start (and on reload) by autostart.lua: bring up
--- every `prespawn` scratchpad that is not already running, hidden.
function scratchpads.ensure_prespawned()
    for _, app in ipairs(scratchpads.apps) do
        if app.prespawn and #windows_of(app) == 0 then
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
