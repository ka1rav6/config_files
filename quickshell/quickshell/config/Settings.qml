pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// Settings — the single source of truth for every user-facing desktop option.
// =============================================================================
// Backed by ~/.config/quickshell/settings.json via FileView + JsonAdapter.
//
// HOW IT WORKS
//   Every `property` declared inside the JsonAdapter below is one key in that
//   JSON file. Quickshell keeps the two in sync automatically, in both
//   directions:
//
//     QML writes a property  -> adapterUpdated fires -> writeAdapter() saves
//     the file changes on disk -> fileChanged fires  -> reload() re-reads
//
//   The second direction is what keeps requirement "retain CLI power" honest:
//   editing settings.json in Neovim, or poking it from a shell script, updates
//   the running desktop live. The GUI is a front-end to this file, never the
//   only way in.
//
// WHY A NESTED JsonObject PER DOMAIN
//   Flat keys (`dockEnabled`, `dockSize`, `dockPosition`, ...) are what Lucid
//   does and its Prefs.qml is 36 KB of them. Grouping into JsonObject sections
//   keeps the file readable by hand, keeps names short, and means a whole
//   section can be reset by reassigning one object.
//
// WHY THE DEBOUNCE
//   Dragging a slider fires the property change on every frame. Without the
//   timer that would be ~120 file writes a second. The timer collapses a burst
//   into one write, 400 ms after the last change.
//
// ADDING A SETTING
//   Add the property to the right JsonObject with a sensible default. That is
//   all — the JSON key, the persistence and the live reload come for free. Do
//   NOT add a matching entry anywhere else; nothing needs to be kept in step.
//
// RESETTING
//   Delete ~/.config/quickshell/settings.json and reload the shell. Every
//   default below is re-applied and the file is written fresh.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    // Convenience aliases so consumers read `Settings.features.dock` rather
    // than `Settings.adapter.features.dock`. Purely ergonomic.
    readonly property alias features: adapter.features
    readonly property alias appearance: adapter.appearance
    readonly property alias desktop: adapter.desktop
    readonly property alias dock: adapter.dock
    readonly property alias launcher: adapter.launcher
    readonly property alias osd: adapter.osd
    // `emoji` was the one section declared in the adapter below WITHOUT an
    // alias here, so `Settings.emoji` was undefined and every read of
    // `Settings.emoji.favourites` threw. There was no load-time error: the
    // picker rendered, favourites and recents silently never worked, and the
    // log filled with ~111 TypeErrors per open (isFavourite() runs per cell).
    //
    // ANY new JsonObject section MUST get a line here too. modules/settings
    // has no way to reach `adapter` otherwise -- it is an id inside the
    // FileView, not a property of this singleton.
    readonly property alias emoji: adapter.emoji
    readonly property alias visualizer: adapter.visualizer
    readonly property alias wallpaper: adapter.wallpaper
    readonly property alias performance: adapter.performance

    // False until the first read finishes. UI that would otherwise flash its
    // defaults for a frame before the real values land should gate on this.
    readonly property bool loaded: file.loaded

    // ---------------------------------------------------------------------
    // Persistence
    // ---------------------------------------------------------------------

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.config/quickshell/settings.json"

        // Read the file during startup rather than asynchronously afterwards.
        // Without this the shell paints one frame at default values before the
        // saved ones arrive, which reads as a flicker on every login.
        preload: true

        // A missing settings.json is the normal first-run state, not a fault.
        // Without this every fresh install logs a scary read failure before
        // seeding the file a millisecond later.
        printErrors: false

        // First run, or the file was deleted to reset the desktop: write the
        // defaults out so the file exists to be edited by hand afterwards.
        // Every property in the adapter below already holds its default at
        // this point, so this is a straight dump rather than a merge.
        //
        // Only seed on "not found". A file that exists but failed to parse is
        // a different problem -- overwriting it would destroy settings the
        // user could otherwise recover by fixing a stray comma.
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) {
                console.log("[settings] no settings.json, writing defaults");
                file.writeAdapter();
            } else {
                console.warn("[settings] could not read settings.json:",
                             FileViewError.toString(error),
                             "- running on defaults, file left untouched");
            }
        }

        // atomicWrites writes to a temporary file and renames over the target.
        // A crash or a full disk mid-write then leaves the old settings intact
        // instead of a truncated file the next login cannot parse.
        atomicWrites: true

        // Pick up edits made outside the GUI — `nvim settings.json`, a script,
        // a `just` recipe. This is the CLI half of the contract.
        watchChanges: true
        onFileChanged: file.reload()

        // Save whenever anything in the adapter changes, debounced below.
        onAdapterUpdated: writeDebounce.restart()

        adapter: JsonAdapter {
            id: adapter

            // =============================================================
            // features — the master switches (requirement: every major
            // component independently toggleable, and turning one off must
            // never break another).
            //
            // These are read by shell.qml, which wraps each component in a
            // Loader. `false` here means the component is never constructed:
            // no window, no timers, no service subscriptions, no cost.
            // =============================================================
            property JsonObject features: JsonObject {
                property bool dock: true
                property bool launcher: true
                property bool overview: true      // workspace carousel, SUPER + SPACE
                property bool emoji: true         // emoji picker, SUPER + F2
                property bool osd: true
                property bool dashboard: true
                property bool widgets: true
                property bool controlCenter: true
                property bool settings: true
                // OFF. hyprlock is the locker.
                //
                // This was on for one afternoon and the session died while
                // locked, which under ext-session-lock means the compositor
                // correctly keeps the screen locked and you need a TTY to get
                // back in. Two separate causes were found (see
                // modules/lock/Lock.qml), one of which is a collision with
                // hypridle that cannot be fixed from this file. Do not turn
                // this on without reading that header.
                property bool lockScreen: false
                property bool wallpaperManager: true
                property bool music: true
                property bool musicVisualizer: true
                property bool calendar: true
                property bool notifications: false   // mako stays the daemon
            }

            // =============================================================
            // appearance — the design tokens. Appearance.qml derives every
            // measurement in the shell from these, so changing one value here
            // re-proportions the whole desktop rather than one widget.
            // =============================================================
            property JsonObject appearance: JsonObject {
                // Corner radius of a standard card, in logical px. Smaller
                // elements scale down from this in Appearance.qml.
                property int radius: 16

                // Base spacing unit. Padding and gaps are multiples of it.
                property int spacing: 12

                // Panel background opacity, 0..1. Anything below 1 only looks
                // right with the matching blur layer rule in
                // ~/.config/hypr/rules.lua — see the note there.
                property real opacity: 0.82

                // Whether to ask Hyprland to blur behind shell surfaces.
                // Blur is the compositor's most expensive effect, so this is
                // a real performance switch, not just a cosmetic one.
                property bool blur: true

                // Drop shadows under floating surfaces.
                property bool shadows: true

                // Global animation speed multiplier. 0 disables motion
                // entirely (accessibility: prefers-reduced-motion), 1 is the
                // designed speed, 2 is half speed.
                property real motion: 1.0

                // UI typeface. Inter is installed and is what the design was
                // drawn against; JetBrainsMono Nerd Font supplies the glyphs.
                property string font: "Inter"
                property string fontMono: "JetBrainsMono Nerd Font"

                // Type scale multiplier, for readability rather than zoom.
                property real fontScale: 1.0

                // "comfortable" | "compact". Compact tightens padding without
                // changing type size, for the external monitor.
                property string density: "comfortable"
            }

            // =============================================================
            // desktop — what is drawn on the wallpaper itself, under every
            // window. Per-widget enablement lives here; per-widget geometry
            // lives in `widgetLayout`, keyed by widget id.
            // =============================================================
            property JsonObject desktop: JsonObject {
                property bool clock: true
                property bool calendar: false
                property bool media: true
                property bool visualizer: true
                property bool cpu: false
                property bool ram: false
                property bool battery: false
                property bool network: false

                // Hide every desktop widget while a window is fullscreen, so a
                // video or a game never has a clock floating over it.
                property bool hideOnFullscreen: true

                // Snap widgets to a grid while dragging them.
                property bool snapToGrid: true
                property int gridSize: 8

                // id -> { x, y, w, h, monitor }. Written by the widget editor.
                // A var rather than typed properties because the set of
                // widgets is open-ended.
                property var widgetLayout: ({})
            }

            // =============================================================
            // emoji — the picker's memory. Favourites are pinned by hand
            // (right-click in the grid); recents fill themselves in.
            // =============================================================
            property JsonObject emoji: JsonObject {
                property list<string> favourites: []
                property list<string> recent: []
            }

            // =============================================================
            // dock
            // =============================================================
            property JsonObject dock: JsonObject {
                property string position: "bottom"   // bottom | left | right

                // Window classes the dock never shows, matched as substrings.
                // The scratchpads live here: they have their own keys and their
                // own special workspaces, so a dock tile would be a second,
                // worse way to reach something that is already one press away.
                property list<string> exclude: [
                    "com.scratchpad.ghostty",
                    "com.yazi.ghostty",
                    "hyprtodo",
                    "cinhimbnkkaeohfgghhklpknlkffjgod",   // YouTube Music PWA
                    "hnpfjngllnobngcgfapefoaidbinmjnm"    // WhatsApp Web PWA
                ]
                property int iconSize: 44
                property int spacing: 8

                // "always" | "auto" | "never". auto = reveal on edge hover.
                property string visibility: "auto"

                // Icon magnification on hover. Disable on battery if it ever
                // costs measurably; it is a transform, so it should not.
                property bool magnify: true
                property real magnifyScale: 1.35

                // Show windows from every workspace, or only the current one.
                property bool allWorkspaces: false

                // Desktop-entry ids, in order. Empty = pinned section hidden.
                //
                // NOTE: these are entry ids, WITHOUT the ".desktop" suffix --
                // DesktopEntries.byId("google-chrome.desktop") returns null
                // while byId("google-chrome") works. The dock accepts either
                // form (see Dock.lookup) because the suffix is what everyone
                // types, but the canonical form is the bare id.
                property var pinned: ["ghostty_ghostty", "google-chrome", "brave-browser", "code", "org.gnome.Nautilus"]
            }

            // =============================================================
            // launcher
            // =============================================================
            property JsonObject launcher: JsonObject {
                property int width: 640
                property int maxResults: 8
                property bool searchFiles: false     // needs fd; off by default
                property bool showPowerActions: true
                property bool showSettings: true
                property bool showClipboard: true

                // Desktop-entry ids, most recently launched first. Persisted so
                // the ordering survives a restart -- a launcher that forgets
                // what you use is barely better than an alphabetical list.
                property var recent: []
            }

            // =============================================================
            // osd — the volume / brightness / mic / media indicator
            // =============================================================
            property JsonObject osd: JsonObject {
                property string position: "bottom"   // top | bottom | left | right
                property int timeout: 1600           // ms on screen after the last change
                property bool showMedia: true
                property bool showVolume: true
                property bool showBrightness: true
                property bool showMic: true
            }

            // =============================================================
            // visualizer — the audio-reactive bars.
            //
            // See services/Cava.qml for how these are enforced. The important
            // one is `gateOnPlayback`: with it on, no cava process exists at
            // all while the machine is silent.
            // =============================================================
            property JsonObject visualizer: JsonObject {
                // Band count. Higher is smoother-looking and linearly more
                // expensive in both cava and the renderer. 48 was chosen by
                // measurement; see the benchmark note in services/Cava.qml.
                // 160 for the mirror style: it is a waveform, and a waveform
                // needs enough columns to read as one rather than as a row of
                // blocks. The Canvas renderer makes the count cheap -- see the
                // benchmark note in modules/visualizer/Visualizer.qml.
                // 160 thin columns: enough to read as a waveform rather than
                // as a row of blocks. Affordable because the renderer draws
                // them as one path of roundedRects -- see the benchmark note in
                // modules/visualizer/Visualizer.qml.
                property int bands: 160

                // 45 rather than 60. Measured on this machine across both
                // monitors: 60 Hz costs 3.9 % CPU, 30 Hz costs 2.3 %, and with
                // the fall-smoothing below already applied the difference
                // between 45 and 60 is not visible. Dropped to 30 on battery by
                // config/Performance.qml.
                // 60 again. The Canvas renderer was the bottleneck, not the
                // frame rate -- once the mirror path stopped drawing hand-rolled
                // bezier curves (see modules/visualizer/Visualizer.qml) 60 fps
                // became affordable, and 45 was visibly choppy on a 120 Hz
                // panel. config/Performance.qml still drops it to 30 on battery.
                property int framerate: 60
                // Gain trim applied AFTER the perceptual curve in
                // services/Cava.qml. 1.0 is the calibrated default; raise it
                // for quiet material.
                property real sensitivity: 1.0
                property real smoothing: 0.78        // fall rate; 0 = instant drop
                property real noiseReduction: 60     // cava's own smoothing, 0..100

                // Total band height. For "mirror" this is the full span, half
                // above the centre line and half below.
                property int height: 150
                property real barOpacity: 0.55
                property int barWidth: 0             // 0 = derive from bands + width
                // Thin bars with a wide gap is what makes it read as a
                // waveform rather than a bar chart. With barWidth 0 the width
                // is derived from the output, so this gap is what actually
                // controls the thinness.
                property int barGap: 5
                property int radius: 3               // rounded bar tops

                // Only run cava while audio is actually playing. This is the
                // single biggest battery win in the whole shell.
                property bool gateOnPlayback: true

                // Only draw while at least one monitor is actually showing its
                // wallpaper. The visualizer lives below every window, so on a
                // workspace with one tiled window on it nothing is visible and
                // the work is wasted -- this is what keeps it at 0.12 % most of
                // the time. Turn it off only if you would rather it kept
                // running behind windows.
                property bool onlyWhenVisible: true

                // Seconds of silence before the cava process is stopped.
                property int idleTimeout: 5

                // "mirror" is a waveform about a centre line, thin rounded
                // pills growing up and down, with a dashed line left at rest.
                // "bars" is the classic spectrum growing out of the bottom edge.
                property string style: "mirror"

                // How far the band floats above the bottom edge, for "mirror".
                // Ignored by "bars", which must touch the edge it grows from.
                property int offset: 280
            }

            // =============================================================
            // wallpaper
            //
            // hyprpaper remains the daemon that draws it and
            // ~/.config/hypr/wallpaper.conf remains the single source of truth
            // for the path. This section only records preferences about how
            // the picker behaves.
            // =============================================================
            property JsonObject wallpaper: JsonObject {
                property string directory: Quickshell.env("HOME") + "/media/pictures/wallpapers"
                property bool perMonitor: false
                property bool random: false
                property int randomInterval: 30      // minutes, 0 = off

                // Derive the desktop accent colours from the wallpaper and
                // feed them through theme-switch. See services/Theme.qml.
                property bool deriveAccents: false
            }

            // =============================================================
            // performance — the profile, plus the automatic behaviours it
            // implies. Performance.qml turns these into the live switches the
            // rest of the shell reads.
            // =============================================================
            property JsonObject performance: JsonObject {
                // "saver" | "balanced" | "visual"
                property string profile: "balanced"

                // Drop to the saver profile automatically when the laptop is
                // unplugged. Overridden by an explicit profile change.
                property bool autoSaverOnBattery: true

                // Keep the audio visualizer running on battery, at the reduced
                // frame rate and band count rather than not at all. Choosing
                // the saver profile by hand still switches it off.
                property bool visualizerOnBattery: true

                // Suspend expensive shell effects while a window is
                // fullscreen. Distinct from desktop.hideOnFullscreen: this one
                // stops work, that one only hides pixels.
                property bool gameMode: true
            }
        }
    }

    // Collapse a burst of property changes into one write. 400 ms is long
    // enough to cover a slider drag and short enough that a settings change
    // followed immediately by a crash is not lost.
    Timer {
        id: writeDebounce

        interval: 400
        onTriggered: file.writeAdapter()
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    // Force an immediate save, skipping the debounce. Call before anything
    // that ends the process -- logout, shell restart -- so a change made in
    // the last 400 ms still lands.
    function flush() {
        writeDebounce.stop();
        file.writeAdapter();
    }

    // Read one widget's saved geometry, falling back to the supplied default.
    // Returns a copy, so a caller mutating the result cannot corrupt the
    // stored layout in place (a var property does not notice in-place edits,
    // which would silently desync the file from the UI).
    function widgetGeometry(id, fallback) {
        const layout = adapter.desktop.widgetLayout;
        if (layout && layout[id])
            return JSON.parse(JSON.stringify(layout[id]));
        return fallback;
    }

    // Write one widget's geometry back. Rebuilds the whole object because a
    // `var` property only emits its change signal on assignment, never on an
    // in-place mutation -- the same reason Lucid's Cava rebuilds its demands
    // map rather than editing it.
    function setWidgetGeometry(id, geometry) {
        const next = {};
        const layout = adapter.desktop.widgetLayout || {};
        for (const key in layout) next[key] = layout[key];
        next[id] = geometry;
        adapter.desktop.widgetLayout = next;
    }
}
