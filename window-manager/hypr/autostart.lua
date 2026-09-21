local home = os.getenv("HOME")

-- PATH for everything Hyprland spawns (waybar, applets, launchers).
-- GDM doesn't source ~/.profile/.zshenv before starting the session, and
-- Hyprland's env keyword does NOT expand $VARS, so list dirs explicitly.
hl.env(
    "PATH",
    home
        .. "/.cargo/bin:"
        .. home
        .. "/.local/bin:"
        .. "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
)

-- Toolkit hints. Without these, Electron apps (VS Code, Cursor, Claude,
-- Obsidian, Antigravity) fall back to XWayland and get upscaled from 1x onto
-- the 1.5x-scaled internal panel, which reads as blurry text.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("XCURSOR_THEME", "Yaru")
hl.env("XCURSOR_SIZE", "24")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- Pre-spawned scratchpads.
--
-- scratchpads.ensure_prespawned() walks the registry in scratchpads.lua and
-- brings up every entry marked `prespawn`, hidden on its own special workspace,
-- skipping any that is already running. Which apps those are is decided there,
-- not here.
--
-- Note for anyone editing this: the spawn deliberately goes through
-- hl.dsp.exec_cmd with a workspace rule rather than shelling out to
-- `hyprctl dispatch exec '[workspace ...] cmd'`. Under the Lua config
-- `hyprctl dispatch` evaluates Lua, so that older string form no longer parses
-- and the spawn silently did nothing.

-- `config.reloaded` also fires once while the config is parsed for the very
-- first time, well before the compositor has finished coming up, so acting on
-- it there spawned the pre-spawned scratchpads a second time at every login, on
-- top of the hyprland.start block below.
--
-- A plain "have we started yet" flag can't separate the two: `hyprctl reload`
-- re-executes this file from a fresh Lua state and drops the old
-- subscriptions, so the flag would read false on every reload and these would
-- never run again. Monitors do survive that - none exist during the first
-- parse, at least one does by the time any later reload runs - so gate on
-- those instead.
local function compositor_is_up()
    local ok, monitors = pcall(hl.get_monitors)
    return ok and #monitors > 0
end

local function on_reload(fn)
    return function()
        if compositor_is_up() then
            fn()
        end
    end
end

hl.on("config.reloaded", on_reload(scratchpads.ensure_prespawned))

-- ---------------------------------------------------------------------------
-- Recovery net for a crashed lock screen.
--
-- ext-session-lock keeps the session locked if the lock CLIENT dies. That is
-- correct -- a lock that fails open is not a lock -- but by default Hyprland
-- lets no replacement locker attach, so the only way back in is a TTY and
-- `hyprctl --instance 0 keyword misc:allow_session_lock_restore 1`. That
-- happened here once, for real. Setting it in advance means a replacement
-- locker (hyprlock, started automatically by ~/.local/bin/lock-session) can
-- take over a lock left behind by a dead one.
--
-- This does NOT weaken the lock. The session stays locked throughout and the
-- replacement locker still demands the password; it only removes the need for
-- a TTY to start that replacement.
--
-- It lives here rather than in looknfeel.lua's misc block so that file stays
-- untouched. hl.config merges, so this adds one key and leaves the rest of
-- misc exactly as looknfeel.lua set it -- verified below by checking that
-- enable_swallow survives.
--
-- NOTE: `hyprctl keyword ...` does NOT work under the Lua parser -- it answers
-- "keyword can't work with non-legacy parsers. Use eval." An earlier attempt
-- to set this from an exec_cmd was therefore a silent no-op.
-- ---------------------------------------------------------------------------
hl.config({ misc = { allow_session_lock_restore = true } })

