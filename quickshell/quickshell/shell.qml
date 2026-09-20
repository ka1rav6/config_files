import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// shell.qml — the Quickshell desktop layer for this machine.
// =============================================================================
// Started once at login from ~/.config/hypr/autostart.lua, guarded by a pgrep
// so `hyprctl reload` cannot stack a second shell on top of the first.
//
// WHAT THIS IS
//   Hyprland owns compositor behaviour: workspaces, scratchpads, window rules,
//   monitors, input, keybindings. None of that lives here and none of it should.
//   This process owns presentation and interaction -- the panels, the controls,
//   the widgets -- and talks to the compositor through services/Hypr.qml.
//
// WHAT HAPPENS IF THIS CRASHES
//   Nothing important. Hyprland keeps running, every keybind still works, the
//   scratchpads still toggle, waybar and mako are separate processes. The shell
//   comes back with `just qs-restart`. The compositor must never depend on this
//   process, and nothing here is allowed to make it.
//
// FEATURE TOGGLES
//   Every component below is wrapped in a LazyLoader keyed off
//   Settings.features. `false` means the object is never constructed -- no
//   window, no timers, no service subscriptions, no cost. Turning one off can
//   never break another, because they communicate through singletons rather
//   than through each other.
//
// CONTROLLING IT
//   Keybindings live in ~/.config/hypr/bindings.lua as they always have. They
//   reach this process through the IpcHandler blocks at the bottom:
//
//       keybind -> bindings.lua -> quickshell ipc call <target> <fn> -> UI
//
//   Check what is available with:  quickshell ipc show
// =============================================================================

