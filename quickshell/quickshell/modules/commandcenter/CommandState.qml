pragma Singleton

import QtQuick
import Quickshell
import qs

// =============================================================================
// CommandState — the live readouts, in three maps.
// =============================================================================
// A row in the Command Center does not just execute something; where there is a
// current state worth knowing, it shows it. This is where that state comes
// from, and the shape is the whole design:
//
//   status  id -> { text, tone }     a one-line readout
//   states  id -> bool              what a toggle currently is
//   values  id -> string            which option a selector is on
//   options id -> [{ id, label }]   the live choices for a selector
//
// WHY MAPS AND NOT A FUNCTION PER COMMAND
//   A registry entry says `status: "wifi"`, and the row binds
//   `CommandState.status.wifi`. If this were `Registry.statusFor(id)` instead,
//   the row would call a plain JS function -- which QML cannot know depends on
//   Network.ssid, so the readout would be captured once and then quietly go
//   stale. A property with the service reads inside it IS a binding: Qt records
//   the dependency, and every row updates the moment the thing it describes
//   changes. That is the "event-driven, not polled" requirement, satisfied by
//   construction rather than by a timer.
//
// WHY ONE MAP AND NOT FORTY PROPERTIES
//   One binding re-running on any service change is cheaper than forty
//   bindings each re-running on one, because the work is string concatenation
//   and there are a dozen entries. It also means the registry stays the only
//   file that has to be edited to add a row: either the key already exists
//   here, or one line is added next to its neighbours.
//
// NOTHING HERE POLLS, SPAWNS OR SUBSCRIBES
//   Every value is read from a service singleton that the shell already keeps
//   up to date for the bar, the Control Center and the OSD. Opening this panel
//   adds no processes, no D-Bus subscriptions and no timers. The two things
//   that WOULD have cost something -- a Wi-Fi scan and Bluetooth discovery --
//   are not here at all: scanning stays gated to the Control Center pages that
//   need it (see the scanning bindings in ControlCenter.qml), and this panel
//   reports only the association NetworkManager knows about regardless.
//
// TONES
//   "good" | "warn" | "bad" | "idle". The row maps those onto Theme.success /
//   warning / error / muted. A tone is a claim about state, not a colour: it
//   is what lets a glance down the panel find the one thing that is wrong.
// =============================================================================