-- Quickshell -- the interactive desktop layer.
--
-- Hyprland owns compositor behaviour; Quickshell owns presentation. It draws
-- the dock, the Control Center, Settings, the OSD, the desktop widgets and the
-- audio visualiser. Its config is ~/.config/quickshell/shell.qml.
--
-- WHY -n RATHER THAN A pgrep GUARD
--   `hyprctl reload` re-runs this file, so an unguarded launch would stack a
--   second shell on every reload -- the same problem the waybar line below
--   solves with pgrep. Quickshell has a purpose-built flag for it:
--
--     -n / --no-duplicate   exit immediately if this config is already running
--
--   That is checked by Quickshell against its own instance registry rather
--   than by pattern-matching a command line, so it cannot be defeated by the
--   wrapper script in ~/.local/bin/quickshell exec'ing the real binary under a
--   different path and argv. The pgrep form this replaced was matching
--   '[q]uickshell --config default', which stopped being the real argv the
--   moment the launch switched to the short -c form.
--
--   -d daemonizes, so the shell is not a child of the compositor's spawn shell
--   and survives it exiting.
--
-- IF QUICKSHELL IS NOT RUNNING
--   Nothing here breaks. Waybar, mako, the scratchpads, every keybind and the
--   compositor itself are independent of it. The keybinds that drive its UI
--   simply do nothing until it is back. Restart it with `just qs-restart`.
--
-- TO DISABLE IT ENTIRELY
--   Set QUICKSHELL_DISABLE=1 in the environment and reload. Useful for
--   bisecting a desktop problem: it takes the whole shell layer out of the
--   picture without editing this file.
local function start_quickshell()
    if os.getenv("QUICKSHELL_DISABLE") == "1" then
        return
    end

    hl.exec_cmd("command -v quickshell >/dev/null 2>&1 && quickshell -c default -n -d >/dev/null 2>&1")
end

-- Launch helper.
--
-- WHY `exec` AND NOT A BARE COMMAND
--   hl.exec_cmd hands its string to /bin/sh -c. Without `exec` the shell
--   forks the program and then SITS THERE as its parent for the whole
--   session -- 10 of those were resident at ~1.9 MB each (18.9 MB) purely to
--   wait on children they had nothing more to do with. `exec` replaces the
--   shell with the program, so there is one process instead of two.
--
--   Anything with a `&&` guard or a redirect still needs the shell to parse
--   it, so `exec` goes immediately before the program, not in front of the
--   test.
local function spawn(command)
    hl.exec_cmd("exec " .. command)
end

-- Launch `command` unless it is already running, matched by `pattern`.
--
-- THE BUG THIS EXISTS TO PREVENT -- READ BEFORE CHANGING IT
--   The obvious form is wrong and fails SILENTLY:
--
--     hl.exec_cmd("pgrep -f '[p]ower-refresh.sh watch' || .../power-refresh.sh watch &")
--
--   `pgrep -f` matches against the whole command line of every process --
--   INCLUDING the `sh -c` wrapper that is running this very line, whose argv
--   contains ".../power-refresh.sh watch" because that is the command it is
--   about to launch. So the guard matches itself, reports "already running",
--   and the `||` never fires. The program never starts, ever, and nothing
--   says so.
--
--   The `[p]` bracket trick does NOT help. It only stops `pgrep` matching its
--   own argv; it does nothing about the enclosing shell that carries the real
--   path.
--
--   Two daemons were dead this way for as long as these lines existed:
--   power-refresh.sh (so the panel never dropped to 60 Hz on battery) and
--   now-playing-notify.
--
--   The fix is `pgrep -x`, which matches the executable NAME only and so can
--   never see a shell's argv. Where the process name is not distinctive
--   enough for -x (an interpreted script runs as "bash" or "sh"), the script
--   carries its own lock instead and is launched unguarded -- see the callers.
--
--   `pgrep -x waybar` below was always correct, which is exactly why waybar
--   kept working while the other two did not.
local function spawn_once(name, command)
    hl.exec_cmd("pgrep -x " .. name .. " >/dev/null 2>&1 || exec " .. command)
end

