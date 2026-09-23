pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// Matugen — how the wallpaper becomes a palette.
// =============================================================================
// `theme-switch auto` no longer derives colours itself. It hands the wallpaper
// to matugen, which implements Google's Material Color Utilities, and maps the
// Material You scheme that comes back onto the nine house colours every part of
// this desktop already speaks. This service is the Settings UI's window onto
// the three knobs that derivation has.
//
// IT DRIVES theme-switch, IT DOES NOT REPLACE IT  (same rule as ThemeCatalogue)
//   Reading options is `theme-switch --matugen --json`. Changing one is
//   `theme-switch --matugen <value>`, which persists it AND re-applies the
//   active theme in the same run -- so a change here rethemes ghostty, waybar,
//   mako, GTK and this shell in one pass, exactly as the CLI would. Nothing in
//   this file knows what a colour is.
//
// WHY THE OPTIONS ARE READ BACK RATHER THAN ASSUMED
//   theme-switch clamps contrast, rejects unknown schemes and falls back to a
//   default when its state file is corrupt. Echoing what we sent would show a
//   value the engine is not using; re-reading shows the truth.
//
// WHY THERE IS AN `installed` FLAG
//   matugen is a separate binary and may not be there. theme-switch keeps its
//   old hand-rolled derivation as a fallback, so `auto` still works -- it just
//   works worse, and the UI says so rather than silently offering knobs that
//   do nothing. `just theme-install-matugen` is the fix.
// =============================================================================

Singleton {
    id: root

    // --- state read back from theme-switch --------------------------------
    property bool installed: false
    property string scheme: "scheme-tonal-spot"
    property string mode: "dark"
    property real contrast: 0.0
    property string prefer: "saturation"

    // [{ id, desc }] — the algorithm list and the seed-preference list, both
    // supplied by theme-switch so this file never goes stale when one is added.
    property var schemes: []
    property var preferences: []

    property bool loaded: false
    readonly property bool busy: applyProc.running

    signal applied(bool ok)

    // Human-readable description of whatever is currently selected, for the
    // subtitle under the picker.
    readonly property string schemeDesc: {
        for (const s of root.schemes)
            if (s.id === root.scheme) return s.desc;
        return "";
    }

    function shortName(id) {
        return String(id).replace("scheme-", "");
    }

    // --- reading -----------------------------------------------------------

    Process {
        id: readProc

        command: ["theme-switch", "--matugen", "--json"]
        running: true

        // The whole document arrives as one JSON blob; collect and parse once.
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(readProc.stdout.text);
                    root.installed = d.installed === true;
                    root.scheme = d.options.scheme;
                    root.mode = d.options.mode;
                    root.contrast = d.options.contrast;
                    root.prefer = d.options.prefer;
                    root.schemes = d.schemes || [];
                    root.preferences = d.prefer || [];
                    root.loaded = true;
                } catch (e) {
                    console.warn("[matugen] could not read options:", e);
                }
            }
        }
    }

    function refresh() {
        if (!readProc.running) readProc.running = true;
    }

    // --- writing -----------------------------------------------------------
    // Every setter funnels through here. One argument at a time is deliberate:
    // theme-switch re-applies the whole desktop per invocation, so batching two
    // changes into one call would be faster but would also mean a slider drag
    // could queue a dozen full rethemes. The UI commits on release instead.

    function set(...args) {
        if (applyProc.running) return false;
        applyProc.command = ["theme-switch", "--matugen"].concat(args.map(String));
        applyProc.running = true;
        return true;
    }

    function setScheme(id) { return root.set(id); }
    function setMode(m) { return root.set(m); }
    function setPrefer(p) { return root.set(p); }
    function setContrast(v) { return root.set("contrast", v.toFixed(2)); }

    Process {
        id: applyProc

        running: false

        onExited: (code) => {
            const ok = code === 0;
            if (!ok) console.warn("[matugen] theme-switch --matugen exited", code);
            // Re-read rather than trusting what we asked for: theme-switch is
            // free to clamp or reject it.
            root.refresh();
            root.applied(ok);
        }
    }
}