Singleton {
    id: root

    // -----------------------------------------------------------------
    // One-line readouts
    // -----------------------------------------------------------------
    readonly property var status: ({
        "theme": {
            text: Theme.name + (Theme.fromDisk ? "" : " · fallback palette")
                + (ThemeCatalogue.busy ? " · applying…" : ""),
            tone: Theme.fromDisk ? "good" : "warn"
        },

        "matugen": {
            text: Matugen.loaded
                ? (Matugen.installed
                    ? Matugen.shortName(Matugen.scheme) + " · " + Matugen.mode
                    : "matugen not installed — `auto` is using the fallback")
                : "reading…",
            tone: !Matugen.loaded ? "idle" : (Matugen.installed ? "good" : "warn")
        },

        "matugenInstalled": {
            text: Matugen.installed ? "Installed" : "Not installed",
            tone: Matugen.installed ? "good" : "warn"
        },

        "wallpaper": {
            text: Wallpaper.name !== "" ? Wallpaper.name : "none set",
            tone: Wallpaper.name !== "" ? "idle" : "warn"
        },

        "nightlight": {
            text: NightLight.available
                ? (NightLight.active
                    ? "On · " + NightLight.temperature + "K"
                    : "Off")
                : NightLight.unavailableReason,
            tone: !NightLight.available ? "bad" : (NightLight.active ? "good" : "idle")
        },

        "dnd": {
            text: Notifications.dnd ? "Notifications held" : "Notifications showing",
            tone: Notifications.dnd ? "warn" : "idle"
        },

        "profile": {
            text: Performance.profile
                + (Performance.downshifted
                    ? " · forced down from " + Performance.chosenProfile
                    : "")
                + (Performance.gameMode ? " · fullscreen" : ""),
            tone: Performance.downshifted ? "warn" : "idle"
        },

        "volume": {
            text: Audio.sinkReady
                ? Math.round(Audio.volume * 100) + "%"
                    + (Audio.muted ? " · muted" : "")
                    + (Audio.volume > 1.001 ? " · above unity" : "")
                : "no output device",
            tone: !Audio.sinkReady ? "bad"
                : Audio.volume > 1.001 ? "warn" : "idle"
        },

        // One line for the whole connectivity story, which is what the row
        // pointing at the Control Center should say.
        "connectivity": {
            text: Network.summary
                + " · " + (Bluetooth.available
                    ? (Bluetooth.enabled
                        ? (Bluetooth.anyConnected
                            ? "BT " + Bluetooth.connectedDevices.length + " connected"
                            : "BT on")
                        : "BT off")
                    : "no BT adapter"),
            tone: Network.connected ? "good" : "bad"
        },

        // The macOS-style control cluster.
        //
        // DELIBERATELY NOT WindowPolicy.visible. That property is false
        // whenever a shell panel is open -- which is always true while you are
        // reading this row, since this row is inside one. It would therefore
        // read "hidden: a shell panel is open (settings)" every single time,
        // which says nothing about the switch and looks like a fault. The
        // live "why is it not drawn" line stays where it is useful, in
        // `quickshell ipc call windowcontrols status`.
        "windowcontrols": {
            text: Settings.windows.controls
                ? "On · " + Settings.windows.controlsPosition.replace("-", " ")
                    + (Settings.windows.controlsOnFloating ? "" : " · tiled only")
                : "Off",
            tone: Settings.windows.controls ? "good" : "idle"
        },

        "displays": {
            text: Quickshell.screens.length === 1
                ? Quickshell.screens[0].name + " only"
                : Quickshell.screens.map(s => s.name).join(" + "),
            tone: "idle"
        },

        "shell": {
            text: "theme " + Theme.name
                + " · " + (Settings.loaded ? "settings loaded" : "SETTINGS NOT LOADED")
                + " · " + Performance.profile
                + " · " + Quickshell.screens.length
                + (Quickshell.screens.length === 1 ? " monitor" : " monitors"),
            tone: Settings.loaded ? "good" : "bad"
        }
    })

    // -----------------------------------------------------------------
    // Toggle positions
    //
    // These are READ-ONLY views of the service. A Toggle in the UI is bound to
    // one of these and calls the registry's `run` to change it -- it never
    // writes its own `checked`. That is the difference between a switch that
    // reflects the system and a switch that merely remembers being clicked:
    // if wlsunset dies, or `makoctl` is used from a terminal, these follow.
    // -----------------------------------------------------------------
    readonly property var states: ({
        "nightlight": NightLight.active,
        "dnd": Notifications.dnd,
        // A settings property rather than a service, but the rule is the same:
        // this is a READ of the thing the switch controls, so the Settings >
        // Windows checkbox, the IPC target and this row all follow each other
        // without any of them knowing the others exist.
        "windowcontrols": Settings.windows.controls
    })

    // Whether a toggle can be operated at all, with the reason if not.
    readonly property var enabled: ({
        "nightlight": NightLight.available,
        "dnd": Notifications.available
    })

    // -----------------------------------------------------------------
    // Selector positions
    // -----------------------------------------------------------------
    readonly property var values: ({
        "theme": Theme.name,
        "scheme": Matugen.scheme,
        "mode": Matugen.mode,
        // The CHOSEN profile, not the effective one. The selector must show
        // what the user picked, or a battery downshift would look like the
        // selection had been changed under them -- the effective profile is in
        // the status line above instead, where "forced down from visual" says
        // what actually happened.
        "profile": Settings.performance.profile
    })

    // -----------------------------------------------------------------
    // Live option lists
    //
    // Derived from the same services the Settings window uses, so a theme
    // added to theme-switch's THEMES dict appears here with no edit anywhere
    // in this module -- the catalogue is generated, never maintained by hand.
    // -----------------------------------------------------------------
    readonly property var options: ({
        "themes": ThemeCatalogue.themes.map(t => ({
            id: t.id,
            label: t.label !== undefined ? t.label : t.id,
            desc: t.desc !== undefined ? t.desc : "",
            swatch: t.a1 !== undefined ? t.a1 : ""
        })),

        "schemes": Matugen.schemes.map(s => ({
            id: s.id,
            label: Matugen.shortName(s.id),
            desc: s.desc !== undefined ? s.desc : ""
        })),

        "profiles": [
            { id: "saver",    label: "Saver",    desc: "No blur, no shadows, reduced motion, no visualiser" },
            { id: "balanced", label: "Balanced", desc: "The default — everything on, nothing extravagant" },
            { id: "visual",   label: "Visual",   desc: "Full effects, highest visualiser detail" }
        ]
    })

    // Whether a command is mid-flight somewhere other than CommandRunner's own
    // queue -- the theme and matugen selectors run through their services, and
    // those report their own progress.
    readonly property var busy: ({
        "theme": ThemeCatalogue.busy,
        "theme-auto": ThemeCatalogue.busy,
        "matugen-scheme": Matugen.busy,
        "matugen-mode": Matugen.busy
    })

    // --- helpers used by the rows ----------------------------------------

    function statusFor(cmd) {
        if (!cmd || !cmd.status) return null;
        const s = root.status[cmd.status];
        return s !== undefined ? s : null;
    }

    function toneColour(tone) {
        switch (tone) {
        case "good": return Theme.success;
        case "warn": return Theme.warning;
        case "bad": return Theme.error;
        default: return Theme.muted;
        }
    }

    function optionsFor(cmd) {
        if (!cmd) return [];
        if (cmd.options) return cmd.options;
        if (cmd.optionsFrom) {
            const list = root.options[cmd.optionsFrom];
            return list !== undefined ? list : [];
        }
        return [];
    }

    function valueFor(cmd) {
        if (!cmd || !cmd.value) return "";
        const v = root.values[cmd.value];
        return v !== undefined ? v : "";
    }

    function labelForValue(cmd) {
        const value = root.valueFor(cmd);
        for (const o of root.optionsFor(cmd))
            if (o.id === value) return o.label;
        return value;
    }

    function isBusy(cmd) {
        if (!cmd) return false;
        if (CommandRunner.runningId === cmd.id) return true;
        const b = root.busy[cmd.id];
        return b === true;
    }
}
