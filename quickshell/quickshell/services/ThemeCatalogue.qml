pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// ThemeCatalogue — the list of themes, and the one way to change one.
// =============================================================================
// Reads ~/.config/quickshell/themes.json, which ~/.local/bin/theme-switch
// regenerates on every apply. Adding a theme to the THEMES dict in that script
// makes it appear in Settings with no edit here -- the catalogue is derived,
// never maintained by hand.
//
// APPLYING GOES THROUGH theme-switch, NOT THROUGH THIS FILE
//   `apply()` runs the same command the Justfile does. That is the whole
//   design: theme-switch rethemes ghostty, bat, btop, waybar, wofi, wlogout,
//   mako, tmux, the Hyprland border gradient and Quickshell in one pass, with
//   its own marker-block safety and its own verification. Reimplementing any
//   part of that here would create a second source of truth and a way for the
//   GUI and the CLI to disagree.
//
//   The shell then repaints because services/Theme.qml is watching theme.json.
//   Nothing here pushes colours anywhere.
//
// IT IS SLOW, AND THAT IS FINE
//   A theme switch reloads waybar (with a restart fallback if SIGUSR2 kills
//   it), mako, Hyprland and tmux. Two to four seconds. The UI shows progress
//   rather than pretending it is instant.
// =============================================================================

Singleton {
    id: root

    readonly property string cataloguePath: Quickshell.env("HOME") + "/.config/quickshell/themes.json"

    // Emitted when a theme-switch run finishes, successfully or not.
    signal applied(string name, bool ok, string message)

    // NOT `Array.isArray(adapter.themes) ? adapter.themes : []`, WHICH WAS
    // ALWAYS FALSE.
    //
    // A `property var` on a JsonAdapter holding a JSON array reads back as a
    // list that behaves like an array -- it has `length`, `map`, `filter`,
    // `indexOf` -- but is NOT one as far as Array.isArray is concerned. With
    // themes.json loaded and holding all ten entries, the guard measured:
    //
    //     adapter.themes.length  10
    //     Array.isArray(...)     false      <-- so this returned []
    //     file.loaded            true
    //
    // so `themes` was permanently empty. The visible symptom was two things
    // that had no obvious connection to each other: the theme swatch list in
    // Settings > Appearance rendered with nothing in it (`model:
    // ThemeCatalogue.themes`), and `just theme <name>` kept working perfectly
    // -- because that path never enters QML. Together with the `apply` alias
    // shadowing fixed below, the GUI theme picker was dead at both ends: an
    // empty list, and a non-function behind each swatch.
    //
    // The copy normalises whatever the adapter hands back into a genuine
    // array, so no consumer has to care which it got. It costs one pass over
    // ten objects, re-run only when theme-switch rewrites the file.
    readonly property var themes: {
        const list = adapter.themes;
        if (!file.loaded || !list || list.length === undefined) return [];
        const out = [];
        for (let i = 0; i < list.length; i++) out.push(list[i]);
        return out;
    }
    readonly property bool busy: applyProc.running

    // --- catalogue ------------------------------------------------------

    FileView {
        id: file

        path: root.cataloguePath
        preload: true
        printErrors: false
        watchChanges: true
        onFileChanged: file.reload()

        // Missing on first run, before theme-switch has ever been run with the
        // catalogue support. Generate it rather than showing an empty picker.
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) {
                console.log("[themes] no catalogue, generating");
                generate.running = true;
            }
        }

        adapter: JsonAdapter {
            id: adapter

            // theme-switch writes { "themes": [ ... ] } rather than a bare
            // array, because JsonAdapter deserialises into named properties
            // and rejects an array at the document root outright:
            //   "Failed to deserialize json: not an object"
            property var themes: []
        }
    }

    Process {
        id: generate

        command: ["theme-switch", "--catalogue"]
        running: false
        onExited: (code) => {
            if (code === 0) file.reload();
            else console.warn("[themes] could not generate catalogue, exit", code);
        }
    }

    // --- applying --------------------------------------------------------

    property string pending: ""

    function apply(name) {
        if (applyProc.running) return false;
        root.pending = name;
        applyProc.command = ["theme-switch", name];
        applyProc.running = true;
        return true;
    }

    // `theme-switch <name>` verifies every marker block BEFORE touching
    // anything, so a failure here means nothing was changed -- the desktop is
    // never left half-themed.
    Process {
        id: applyProc

        running: false
        property string errorOutput: ""

        stderr: SplitParser {
            onRead: (line) => applyProc.errorOutput += line + "\n"
        }

        onExited: (code) => {
            const name = root.pending;
            root.pending = "";
            const ok = code === 0;
            if (!ok)
                console.warn("[themes] theme-switch", name, "exited", code, applyProc.errorOutput);
            applyProc.errorOutput = "";
            root.applied(name, ok, ok ? "" : "theme-switch exited " + code);
        }
    }

    // NO `property alias apply` HERE. IT SHADOWED THE FUNCTION ABOVE.
    //
    // This file used to end the Process block with
    //
    //     readonly property alias apply: applyProc
    //
    // which is a property named `apply` on a type that also declares
    // `function apply(name)`. The property wins, so `ThemeCatalogue.apply` was
    // the Process object and `ThemeCatalogue.apply("gruvbox")` raised
    //
    //     TypeError: Property 'apply' of object ThemeCatalogue is not a function
    //
    // -- which silently broke every caller: the theme swatches in
    // Settings > Appearance, the auto-theme switches in Settings > Desktop, and
    // the wallpaper picker's "derive colours from wallpaper" toggle. All three
    // did nothing when clicked.
    //
    // It went unnoticed because the three paths that DO work do not go through
    // this function: `just theme <name>` never enters QML at all,
    // refreshAuto() builds its own command, and apply-wallpaper.sh re-derives
    // the palette itself when `auto` is active. So the terminal worked, the
    // wallpaper hook worked, and only the GUI buttons were dead.
    //
    // The alias existed solely so `busy` and the re-entrancy guard could say
    // `apply.running`; both now say `applyProc.running` directly, which is what
    // they meant. Nothing outside this file ever read the alias.
    //
    // Re-derive the `auto` palette from the current wallpaper. Called by the
    // wallpaper picker after a change, and by the Appearance page's refresh.
    function refreshAuto() {
        if (applyProc.running) return;
        root.pending = "auto";
        applyProc.command = ["theme-switch", "auto"];
        applyProc.running = true;
    }
}
