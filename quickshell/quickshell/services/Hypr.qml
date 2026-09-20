pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// =============================================================================
// Hypr — the shell's one connection to the compositor.
// =============================================================================
// Quickshell.Hyprland already maintains a live model of monitors, workspaces
// and toplevels off the event socket, so almost nothing here needs to poll or
// shell out to hyprctl. This file exists to:
//
//   1. Give the rest of the shell ONE place to ask about compositor state,
//      rather than every component opening its own subscription (requirement:
//      do not duplicate system state).
//
//   2. Derive the few things the built-in model does not expose directly --
//      chiefly "is anything fullscreen", which gates game mode.
//
//   3. Keep every dispatch in one place, so the Lua-config quoting rules below
//      are written down once instead of being rediscovered per call site.
//
// -----------------------------------------------------------------------------
// IMPORTANT: DISPATCH SYNTAX UNDER A LUA CONFIG
//
//   This machine runs Hyprland's native Lua config (~/.config/hypr/hyprland.lua).
//   Under Lua, a dispatch request is EVALUATED AS LUA -- and that is true of
//   the request socket as well as the hyprctl binary. The classic string form
//   does not merely fail, it fails with a Lua parse error:
//
//       focuswindow address:0x123
//       -> [string "return hl.dispatch(focuswindow address:0x123"]:1: ')' expected
//
//   So every dispatch from here is written as a Lua call:
//
//       hl.dsp.focus({ window = "address:0x123" })
//       hl.dsp.focus({ workspace = 3 })
//       hl.dsp.workspace.toggle_special("todo")
//
//   An earlier version of this file asserted the opposite -- that the socket
//   took the classic form regardless of config language -- and every dock click
//   silently did nothing as a result. It does not.
//
//   This is the same trap that already bit ~/.config/waybar/config.jsonc (the
//   hyprtodo module) and ~/.config/hypr/hypridle.conf (after_sleep_cmd), both
//   of which carry their own notes about it.
//
//   Argument names are NOT free-form. hl.focus accepts exactly:
//       direction, monitor, window, urgent_or_last, last
//   Anything else is rejected at runtime with "unrecognized arguments", which
//   is at least a loud failure. Check /usr/share/hypr/stubs/hl.meta.lua.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    // -----------------------------------------------------------------
    // Direct pass-throughs
    //
    // Re-exported rather than having components import Quickshell.Hyprland
    // themselves, so that if the upstream API changes there is one file to fix
    // and components keep reading `Hypr.workspaces`.
    // -----------------------------------------------------------------

    readonly property var monitors: Hyprland.monitors
    readonly property var workspaces: Hyprland.workspaces
    readonly property var toplevels: Hyprland.toplevels

    readonly property var focusedMonitor: Hyprland.focusedMonitor
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var activeWindow: Hyprland.activeToplevel

    readonly property string activeTitle: root.activeWindow ? root.activeWindow.title : ""

    // True when the compositor is running the Lua config rather than
    // hyprland.conf. Surfaced in Settings > About; also a useful assertion,
    // because anything that generates compositor config has to know which.
    readonly property bool usingLua: Hyprland.usingLua

    // -----------------------------------------------------------------
    // Fullscreen tracking
    //
    // Drives Performance.gameMode. Hyprland emits a `fullscreen` event whose
    // data is "1" on entering and "0" on leaving, so this is fully
    // event-driven -- no timer, no hyprctl call.
    //
    // The refresh on workspace/monitor change exists because the event fires
    // for the window, not for the view: switching away from a workspace that
    // holds a fullscreen window leaves the flag stale otherwise. Re-deriving
    // from the workspace model is cheap and happens only on a switch.
    // -----------------------------------------------------------------

    property bool fullscreen: false

    // Push the result into Performance rather than having Performance import
    // Hyprland. Keeps the policy singleton free of compositor knowledge, so it
    // stays testable and so a future non-Hyprland target only replaces this file.
    onFullscreenChanged: Performance.fullscreenActive = root.fullscreen

    function refreshFullscreen() {
        // `hasfullscreen` comes from hyprctl's workspace object, which the
        // Quickshell model keeps in lastIpcObject. Checking only the focused
        // workspace is deliberate: a fullscreen window on an unfocused monitor
        // is not something to suppress animations for.
        const ws = Hyprland.focusedWorkspace;
        root.fullscreen = !!(ws && ws.lastIpcObject && ws.lastIpcObject.hasfullscreen);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "fullscreen":
                // data is "0" or "1"
                root.fullscreen = event.data === "1";
                break;
            case "workspace":
            case "focusedmon":
            case "closewindow":
                // The view changed under the flag; re-derive it.
                root.refreshFullscreen();
                break;
            }
        }

        function onFocusedWorkspaceChanged() {
            root.refreshFullscreen();
        }
    }

    // -----------------------------------------------------------------
    // Monitor helpers
    //
    // Multi-monitor correctness rule for the whole shell: never index
    // Quickshell.screens by number and never hardcode a name. This laptop is
    // eDP-1 plus an occasional HDMI-A-1, and ~/.config/hypr/monitors.lua
    // reassigns workspaces on hotplug -- a panel pinned to "screen 0" ends up
    // on the wrong output the first time something is unplugged.
    //
    // Components should use `Variants { model: Quickshell.screens }` to exist
    // once per output, and these helpers to reason about which is which.
    // -----------------------------------------------------------------

    // The Hyprland monitor object backing a Quickshell screen, or null.
    function monitorFor(screen) {
        return Hyprland.monitorFor(screen);
    }

    // The screen the user is currently looking at. Used by surfaces that
    // should appear once, on the active output -- the launcher, the Control
    // Center -- rather than once per monitor.
    readonly property var activeScreen: {
        const name = root.focusedMonitor ? root.focusedMonitor.name : "";
        for (const screen of Quickshell.screens) {
            if (screen.name === name)
                return screen;
        }
        // Before the first focus event arrives, or if the focused monitor has
        // just been unplugged, fall back to whatever exists rather than null --
        // a panel with no screen is a panel that never appears.
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function isActiveScreen(screen) {
        return !!screen && screen === root.activeScreen;
    }

    // -----------------------------------------------------------------
    // Desktop visibility
    //
    // Anything drawn on WlrLayer.Bottom -- the visualizer, the desktop widgets
    // -- sits above the wallpaper and BELOW every window. On a tiling
    // compositor that means it is invisible the moment the workspace has a
    // tiled window on it, which on this machine is most of the time.
    //
    // Rendering pixels nobody can see is the most obviously wasted work a
    // shell can do, and for the visualizer it is the difference between a few
    // percent of CPU and zero. So bottom-layer components ask here whether
    // their output is actually on show, and stop entirely when it is not.
    //
    // WHAT COUNTS AS COVERING
    //   A tiled window does. In the dwindle layout tiled windows fill the
    //   workspace, and they are opaque (inactive_opacity is 0.94 in
    //   ~/.config/hypr/looknfeel.lua, which is not see-through enough to make
    //   a visualizer readable through it).
    //
    //   A floating window does NOT. Floating windows leave the desktop visible
    //   around them, and the scratchpad terminals are translucent Ghostty
    //   (background-opacity 0.65) with blur, so the desktop genuinely does show
    //   through. Suppressing on those would take the visualizer away exactly
    //   when it is most visible.
    //
    //   A fullscreen window does, and is caught by the tiled test -- fullscreen
    //   windows report floating = false.
    //
    // COST
    //   Derived from the toplevel model Quickshell already maintains off the
    //   compositor event socket, so this is a binding re-evaluated on window
    //   open/close/move, not a poll. `hidden` excludes windows parked on a
    //   special workspace (the scratchpads) while they are toggled away.
    // -----------------------------------------------------------------

    // Monitor name -> is the wallpaper layer visible on it right now.
    readonly property var desktopVisibleByMonitor: {
        const result = {};

        for (const monitor of Hyprland.monitors.values) {
            // Start optimistic: an empty workspace shows the desktop.
            result[monitor.name] = true;
        }

        for (const toplevel of Hyprland.toplevels.values) {
            const ipc = toplevel.lastIpcObject;
            if (!ipc) continue;
            if (ipc.floating) continue;          // see the note above
            if (ipc.hidden) continue;            // parked on a special workspace

            const workspace = toplevel.workspace;
            const monitor = toplevel.monitor;
            if (!workspace || !monitor) continue;

            // Only windows on the workspace currently SHOWN on that monitor
            // cover anything. A tiled window two workspaces away does not.
            if (!monitor.activeWorkspace || monitor.activeWorkspace.id !== workspace.id)
                continue;

            result[monitor.name] = false;
        }

        return result;
    }

    // Is the wallpaper visible on this Quickshell screen?
    function desktopVisibleOn(screen) {
        if (!screen) return false;
        const value = root.desktopVisibleByMonitor[screen.name];
        // Unknown monitor: assume visible rather than silently blanking a
        // component on an output the model has not caught up with yet.
        return value === undefined ? true : value;
    }

    // True when at least one output is showing its wallpaper. Components that
    // exist once rather than per-monitor gate on this.
    readonly property bool anyDesktopVisible: {
        for (const name in root.desktopVisibleByMonitor) {
            if (root.desktopVisibleByMonitor[name]) return true;
        }
        return false;
    }

    // -----------------------------------------------------------------
    // Dispatch
    //
    // See the header note: these take classic string syntax because they go
    // over the request socket, not through hyprctl.
    // -----------------------------------------------------------------

    // Raw dispatch. `request` must be a Lua expression -- see the header.
    function dispatch(request) {
        Hyprland.dispatch(request);
    }

    function focusWorkspace(id) {
        // Numeric ids unquoted, names quoted -- hl.focus distinguishes them.
        const arg = typeof id === "number" ? id : JSON.stringify(id);
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + arg + " })");
    }

    function toggleSpecial(name) {
        Hyprland.dispatch("hl.dsp.workspace.toggle_special(" + JSON.stringify(name) + ")");
    }

    // Focus a window by address. This also switches to whatever workspace the
    // window is on, which is what makes it the right action for a dock click.
    // The address from a toplevel already carries its 0x prefix; the
    // "address:" prefix is what hl.focus expects around it.
    function focusWindow(address) {
        if (!address) return;
        Hyprland.dispatch("hl.dsp.focus({ window = " + JSON.stringify("address:" + address) + " })");
    }

    function closeWindow(address) {
        if (!address) return;
        Hyprland.dispatch("hl.dsp.window.close({ window = " + JSON.stringify("address:" + address) + " })");
    }

    // -----------------------------------------------------------------
    // Startup
    // -----------------------------------------------------------------

    Component.onCompleted: {
        // The event socket only reports changes from here on, so derive the
        // initial fullscreen state once rather than waiting for the first
        // window to toggle it.
        root.refreshFullscreen();
    }
}
