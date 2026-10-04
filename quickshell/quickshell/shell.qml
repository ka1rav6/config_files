import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// shell.qml — the Quickshell desktop layer for this machine.
// =============================================================================
// Started once at login from ~/.config/hypr/autostart.lua. A second instance
// is prevented by Quickshell's own `-n` / --no-duplicate flag, which is checked
// against its instance registry -- NOT by a pgrep guard, which is what this
// used to say. (The pgrep form was replaced precisely because it matched on a
// command line that had stopped being accurate; see the long note in
// autostart.lua about how `pgrep -f` guards silently match themselves.)
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
        // WindowPolicy — pushes the SUPER+drag policy into the compositor's Lua
        // state at startup and on every `hyprctl reload`. That has to happen
        // whether or not the control cluster is enabled, so it cannot be left
        // to WindowControls constructing it lazily.
        void WindowPolicy.visible;
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

    // The power menu has no feature flag of its own: a desktop you cannot shut
    // down from is not a desktop. SUPER + M opens this; if the shell is not
    // running that keybind falls back to wlogout via
    // ~/.config/waybar/scripts/power-menu.sh (see bindings.lua -- `ipc call`
    // exits 255 when no shell is reachable, which is what drives the ||).
    PowerMenu {}

    Loader {
        active: Settings.features.settings
        sourceComponent: SettingsWindow {}
    }

    // The Command Center.  SUPER + SHIFT + K, or the waybar ⌘ button.
    //
    // A front-end for ~/Justfile and the system CLI, not a third settings app
    // -- see the header of modules/commandcenter/CommandCenter.qml for where
    // the line between this, the Control Center and Settings is drawn.
    //
    // Gated on its own feature flag like every other component, so it can be
    // unloaded entirely; the keybind and the waybar button then do nothing at
    // all, and every command they front is still one `just` away. That is the
    // whole point of the panel calling `just` rather than copying it.
    Loader {
        active: Settings.features.commandCenter
        sourceComponent: CommandCenter {}
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

    // The workspace carousel. SUPER + SPACE used to open the launcher; wofi is
    // the launcher now (SUPER + S), by choice, so the key went to this.
    Loader {
        active: Settings.features.overview
        sourceComponent: Overview {}
    }

    Loader {
        active: Settings.features.emoji
        sourceComponent: EmojiPicker {}
    }

    Loader {
        active: Settings.features.dock
        sourceComponent: Dock {}
    }

    Loader {
        active: Settings.features.dashboard
        sourceComponent: Dashboard {}
    }

    // The macOS-style control cluster on the active window's top-right corner.
    //
    // Gated on Settings.windows.controls rather than on a features flag: it is
    // one small surface per output with no service subscriptions, so it belongs
    // with the other window settings rather than in Components. `false` still
    // means nothing is constructed -- no surface, no tracking timer, no socket
    // traffic (see the tracking note in services/WindowPolicy.qml).
    Loader {
        active: Settings.windows.controls
        sourceComponent: WindowControls {}
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
        target: "emoji"

        function toggle(): string { return Shell.toggle("emoji") ? "ok" : "emoji picker is disabled"; }
        function open(): string { return Shell.open("emoji") ? "ok" : "emoji picker is disabled"; }
        function close(): void { Shell.close("emoji"); }
    }

    IpcHandler {
        target: "overview"

        function toggle(): string { return Shell.toggle("overview") ? "ok" : "overview is disabled"; }
        function open(): string { return Shell.open("overview") ? "ok" : "overview is disabled"; }
        function close(): void { Shell.close("overview"); }
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
        target: "commandcenter"

        function toggle(): string { return Shell.toggle("command-center") ? "ok" : "command center is disabled"; }
        function open(): string { return Shell.open("command-center") ? "ok" : "command center is disabled"; }
        function close(): void { Shell.close("command-center"); }

        // Open straight onto one category: appearance, shell, kdeconnect,
        // session, system, maintenance, tools. For a waybar module or a `just`
        // recipe that wants to land somewhere specific.
        function page(name: string): string {
            if (!Shell.has("command-center")) return "command center is disabled";
            const panel = Shell.panels["command-center"];
            if (!CommandRegistry.category(name))
                return "no such category: " + name
                    + " (" + CommandRegistry.categories.map(c => c.id).join(", ") + ")";
            // OPEN FIRST, then navigate. Opening a closed panel fires its
            // `opened()` handler, which resets it to the home page with an
            // empty search -- so setting the page before opening silently
            // landed on home instead. It only looked correct while testing
            // because the panel happened to be open already, which is the
            // worst way for an ordering bug to hide.
            Shell.open("command-center");
            panel.categoryId = name;
            panel.page = "category";
            panel.selected = -1;
            return "ok";
        }

        // Open with the search box pre-filled, and report what matched.
        // `quickshell ipc call commandcenter find vpn` is the scriptable half
        // of search -- and the only way to check the ranking without clicking.
        function find(query: string): string {
            const hits = CommandRegistry.search(query);
            if (Shell.has("command-center")) {
                Shell.open("command-center");
                Shell.panels["command-center"].query = query;
            }
            if (hits.length === 0) return "no match for " + JSON.stringify(query);
            return hits.length + (hits.length === 1 ? " match" : " matches") + "\n"
                + hits.map(c => "  " + c.id.padEnd(22) + c.name).join("\n");
        }

        // Run one command by its registry id, without opening the panel.
        //
        // SAFE COMMANDS ONLY, and that restriction is the point. This is not a
        // back door around the confirmation sheet in CmdConfirm.qml: anything
        // marked `confirm` or `danger` is refused and told to use the panel,
        // because the sheet is where the consequence is explained and a
        // scripted `ipc call` has nobody to explain it to. The CLI equivalent
        // of a dangerous command is the `just` recipe itself, which is right
        // there in the refusal message.
        //
        // It also cannot run anything that is not in the registry, so this
        // stays a curated launcher rather than a shell over D-Bus.
        function run(id: string): string {
            const cmd = CommandRegistry.get(id);
            if (!cmd)
                return "no such command: " + id;
            if (cmd.safety !== "safe")
                return cmd.name + " needs confirmation (" + cmd.safety + "). "
                    + "Run it from the panel, or use: " + cmd.cli;
            // A selector has nothing to run without being told WHICH. It used
            // to reach the service with `undefined`, which is how the shadowed
            // ThemeCatalogue.apply() was found -- but handing a service an
            // undefined argument is not behaviour to keep.
            if (cmd.ui === "select")
                return cmd.name + " is a selector — use: "
                    + "ipc call commandcenter set " + id + " <value>";
            // A command that needs a value has no scripted form here on
            // purpose: the `just` recipe IS the scripted form, it already
            // takes the argument, and adding a second way in would be a
            // second thing to keep in step for no gain.
            if (cmd.input !== undefined)
                return cmd.name + " needs a value — use the panel ("
                    + "ipc call commandcenter prompt " + id + "), or: " + cmd.cli;
            return CommandRunner.run(cmd) ? "running " + cmd.name : "could not run " + id;
        }

        // Choose one option of a `select` command:
        //   ipc call commandcenter set theme gruvbox
        //   ipc call commandcenter set profile saver
        //
        // A separate function rather than a second argument to `run`, because
        // Quickshell's IPC enforces arity: a two-parameter `run` could no
        // longer be called as `run <id>` at all, which is how every other
        // command is reached.
        //
        // An unknown value is LISTED rather than passed on. `theme-switch
        // <typo>` exits non-zero several seconds later, by which time there is
        // nothing on screen to attribute the failure to -- and the valid list
        // is right here, generated by theme-switch itself.
        function set(id: string, value: string): string {
            const cmd = CommandRegistry.get(id);
            if (!cmd) return "no such command: " + id;
            if (cmd.ui !== "select")
                return cmd.name + " is not a selector — use: "
                    + "ipc call commandcenter run " + id;

            const ids = CommandState.optionsFor(cmd).map(o => o.id);
            if (ids.length === 0)
                return cmd.name + " has no options yet (its service is still "
                    + "loading; try again in a moment)";
            if (!value)
                return cmd.name + " needs a value: " + ids.join(", ")
                    + "  (currently " + CommandState.valueFor(cmd) + ")";
            if (ids.indexOf(value) === -1)
                return "no such option " + JSON.stringify(value) + " for "
                    + cmd.name + ". Expected: " + ids.join(", ");

            return CommandRunner.run(cmd, value)
                ? "applying " + cmd.name + ": " + value
                : cmd.name + " is already busy";
        }

        // Every command, one per line, as id + category + safety. The
        // discoverable half of `run` -- the same job `just --list` does for the
        // Justfile, which is where most of these come from.
        function list(): string {
            return CommandRegistry.commands.map(c =>
                c.id.padEnd(22) + c.category.padEnd(13)
                + c.safety.padEnd(9) + c.name).join("\n");
        }

        // The last run's exit code and output, for the command named. The
        // scripted equivalent of the panel's output view.
        function output(id: string): string {
            const entry = CommandRunner.lastRun(id);
            if (!entry) return "no recorded run of " + id;
            return "exit " + entry.code
                + (entry.detached ? " (detached, output not captured)" : "")
                + (entry.stderr ? "\n--- stderr ---\n" + entry.stderr : "")
                + (entry.stdout ? "\n--- stdout ---\n" + entry.stdout : "");
        }

        // Open the panel with the confirmation sheet already armed for one
        // command. The counterpart to `run`, which refuses anything that is not
        // `safe`: this reaches the dangerous ones WITHOUT bypassing the gate --
        // the sheet still has to be answered, and it still explains what is
        // about to happen. So a keybind or a script can offer "restart the
        // shell?" properly rather than either doing it silently or not at all.
        function prompt(id: string): string {
            if (!Shell.has("command-center")) return "command center is disabled";
            const cmd = CommandRegistry.get(id);
            if (!cmd) return "no such command: " + id;
            const panel = Shell.panels["command-center"];
            Shell.open("command-center");

            // Whatever gate this command has, arm it: the input sheet for one
            // that takes a value, the file picker for one that takes paths,
            // the confirmation sheet for a risky one. Either way it still has
            // to be answered.
            //
            // Routed through the panel's own invoke() rather than reproduced
            // here, so there is exactly ONE place that decides which gate a
            // command gets. A second copy of that decision is how a dangerous
            // command eventually reaches a path that forgot to ask.
            if (cmd.input !== undefined || cmd.safety !== "safe") {
                panel.invoke(cmd, undefined, undefined);
                return (cmd.input !== undefined ? "awaiting input: " : "awaiting confirmation: ")
                    + cmd.name;
            }

            // Nothing to gate; show it in context rather than silently running
            // something the caller did not ask to have run.
            panel.query = cmd.name;
            return cmd.name + " is safe — no confirmation needed, shown in search";
        }

        // Every live readout the panel can show, whether or not it is open.
        //
        // The same job `shell services` does for the service layer, and for the
        // same reason: when a row shows the wrong thing, this says whether the
        // problem is the state layer (wrong text here) or the UI (right text
        // here, wrong pixels on screen).
        //
        // Reading these also FORCES the lazy singletons behind them to
        // construct, which is the cheap way to smoke-test the registry after a
        // change -- a service with an error in it stays silent until something
        // touches it.
        function state(): string {
            const lines = [];
            for (const key in CommandState.status) {
                const s = CommandState.status[key];
                lines.push("  " + key.padEnd(18) + "[" + s.tone + "] " + s.text);
            }
            const toggles = [];
            for (const key in CommandState.states)
                toggles.push(key + "=" + CommandState.states[key]
                    + (CommandState.enabled[key] === false ? " (unavailable)" : ""));
            const values = [];
            for (const key in CommandState.values)
                values.push(key + "=" + CommandState.values[key]);
            // Option-list sizes too: an empty selector is the one failure
            // this panel cannot show on its own (the page renders, with
            // nothing on it), and the cause is always upstream -- a service
            // that has not loaded its file yet, or theme-switch not having
            // generated the catalogue.
            const opts = [];
            for (const key in CommandState.options)
                opts.push(key + "=" + CommandState.options[key].length);
            return "status\n" + lines.join("\n")
                + "\ntoggles\n  " + toggles.join("  ")
                + "\nvalues\n  " + values.join("  ")
                + "\noptions\n  " + opts.join("  ")
                + "\nsources\n  themeCatalogue=" + ThemeCatalogue.themes.length
                + " matugenLoaded=" + Matugen.loaded
                + " matugenSchemes=" + Matugen.schemes.length;
        }

        // What the panel knows, without opening it. Mostly here so a failing
        // keybind can be told apart from a failing registry.
        function status(): string {
            if (!Shell.has("command-center")) return "command center is disabled";
            const panel = Shell.panels["command-center"];
            // Reconciled counts, not raw list lengths: an id left in
            // settings.json whose command has been renamed is skipped when the
            // panel renders, so counting the raw array would make this
            // diagnostic disagree with the screen. The `of N stored` only
            // appears when they differ, which is exactly when it matters.
            const pinned = CommandRunner.favouriteCommands.length;
            const pinnedStored = CommandRunner.favourites.length;
            const recent = CommandRunner.recentCommands.length;
            const recentStored = CommandRunner.recent.length;
            return CommandRegistry.commands.length + " commands in "
                + CommandRegistry.categories.length + " categories"
                + " · " + pinned + " pinned"
                + (pinned !== pinnedStored ? " (of " + pinnedStored + " stored)" : "")
                + " · " + recent + " recent"
                + (recent !== recentStored ? " (of " + recentStored + " stored)" : "")
                + " · " + (panel.open ? "open on " + panel.page : "closed")
                + (CommandRunner.running ? " · running " + CommandRunner.runningId : "");
        }
    }

    // SUPER + SHIFT + T. There is no separate theme PANEL -- theme switching is
    // the Appearance page of Settings, backed by ~/.local/bin/theme-switch,
    // which stays the single source of truth for what the desktop looks like.
    //
    // This target exists because bindings.lua has bound SUPER+SHIFT+T to
    // `quickshell ipc call theme toggle` for as long as the shell has existed,
    // against a target that was never declared. `ipc call` prints "Target not
    // found." and still exits 0, so the key did nothing and said nothing.
    IpcHandler {
        target: "theme"

        function toggle(): string {
            if (!Shell.has("settings")) return "settings is disabled";
            const panel = Shell.panels["settings"];
            // Already sitting on Appearance: treat the key as a toggle and
            // close, matching every other panel key in the shell.
            if (panel.open && panel.page === "appearance") {
                panel.hide();
                return "ok";
            }
            panel.page = "appearance";
            Shell.open("settings");
            return "ok";
        }

        function open(): string {
            if (!Shell.has("settings")) return "settings is disabled";
            Shell.panels["settings"].page = "appearance";
            Shell.open("settings");
            return "ok";
        }

        function close(): void { Shell.close("settings"); }

        // Which palette is live, and whether it came from theme-switch or the
        // built-in fallback.
        function current(): string {
            return Theme.name + (Theme.fromDisk ? "" : " (fallback)");
        }
    }

    // Window controls. `toggle` is the same switch as Settings > Windows, so a
    // keybind and the GUI cannot disagree about it.
    //
    // `suspend` / `resume` are called by the SUPER+drag mouse binds in
    // ~/.config/hypr/bindings.lua, on press and on release. They exist because
    // Hyprland emits no geometry event: without them the cluster would
    // rubber-band a frame behind a window being dragged. The suspension
    // self-clears after 8 s, so a `resume` lost to a shell restart mid-drag
    // cannot hide the cluster permanently.
    IpcHandler {
        target: "windowcontrols"

        function toggle(): string {
            Settings.windows.controls = !Settings.windows.controls;
            return Settings.windows.controls ? "on" : "off";
        }

        function on(): void { Settings.windows.controls = true; }
        function off(): void { Settings.windows.controls = false; }

        function suspend(): void { WindowPolicy.beginInteraction(); }
        function resume(): void { WindowPolicy.endInteraction(); }

        // Why the cluster is or is not on screen, in one line.
        function status(): string {
            if (!Settings.windows.controls) return "off";
            if (WindowPolicy.visible) {
                const win = WindowPolicy.active;
                return "visible on " + (win ? win.cls + " @ " + win.x + "," + win.y
                                              + " " + win.width + "x" + win.height
                                        : "?")
                    + (WindowPolicy.trackingFast ? " [following 8Hz]" : " [event-driven]");
            }
            return "hidden: " + WindowPolicy.suppressedBecause;
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
                // Both numbers, because they can legitimately differ and the
                // gap between them is exactly what makes "the slider says 160
                // but it looks coarse" hard to diagnose. The profile scales
                // the configured value (Performance.visualizerBands), and the
                // RUNNING process may be on an older value still, since cava
                // only re-reads its config on respawn.
                + "\nbands       set " + Settings.visualizer.bands
                + " · profile " + Performance.visualizerBands
                + (Cava.liveBands > 0 ? " · running " + Cava.liveBands : " · not running")
                + " @ " + Performance.visualizerFramerate + "fps";
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
                // This used to say a 0 here meant "not measured, because the
                // scanner is off". That was wrong, and it was wrong in a way
                // that hid a real bug for a long time: NetworkManager always
                // knows the AP you are ASSOCIATED with, scanner or not, so the
                // connected network's strength is live at all times. The zeroes
                // were a unit mismatch in services/Network.qml, now fixed. A 0
                // here again means Wi-Fi is genuinely down -- treat it as a
                // symptom, not as expected quiet.
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