ShellRoot {
    id: shell

    // -----------------------------------------------------------------
    // Reload behaviour
    //
    // Quickshell pops a toast on every config reload. That is useful while
    // developing a shell and noise once it works -- and this shell reloads
    // whenever settings.json changes, which is every time a slider moves.
    // -----------------------------------------------------------------
    Connections {
        target: Quickshell

        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
        }

        function onReloadFailed(error) {
            // Deliberately NOT inhibited the same way: a failed reload leaves
            // the previous generation running, and silently swallowing that
            // means editing a QML file can leave you looking at a stale shell
            // with no indication why. Let this one show.
            console.warn("[shell] reload failed:", error);
        }
    }

    // -----------------------------------------------------------------
    // Eager singletons
    //
    // QML builds singletons lazily, on first read. Most should stay lazy, but
    // a few have to be alive before anything asks, because they own state that
    // has to be correct from the first frame:
    //
    //   Settings  — everything else reads it; loading it late means one frame
    //               at default values.
    //   Theme     — same, for colours.
    //   Hypr      — subscribes to the compositor event socket. Events that
    //               arrive before it is constructed are simply missed, so the
    //               fullscreen flag would start out wrong.
    //
    // `void X.y` is the idiom for "touch this singleton without using the
    // result" -- reading any property is what forces construction.
    // -----------------------------------------------------------------
    Component.onCompleted: {
        void Settings.loaded;
        void Theme.name;
        void Hypr.usingLua;
    }

    // -----------------------------------------------------------------
    // Components
    //
    // Each is gated on its feature flag in settings.json. A `false` there means
    // the object is never constructed: no window, no timers, no subscriptions.
    // Turning one off can never break another, because they talk to each other
    // through singletons rather than directly.
    // -----------------------------------------------------------------

    // The OSD is a Scope, not a window -- it builds its own window only while
    // something is being shown -- so it is cheap to keep loaded and does not
    // need a LazyLoader of its own.
    Loader {
        active: Settings.features.osd
        sourceComponent: Osd {}
    }

    // Panels are Scopes too: each holds a LazyLoader that builds its window on
    // first open and tears it down after close. The Loader here only decides
    // whether the panel EXISTS (and so whether it registers with Shell and can
    // be opened at all), not whether it is on screen.
    Loader {
        active: Settings.features.controlCenter
        sourceComponent: ControlCenter {}
    }

    // The power menu has no feature flag of its own: an desktop you cannot
    // shut down from is not a desktop. SUPER + M still reaches wlogout via
    // ~/.config/waybar/scripts/power-menu.sh when Quickshell is not running.
    PowerMenu {}

    Loader {
        active: Settings.features.settings
        sourceComponent: SettingsWindow {}
    }

    // The visualizer is a Scope that creates its own per-monitor surfaces only
    // while it is wanted, so this Loader only decides whether it exists at all.
    Loader {
        active: Settings.features.musicVisualizer
        sourceComponent: Visualizer {}
    }

    // NO LOCK LOADER HERE, DELIBERATELY.
    //
    // The lock screen used to live in this process. When the session fell over
    // one afternoon it took the locker with it, and ext-session-lock does
    // exactly what it is supposed to in that situation: the compositor keeps
    // the screen locked, because a lock that fails open is not a lock. The way
    // back in was a TTY.
    //
    // It now runs as its own quickshell process (lock.qml, launched by
    // ~/.local/bin/lock-session) so that nothing in this shell -- the dock, the
    // visualiser, cava, a service singleton -- can take the locker down with
    // it. See modules/lock/Lock.qml.

    // Desktop widgets create their own per-monitor surfaces only while the
    // wallpaper is actually visible, so this Loader only decides whether the
    // layer exists at all.
    Loader {
        id: widgetLayer
        active: Settings.features.widgets
        sourceComponent: Widgets {}
    }

    Loader {
        active: Settings.features.wallpaperManager
        sourceComponent: WallpaperPicker {}
    }

    Loader {
        active: Settings.features.launcher
        sourceComponent: Launcher {}
    }

    Loader {
        active: Settings.features.dock
        sourceComponent: Dock {}
    }

    Loader {
        active: Settings.features.dashboard
        sourceComponent: Dashboard {}
    }

    // -----------------------------------------------------------------
    // IPC
    //
    // The bridge from the existing keybindings. Every UI surface gets a target
    // here rather than a global shortcut registered from QML, because the
    // keybinding architecture in ~/.config/hypr/bindings.lua stays the single
    // place keys are declared.
    // -----------------------------------------------------------------

    // -----------------------------------------------------------------
    // Panel IPC
    //
    // One handler per panel, each a three-line pass-through to the registry in
    // services/Shell.qml. They are written out rather than generated because
    // `quickshell ipc show` reads the declared functions -- a generic
    // `panel(name, action)` would work but would make the IPC surface
    // undiscoverable, and discoverability is the point of `just qs-ipc`.
    //
    // Calling one whose panel is disabled in Settings is harmless: the panel
    // never registered, so this returns a clear message rather than failing.
    // That is what makes the feature toggles genuinely independent.
    // -----------------------------------------------------------------

    IpcHandler {
        target: "controlcenter"

        function toggle(): string { return Shell.toggle("control-center") ? "ok" : "control center is disabled"; }
        function open(): string { return Shell.open("control-center") ? "ok" : "control center is disabled"; }
        function close(): void { Shell.close("control-center"); }

        // Open straight onto one of the sub-pages: main, wifi, bluetooth,
        // audio. Used for testing, and available to anything that wants to
        // land on a specific panel rather than the tile grid.
        function page(name: string): string {
            if (!Shell.has("control-center")) return "control center is disabled";
            Shell.open("control-center");
            Shell.panels["control-center"].page = name;
            return "ok";
        }
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): string { return Shell.toggle("dashboard") ? "ok" : "dashboard is disabled"; }
        function open(): string { return Shell.open("dashboard") ? "ok" : "dashboard is disabled"; }
        function close(): void { Shell.close("dashboard"); }

        // The waybar clock calls this instead of toggle(): same panel, but it
        // drops down from under the bar rather than appearing at the top right.
        function dropdown(): string {
            if (!Shell.has("dashboard")) return "dashboard is disabled";
            const panel = Shell.panels["dashboard"];
            if (panel.open) { panel.hide(); return "ok"; }
            panel.dropdown = true;
            Shell.open("dashboard");
            return "ok";
        }
    }

    // Desktop widgets are not a Panel -- they are a permanent layer with an
    // edit mode rather than something that opens and closes -- so they get
    // their own handler instead of a Shell registry entry.
    IpcHandler {
        target: "widgets"

        function edit(): string {
            if (!widgetLayer.item) return "widgets are disabled";
            widgetLayer.item.toggleEdit();
            return widgetLayer.item.editing ? "editing" : "done";
        }

        function done(): void { if (widgetLayer.item) widgetLayer.item.done(); }

        function reset(): string {
            if (!widgetLayer.item) return "widgets are disabled";
            widgetLayer.item.resetLayout();
            return "layout reset";
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): string { return Shell.toggle("launcher") ? "ok" : "launcher is disabled"; }
        function open(): string { return Shell.open("launcher") ? "ok" : "launcher is disabled"; }
        function close(): void { Shell.close("launcher"); }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): string { return Shell.toggle("wallpaper") ? "ok" : "wallpaper manager is disabled"; }
        function open(): string { return Shell.open("wallpaper") ? "ok" : "wallpaper manager is disabled"; }
        function close(): void { Shell.close("wallpaper"); }

        // `quickshell ipc call wallpaper random` -- also useful from a cron or
        // a `just` recipe.
        function random(): void { Wallpaper.random(); }
        function current(): string { return Wallpaper.current; }
    }

    IpcHandler {
        target: "visualizer"

        // The bind is SUPER + SHIFT + B. This toggles the DESKTOP widget, not
        // the feature: `Settings.features.musicVisualizer` in Settings >
        // Components unloads the whole thing, while this is the everyday
        // show/hide.
        function toggle(): string {
            Settings.desktop.visualizer = !Settings.desktop.visualizer;
            return Settings.desktop.visualizer ? "on" : "off";
        }

        function on(): void { Settings.desktop.visualizer = true; }
        function off(): void { Settings.desktop.visualizer = false; }

        // Why the bars are or are not moving.
        function status(): string { return Cava.status; }
    }

    IpcHandler {
        target: "settings"

        function toggle(): string { return Shell.toggle("settings") ? "ok" : "settings is disabled"; }
        function open(): string { return Shell.open("settings") ? "ok" : "settings is disabled"; }
        function close(): void { Shell.close("settings"); }

        // Jump straight to a page: `quickshell ipc call settings page visualizer`
        function page(name: string): string {
            if (!Shell.has("settings")) return "settings is disabled";
            Shell.open("settings");
            Shell.panels["settings"].page = name;
            return "ok";
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): string { return Shell.toggle("power") ? "ok" : "unavailable"; }
        function open(): string { return Shell.open("power") ? "ok" : "unavailable"; }
        function close(): void { Shell.close("power"); }
    }

    IpcHandler {
        target: "shell"

        // Health check. `quickshell ipc call shell status` is the quickest way
        // to tell a running shell from a crashed one, and it reports enough to
        // diagnose the usual failures: wrong theme file, settings not loaded,
        // compositor socket not connected.
        function status(): string {
            return "quickshell up"
                + " · theme " + Theme.name + (Theme.fromDisk ? "" : " (fallback)")
                + " · settings " + (Settings.loaded ? "loaded" : "NOT LOADED")
                + " · profile " + Performance.profile + (Performance.downshifted ? " (downshifted)" : "")
                + " · hyprland " + (Hypr.usingLua ? "lua" : "conf")
                + " · monitors " + Quickshell.screens.length
                + (Hypr.fullscreen ? " · fullscreen" : "");
        }

        // Write any pending settings change immediately. Worth calling before
        // a logout so a toggle flipped in the last 400 ms is not lost to the
        // debounce in config/Settings.qml.
        function flush(): void {
            Settings.flush();
        }

        // Set the performance profile from the command line, so the CLI keeps
        // parity with the GUI: `quickshell ipc call shell profile saver`
        function profile(name: string): string {
            if (name !== "saver" && name !== "balanced" && name !== "visual")
                return "expected: saver | balanced | visual";
            Settings.performance.profile = name;
            return "profile: " + name;
        }

        // Why the visualizer is or is not on screen. It has three
        // independent gates and "it is not showing" is otherwise very hard to
        // attribute.
        function viz(): string {
            const perMonitor = [];
            for (const name in Hypr.desktopVisibleByMonitor)
                perMonitor.push(name + "=" + (Hypr.desktopVisibleByMonitor[name] ? "visible" : "covered"));
            return "cava        " + Cava.status
                + "\nfeature     " + (Settings.features.musicVisualizer ? "on" : "OFF (Settings > Components)")
                + "\nwidget      " + (Settings.desktop.visualizer ? "on" : "OFF (Settings > Desktop)")
                + "\nprofile     " + (Performance.allowVisualizer ? "allows it" : "SUPPRESSED (" + Performance.profile + (Performance.gameMode ? ", fullscreen" : "") + ")")
                + "\ndesktop     " + (Hypr.anyDesktopVisible ? "visible" : "COVERED on every output")
                + "\n  " + perMonitor.join("  ")
                + "\naudio       peak " + Audio.peak.toFixed(3) + (Audio.audible ? " (audible)" : " (silent)")
                + " · mpris " + (Media.playing ? "playing" : "not playing")
                + "\nbands       " + Settings.visualizer.bands + " @ " + Performance.visualizerFramerate + "fps";
        }

        // What the dock thinks is running, and why an app might be missing.
        function dock(): string {
            const lines = [];
            for (const t of Hypr.toplevels.values) {
                const o = t.lastIpcObject;
                lines.push("  class=" + (o && o.class !== undefined ? JSON.stringify(o.class) : "<no ipc object>")
                    + " ws=" + (t.workspace ? t.workspace.id : "?")
                    + " hidden=" + (o ? o.hidden : "?")
                    + " addr=" + (o ? o.address : "?"));
            }
            const pins = [];
            for (const id of (Settings.dock.pinned || [])) {
                const e = DesktopEntries.byId(id);
                pins.push("  " + id + " -> " + (e ? e.name : "NOT FOUND"));
            }
            const looks = [];
            for (const t of Hypr.toplevels.values) {
                const o = t.lastIpcObject;
                if (!o || !o.class) continue;
                const e = DesktopEntries.heuristicLookup(o.class);
                looks.push("  " + o.class + " -> " + (e ? e.id : "NO MATCH"));
            }
            return "toplevels " + Hypr.toplevels.values.length + "\n" + lines.join("\n")
                + "\npinned:\n" + pins.join("\n")
                + "\nheuristic:\n" + looks.join("\n");
        }

        // Which panels exist and which are open. The first thing to check
        // when a keybind appears to do nothing -- a panel that is disabled in
        // Settings will simply not be listed here.
        function panels(): string {
            return Shell.summary;
        }

        // Every service's view of the world, in one call. This is the first
        // thing to run when a panel shows the wrong thing -- it says whether
        // the problem is the service (wrong data here) or the UI (right data
        // here, wrong pixels on screen).
        //
        // It also has a side effect worth knowing about: reading these forces
        // the singletons to construct. QML builds them lazily, so a service
        // with an error in it loads silently until something touches it.
        // Running this after a change is the cheap way to smoke-test the lot.
        function services(): string {
            return [
                "audio      " + (Audio.sinkReady
                    ? Math.round(Audio.volume * 100) + "%" + (Audio.muted ? " muted" : "") + " · " + Audio.sinkName
                    : "no sink"),
                "mic        " + (Audio.sourceReady
                    ? Math.round(Audio.micVolume * 100) + "%" + (Audio.micMuted ? " muted" : "") + " · " + Audio.sourceName
                    : "no source"),
                "brightness " + (Brightness.available ? Brightness.percent + "%" : "unavailable"),
                // signalStrength is only populated while the Wi-Fi scanner is
                // on, which it deliberately is not unless a panel is open --
                // so a 0 here means "not measured", not "no signal".
                "network    " + Network.summary
                    + (Network.signalStrength > 0 ? " · " + Network.signalStrength + "%" : "")
                    + " · " + Network.networks.length + " visible",
                "bluetooth  " + Bluetooth.summary + " · " + Bluetooth.pairedDevices.length + " paired",
                "media      " + (Media.available
                    ? (Media.playing ? "playing" : "paused") + " · " + (Media.summary || Media.identity)
                    : "no player"),
                "battery    " + (Performance.hasBattery
                    ? Math.round(Performance.batteryPercent * 100) + "%"
                      + (Performance.batteryCharging ? " charging" : " on battery")
                      + (Performance.batteryHealth > 0
                          ? " · health " + Math.round(Performance.batteryHealth) + "%"
                          : " · health not reported")
                    : "no battery"),
                "visualizer " + Cava.status,
                "theme      " + Theme.name + " · accent " + Theme.accent,
                "compositor " + (Hypr.usingLua ? "lua" : "conf") + " · ws "
                    + (Hypr.focusedWorkspace ? Hypr.focusedWorkspace.name : "?")
                    + " · " + Quickshell.screens.length + " monitor(s)"
                    + (Hypr.fullscreen ? " · fullscreen" : "")
            ].join("\n");
        }
    }
}
