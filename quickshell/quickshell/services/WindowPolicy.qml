pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

// =============================================================================
// WindowPolicy — everything the shell knows about the window under the cursor.
// =============================================================================
// Two jobs that belong together because they share one question ("which window,
// and where is it?"), and would otherwise be answered twice:
//
//   1. THE GEOMETRY OF THE ACTIVE WINDOW, kept current enough to hang a control
//      cluster off its top-right corner. modules/windowcontrols reads this.
//
//   2. PUSHING THE TWO MOUSE-POLICY VALUES INTO THE COMPOSITOR, so the
//      SUPER+SHIFT+drag keybind in ~/.config/hypr/windows.lua honours what is
//      in Settings without having to read a JSON file from a mouse-press
//      handler.
//
// -----------------------------------------------------------------------------
// WHY THERE IS A POLL HERE AT ALL, IN A SHELL THAT AVOIDS THEM
//
// Hyprland has no window-geometry event. Checked against 0.56.2: the event
// socket carries openwindow, closewindow, movewindow (workspace moves ONLY),
// windowtitle, changefloatingmode, fullscreen and pin -- and nothing that fires
// while a window is being dragged or resized. There is no `resizewindow`.
//
// So a surface that has to sit on a window's corner cannot be purely
// event-driven. The options were: poll always (rejected -- it would cost
// something every second of the day for a feature that is idle most of it), or
// poll only while the answer can actually be changing. This does the second:
//
//   * TILED and visible      -> events only, plus one 1 s safety tick. A tiled
//                               window moves when the layout changes, and every
//                               layout change comes from an event. The tick is
//                               for the two things that do not: keyboard resize
//                               (SUPER+CTRL+hjkl) and SUPER+R resize mode.
//   * FLOATING and visible   -> 8 Hz. This is the case that matters: a floating
//                               window is the one that moves continuously under
//                               the pointer, and SUPER+SHIFT+drag makes a tiled
//                               window floating before it moves it, so that drag
//                               lands here within one frame of starting.
//   * cluster not visible    -> nothing at all. No timer, no socket traffic.
//     (disabled, fullscreen,
//      scratchpad, excluded)
//
// The refresh is Hyprland.refreshToplevels(), i.e. one request-socket roundtrip
// -- NOT a `hyprctl` process spawn. Measured cost of the 8 Hz case on this
// machine is below the noise floor of `top`; the 1 s case is not measurable.
//
// The honest residue, which no amount of cleverness fixes: a window moved by
// its OWN client-side titlebar (a GTK headerbar drag in Nautilus or Chrome)
// emits nothing and is not floating-by-Hyprland's-reckoning until it is, so the
// cluster follows it on the next tick rather than in lockstep. Documented in
// the Settings page too, so it reads as a known edge rather than a bug.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    // ---------------------------------------------------------------------
    // The active window, as a plain record
    //
    // Quickshell's toplevel model is the source, but `lastIpcObject` is a raw
    // hyprctl client object and every consumer would otherwise repeat the same
    // null-checking. This flattens it to one object (or null) with the fields
    // the controls actually need.
    //
    // See the long note on `toplevels` in services/Hypr.qml for why
    // lastIpcObject can be empty: the event socket never announces windows that
    // were already open, so this is undefined until something refreshes the
    // model. Hypr.qml does that at startup and on every relevant event.
    // ---------------------------------------------------------------------

    // The focused toplevel.
    //
    // WHY THERE IS A FALLBACK. Quickshell sets Hyprland.activeToplevel from the
    // `activewindow` EVENT and from nothing else. The event socket only reports
    // changes, so a shell that starts while a window is already focused is never
    // told about it -- activeToplevel stays null until the user focuses something
    // different. Measured: after `just qs-restart` the cluster never appeared at
    // all, and polling `windowcontrols status` for seven seconds showed "no
    // active window" the whole way. It was not a startup race that settles; it
    // does not settle.
    //
    // This is the same class of gap services/Hypr.qml documents at length for
    // the toplevel MODEL (windows open before the shell are never announced), and
    // it has the same shape of fix: derive the answer from a refresh instead of
    // waiting for an event that will not come.
    //
    // `focusHistoryID` is hyprctl's own answer to "which window is focused" -- 0
    // is the most recently focused, 1 the one before it. It arrives with every
    // toplevel refresh, so the fallback costs no extra query and no process.
    //
    // The event path stays PREFERRED, because it is immediate: focus moving
    // between two windows updates activeToplevel in the same frame, whereas
    // focusHistoryID is only as fresh as the last refresh.
    readonly property var activeToplevel: {
        if (Hypr.activeWindow) return Hypr.activeWindow;

        for (const toplevel of Hypr.toplevels.values) {
            const ipc = toplevel.lastIpcObject;
            if (ipc && ipc.focusHistoryID === 0) return toplevel;
        }
        return null;
    }

    readonly property var active: {
        const toplevel = root.activeToplevel;
        if (!toplevel) return null;

        const ipc = toplevel.lastIpcObject;
        if (!ipc || !ipc.at || !ipc.size) return null;

        return {
            address: ipc.address || "",
            x: ipc.at[0],
            y: ipc.at[1],
            width: ipc.size[0],
            height: ipc.size[1],
            monitor: ipc.monitor,                  // Hyprland monitor ID, not a name
            workspace: ipc.workspace ? ipc.workspace.name : "",
            floating: !!ipc.floating,
            hidden: !!ipc.hidden,
            mapped: ipc.mapped !== false,
            // 0 = neither, 1 = maximized, 2 = fullscreen. The controls treat
            // these very differently: maximized keeps its cluster (and turns the
            // green dot into "restore" -- see `zoomAction`), fullscreen loses
            // it, because a fullscreen window is the one case where an overlay
            // on top of the content is unambiguously wrong.
            //
            // INDEPENDENT OF `floating` above. A window can be floating AND
            // maximized at the same time; services/Hypr.qml has a note on the
            // bug that assuming otherwise caused.
            fullscreen: ipc.fullscreen || 0,
            cls: ipc.class || ""
        };
    }

    // ---------------------------------------------------------------------
    // Should the cluster be on screen at all?
    //
    // Kept here rather than in the view so that `quickshell ipc call
    // windowcontrols status` can explain a missing cluster in one line -- which
    // is the difference between a feature you can debug and one you cannot.
    // ---------------------------------------------------------------------

    readonly property string suppressedBecause: {
        if (!Settings.windows.controls) return "disabled in Settings > Windows";
        if (root.interacting) return "an interaction is in flight";
        if (Shell.anyOpen) return "a shell panel is open (" + Shell.openPanels.join(", ") + ")";

        const win = root.active;
        if (!win) return "no active window";
        if (!win.mapped) return "active window is not mapped";
        if (win.hidden) return "active window is hidden";
        // Scratchpads and anything else parked on a special workspace. They are
        // summoned overlays with their own toggle keys, not windows you manage.
        if (win.workspace.indexOf("special:") === 0) return "active window is on a special workspace";
        if (win.fullscreen === 2) return "active window is fullscreen";
        if (win.floating && !Settings.windows.controlsOnFloating) return "floating windows are excluded";
        if (root.excluded(win.cls)) return "class '" + win.cls + "' is excluded";
        // A window narrower than the cluster plus two insets has nowhere to put
        // it that is not simply on top of the whole window.
        if (win.width < root.clusterWidth + Settings.windows.controlsInset * 3) return "active window is too narrow";
        return "";
    }

    readonly property bool visible: root.suppressedBecause === ""

    function excluded(cls) {
        if (!cls) return false;
        const list = Settings.windows.controlsExclude || [];
        for (const pattern of list) {
            if (pattern !== "" && cls.indexOf(pattern) !== -1) return true;
        }
        return false;
    }

    // Three dots plus the gaps between them. The view derives its width from
    // this so the two can never disagree about where the right edge is.
    readonly property int dotSize: Settings.windows.controlsSize
    readonly property int dotGap: Math.max(4, Math.round(root.dotSize * 0.55))
    readonly property int clusterWidth: root.dotSize * 3 + root.dotGap * 2

    // ---------------------------------------------------------------------
    // Interaction suspension
    //
    // Set while something is deliberately moving the window and the cluster
    // would only rubber-band behind it. Driven over IPC from the SUPER+drag
    // binds, which are the one interaction the compositor tells us about,
    // because they are OUR binds -- see ~/.config/hypr/bindings.lua.
    //
    // Self-clearing: a `release` bind that never arrives (the key released over
    // a different surface, the shell restarted mid-drag) must not leave the
    // cluster hidden forever.
    // ---------------------------------------------------------------------

    property bool interacting: false

    function beginInteraction() {
        root.interacting = true;
        interactionGuard.restart();
    }

    function endInteraction() {
        root.interacting = false;
        interactionGuard.stop();
        // The window has just stopped moving somewhere new and no event says
        // so. Ask once, immediately, rather than waiting for the next tick.
        Hypr.refreshToplevels();
    }

    Timer {
        id: interactionGuard

        interval: 8000
        onTriggered: {
            console.warn("[windowpolicy] interaction never ended, clearing");
            root.interacting = false;
        }
    }

    // ---------------------------------------------------------------------
    // Tracking
    // ---------------------------------------------------------------------

    // Only ever true when the cluster is on screen, so a disabled or hidden
    // feature costs exactly nothing. See the header for the reasoning.
    readonly property bool tracking: root.visible || root.interacting

    readonly property bool trackingFast: root.tracking
        && !!root.active
        && (root.active.floating || root.interacting)

    Timer {
        id: follow

        running: root.tracking
        repeat: true
        // 125 ms follows a drag closely enough that the cluster reads as
        // attached; 1000 ms is a safety net for the handful of geometry changes
        // Hyprland reports through no event at all.
        interval: root.trackingFast ? 125 : 1000
        triggeredOnStart: true
        onTriggered: Hypr.refreshToplevels()
    }

    // ---------------------------------------------------------------------
    // Actions
    //
    // Every one of these focuses the window by address first. That is not
    // superstition: hl.window.move, hl.window.resize and hl.window.fullscreen
    // act on the ACTIVE window and take no window selector (verified against
    // 0.56.2 -- hl.window.move answers "unrecognized arguments. Expected one
    // of: direction, x+y(+relative), workspace, into_group, out_of_group").
    // The cluster only ever appears on the active window, so the focus is
    // normally a no-op -- but "normally" is not the same as "always", and the
    // failure mode without it is maximizing the wrong window.
    // ---------------------------------------------------------------------

    function close() {
        const win = root.active;
        if (!win || !win.address) return;
        Hypr.closeWindow(win.address);
    }

    // The green button: one step back towards normal, or maximize if already
    // there. Hyprland's "maximized" mode keeps gaps, borders and the bar -- it
    // is the macOS green button, not the F11 one. SUPER + SHIFT + F is the
    // keyboard equivalent of the maximize step, SUPER + T of the tile step.
    //
    //   maximized           -> un-maximize, back to the size it had
    //   floating, not max'd -> back INTO THE LAYOUT (tiled)
    //   tiled, not max'd    -> maximize
    //
    // WHY IT UNFLOATS INSTEAD OF BEING A PURE MAXIMIZE TOGGLE
    //   On this desktop TILED IS NORMAL -- every window opens tiled and the
    //   layout is the resting state. A pure maximize toggle has no way back to
    //   it, so a window popped out by SUPER + SHIFT + drag could only be put
    //   back from the keyboard, and the one button that looks like "restore this
    //   window" restored it to a floating rectangle instead. Pressed on an
    //   already-small floating window it then appeared to do nothing at all,
    //   because un-maximizing something that is not maximized is a no-op.
    //
    //   So the button walks the window back one state per press, and is never a
    //   no-op: whatever it does, something visibly changes.
    //
    // WHY MAXIMIZED IS HANDLED FIRST AND SEPARATELY
    //   Unfloating a MAXIMIZED window leaves Hyprland holding a maximized tile,
    //   which is the same ordering hazard ~/.config/hypr/windows.lua documents
    //   on the way INTO a float ("leave that state first, or the float lands
    //   underneath it"). Taking one step per press means the two never combine.
    readonly property string zoomAction: {
        const win = root.active;
        if (!win) return "";
        // Non-zero covers maximized (1); fullscreen (2) never reaches the
        // button, because `suppressedBecause` hides the cluster on it.
        if (win.fullscreen !== 0) return "restore";
        return win.floating ? "tile" : "maximize";
    }

    function toggleMaximize() {
        const win = root.active;
        if (!win || !win.address) return;
        Hypr.dispatch("hl.dsp.focus({ window = " + JSON.stringify("address:" + win.address) + " })");

        switch (root.zoomAction) {
        case "restore":
            Hypr.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" })');
            break;
        case "tile":
            Hypr.dispatch('hl.dsp.window.float({ action = "unset" })');
            break;
        case "maximize":
            Hypr.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "set" })');
            break;
        default:
            return;
        }

        // `set`/`unset` rather than `toggle` on purpose: the branch already
        // knows which way it is going, and a toggle would fight the state read
        // above if it went stale between the read and the dispatch.
        //
        // None of the three emit a geometry event -- changefloatingmode fires
        // for the tile step but carries no size -- so ask once instead of
        // waiting up to a second for the follow timer.
        Hypr.refreshToplevels();
    }

    // Minimize, i.e. stash on the special:minimized workspace.
    //
    // This deliberately shells out to the EXISTING
    // ~/.config/hypr/scripts/toggle-minimize.sh rather than reimplementing it.
    // That script already owns the per-workspace stash state file that
    // SUPER+SHIFT+A restores from, and a second implementation writing the same
    // file is how the two would drift. `stash` is the subcommand that forces
    // the hide branch -- the bare script is a toggle, and a minimize button
    // that sometimes un-minimizes something else is not a minimize button.
    function minimize() {
        const win = root.active;
        if (!win || !win.address) return;
        minimizeProc.workspace = win.workspace;
        minimizeProc.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/toggle-minimize.sh",
                                "stash", win.address];
        minimizeProc.running = true;
    }

    Process {
        id: minimizeProc

        property string workspace: ""

        running: false
        onExited: (code) => {
            if (code !== 0) {
                console.warn("[windowpolicy] toggle-minimize.sh stash failed:", code);
                return;
            }
            root.announceMinimize(minimizeProc.workspace);
        }
    }

    // ---------------------------------------------------------------------
    // Tell the user how to get the window back.
    //
    // WHY THIS IS NOT DECORATION. On macOS a minimised window visibly flies into
    // the Dock, so the way back is obvious. Here there is no target to fly to:
    // the window simply stops existing on screen, and the key that brings it
    // back (SUPER + SHIFT + A) is not one you would guess from having clicked a
    // dot. The button is otherwise a trapdoor.
    //
    // The workspace is named because the stash is SCOPED to it -- see the header
    // of toggle-minimize.sh. Pressing the key on a different workspace restores
    // nothing and looks broken, so the message says where to press it.
    //
    // Only the BUTTON path announces. SUPER + SHIFT + A does not: if you pressed
    // the key you already know the key, and a notification every time would be
    // noise on a bind that has worked silently for as long as it has existed.
    //
    // notify-send goes to mako, which is the notification daemon on this system
    // (Settings.features.notifications is deliberately false -- the shell does
    // not run its own). Low urgency and a short timeout so it never queues up
    // behind anything that matters.
    // ---------------------------------------------------------------------
    function announceMinimize(workspace) {
        const where = workspace && workspace !== ""
            ? "workspace " + workspace : "this workspace";
        notifyProc.command = ["notify-send",
            "--app-name=Windows",
            "--urgency=low",
            "--expire-time=3000",
            "--hint=string:x-canonical-private-synchronous:window-minimize",
            "Window minimized",
            "SUPER + SHIFT + A on " + where + " brings it back"];
        notifyProc.running = true;
    }

    Process {
        id: notifyProc
        running: false
    }

    // ---------------------------------------------------------------------
    // Pushing the mouse policy into the compositor
    //
    // WHY A PUSH AND NOT A READ
    //   The consumer is a MOUSE-PRESS handler in the compositor's Lua state.
    //   It has to decide "float this window or hand it to the plain drag" and
    //   then act in the same breath. Shelling out to jq from there would put a
    //   process spawn in front of every SUPER+SHIFT+click. So the values are
    //   pushed in as Lua globals whenever they change, and
    //   ~/.config/hypr/windows.lua carries identical defaults for the case
    //   where this process is not running.
    //
    // WHY hyprctl eval
    //   It is the established way this desktop writes to its own Lua config --
    //   display-layout.sh and toggle-minimize.sh both do it, because
    //   `hyprctl keyword` is rejected outright under a non-legacy parser
    //   ("keyword can't work with non-legacy parsers. Use eval."). eval runs
    //   the chunk in the live config state, so a global set here persists.
    //
    // WHY IT RE-PUSHES ON RELOAD
    //   `hyprctl reload` re-executes the Lua config from a FRESH state, which
    //   drops every global this has set and restores windows.lua's defaults.
    //   Without the configreloaded hook a SUPER+SHIFT+R would silently revert
    //   the setting -- the exact class of silent staleness autostart.lua's
    //   header is written about.
    // ---------------------------------------------------------------------

    function pushPolicy() {
        pushProc.command = ["hyprctl", "eval",
            "WindowBehaviour.drag_to_float = " + (Settings.windows.dragToFloat ? "true" : "false")
            + "; WindowBehaviour.float_scale = " + Number(Settings.windows.floatScale).toFixed(3)];
        pushProc.running = true;
    }

    Process {
        id: pushProc

        running: false
        onExited: (code) => {
            if (code !== 0) console.warn("[windowpolicy] could not push window policy to Hyprland:", code);
        }
    }

    // Collapse a slider drag into one push, the same way Settings collapses it
    // into one file write.
    Timer {
        id: pushDebounce

        interval: 250
        onTriggered: root.pushPolicy()
    }

    Connections {
        target: Settings.windows

        function onDragToFloatChanged() { pushDebounce.restart(); }
        function onFloatScaleChanged() { pushDebounce.restart(); }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded") root.pushPolicy();
        }
    }

    Component.onCompleted: {
        // Push once at startup: settings.json is authoritative and windows.lua
        // has only just re-applied its own defaults.
        root.pushPolicy();
    }
}