hl.on("hyprland.start", function()
    scratchpads.ensure_prespawned()
    spawn("hyprpaper")
    spawn_once("waybar", "waybar")
    spawn("mako")
    -- Both of these hold their own single-instance lock (a mkdir lockdir in
    -- $XDG_RUNTIME_DIR), so they need no guard here -- which is just as well,
    -- because they run as "bash" and `pgrep -x` could not tell them apart.
    -- A second copy exits immediately on its own.
    spawn(home .. "/.local/bin/system-monitor-notify")
    spawn(home .. "/.local/bin/now-playing-notify")
    hl.exec_cmd("command -v hypridle >/dev/null 2>&1 && exec hypridle")
    -- Drops the internal panel to 60 Hz on battery and restores 120 Hz on AC.
    -- Event-driven off udev, so it idles at zero cost. See the script, which
    -- also holds its own lock.
    spawn(home .. "/.config/hypr/scripts/power-refresh.sh watch")
    -- NO wlsunset HERE, DELIBERATELY -- IT CANNOT WORK ON THIS MACHINE.
    --
    -- Colour temperature needs wlr-gamma-control, and aquamarine refuses it on
    -- the legacy DRM interface that defaults.lua pins us to with
    -- AQ_NO_ATOMIC=1. Every modeset logs:
    --
    --     ERR from aquamarine ]: No support for gamma on the legacy iface
    --
    -- So `wlsunset -t 4000` sat resident doing NOTHING -- a process, a wrapper
    -- shell and a wayland connection for an effect the compositor discards.
    -- (The flag was a no-op twice over: -t is the *low* temperature and 4000
    -- is already its default, and with no -l/-L or -S/-s there was no
    -- schedule to enter night mode on either.)
    --
    -- services/NightLight.qml now probes for gamma support and reports the
    -- feature unavailable instead of offering a toggle that changes nothing.
    -- Restore this line together with the AQ_NO_ATOMIC removal in defaults.lua.
    hl.exec_cmd(
        "command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1 && exec wl-paste --type text --watch "
            .. home
            .. "/.config/hypr/scripts/cliphist-store.sh"
    )
    hl.exec_cmd(
        "command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1 && exec wl-paste --type image --watch "
            .. home
            .. "/.config/hypr/scripts/cliphist-store.sh"
    )
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service 2>/dev/null || true")
    -- nm-applet is gone. Its only job here was a tray icon, and waybar no
    -- longer has a tray module -- the Wi-Fi UI is the Control Center now
    -- (SUPER + A, or the network reading on the bar). NetworkManager itself is
    -- a system service and is entirely unaffected; nm-connection-editor is
    -- still there on right-click for static IPs, VPNs and saved profiles.
    --
    -- blueman-applet is gone too, but for a subtler reason. Its visible job
    -- (a tray icon) also has nowhere to render, and the invisible one it was
    -- really here for -- selecting the A2DP card profile so headphones
    -- actually produce a sink -- is now done by the shell itself
    -- (~/.config/quickshell/services/Bluetooth.qml, ensureAudioProfile).
    --
    -- What it ALSO did is register the BlueZ pairing agent, and BlueZ will not
    -- pair a NEW device without one. Rather than keep ~97 MiB of Python
    -- resident year-round for something done a few times a year, the applet is
    -- now started on demand by ~/.local/bin/bt-pair -- behind the "Pair a new
    -- device" button on the Control Center's Bluetooth page -- and stopped
    -- again when the window closes.
    --
    -- bt-pair has to stop the systemd UNIT, not just the process: blueman-applet
    -- is a D-Bus-activated user service, so `pkill` alone leaves systemd's copy
    -- (plus blueman-tray, which pkill never matched at all) resident forever.
    -- That leak was measured at 97 MiB after a single pairing session.
    --
    -- Reconnecting an already-paired device needs no agent, so headphones,
    -- mice and keyboards all come back on their own exactly as before.
    start_quickshell()
end)
