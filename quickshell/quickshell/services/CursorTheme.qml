pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

// =============================================================================
// CursorTheme — which pointer theme and size, applied live.
// =============================================================================
// Settings.cursor.theme is one of:
//   ""            leave the login default alone (XCURSOR_THEME in autostart.lua)
//   "accent:<Style>"  generated in the theme accent (scripts/cursor-gen.py) and
//                 regenerated whenever the accent changes. Styles: Fluent (a dot
//                 that morphs into each shape, with a press bounce), Circle
//                 (always the same dot, pulsing on every click), Dot, Ring,
//                 Arrow.
//
// THE CIRCLE TOGGLE
//   toggleCircle() flips between accent:Circle and whatever was in use before
//   (kept in Settings.cursor.normalTheme), from Settings › Cursor or
//   `quickshell ipc call cursor toggleCircle`.
//
// INVERTED
//   Settings.cursor.color "invert" builds the accent style in pure white
//   (QS-<Style>-invert) and has the qs-pointer plugin draw it inverted: each
//   pixel the opposite of the screen under it, like Windows' inverted pointer.
//   Without the plugin it is simply a white cursor. Installed themes are never
//   inverted. The plugin also draws the TRAIL itself, inverted the same way,
//   so it always matches the pointer: a black trail behind a black pointer on
//   a white page, a white one on a dark page (Pointer.drawsTrail; CursorFx
//   hides its own trail then). The click effect and ring stay in Quickshell's
//   layer, which cannot invert, and are drawn in black.
//   <dir name>    any installed XCursor theme
//
// APPLYING
//   hyprctl setcursor     what Hyprland draws, and what every Wayland client
//                         asking for a cursor shape gets -- live
//   gsettings             GTK apps that load the theme themselves
//   ~/.config/hypr/cursor.lua   read by autostart.lua, so the next login starts
//                         with it (XCURSOR_THEME/SIZE for apps, XWayland too)
//   Already-running XWayland apps keep their old cursor until restarted; that
//   is X11, not something this can reach.
//
// WHERE THEMES MUST LIVE
//   Ubuntu's libXcursor, which Hyprland draws with, searches only ~/.icons,
//   /usr/share/icons and /usr/share/pixmaps -- never ~/.local/share/icons. A
//   theme found only there is silently drawn as the built-in arrow.
//   ~/.icons is therefore a symlink to ~/.local/share/icons, which
//   cursor-gen.py re-creates if it goes missing.
//
// Nothing here runs unless the setting is changed or is non-default, so a user
// who never opens the Cursor page is never touched.
// =============================================================================
Singleton {
    id: root

    readonly property string choice: Settings.cursor.theme
    readonly property int size: Settings.cursor.size
    readonly property bool isAccent: root.choice.startsWith("accent:")
    readonly property string accentStyle: root.isAccent ? root.choice.slice(7) : ""
    readonly property string accentHex: String(Theme.accent).slice(1, 7).toLowerCase()

    // THE cursor colour: what the accent styles are drawn in, and what the
    // trail, click effect and ring use, so the effects always match the
    // pointer. Settings.cursor.color is "accent" (follows the theme), "white",
    // "black", or a "#rrggbb" picked from the swatches. Installed themes keep
    // their own colours; the effects still use this.
    readonly property var named: ({ white: "f4f5f7", black: "1b1d22", invert: "ffffff" })
    readonly property bool inverted: String(Settings.cursor.color) === "invert"
    // The colour as it appears in theme names: "invert" stays a word.
    readonly property string colorTag: root.inverted ? "invert" : root.colorHex
    readonly property string colorHex: {
        const c = String(Settings.cursor.color || "accent");
        if (c.startsWith("#") && c.length >= 7) return c.slice(1, 7).toLowerCase();
        if (root.named[c]) return root.named[c];
        if (c === "text") return String(Theme.text).slice(1, 7).toLowerCase();
        return root.accentHex;
    }
    readonly property color color: "#" + root.colorHex
    // What cursor-gen.py is given.
    readonly property string genColor: root.inverted ? "invert" : "#" + root.colorHex
    readonly property string fallback: Quickshell.env("XCURSOR_THEME") || "Yaru"

    // The theme Hyprland should actually be running.
    readonly property string speed: Settings.cursor.speed || "normal"
    readonly property bool fluent: root.isAccent && root.accentStyle === "Fluent"
    readonly property bool circle: root.choice === "accent:Circle"
    // Styles with a click animation (pop_<shape> cursors) and a speed.
    readonly property bool animated: root.fluent || root.circle
    readonly property string resolved: root.isAccent ? "QS-" + root.accentStyle + "-" + root.colorTag + (root.animated ? "-" + root.speed : "")
        : root.choice !== "" ? root.choice
        : root.fallback

    readonly property var accentStyles: ["Fluent", "Circle", "Dot", "Ring", "Arrow"]

    function toggleCircle() {
        if (root.circle) {
            const back = Settings.cursor.normalTheme;
            Settings.cursor.theme = back === "accent:Circle" ? "" : back;
        } else {
            Settings.cursor.normalTheme = Settings.cursor.theme;
            Settings.cursor.theme = "accent:Circle";
        }
    }

    // Previews of the accent styles in the current accent (cursor-gen.py
    // preview), keyed by style.
    function accentPreview(style) {
        return "file://" + root.previewDir + "/accent-" + style + "-" + root.colorTag + ".png?" + root.previewStamp;
    }
    property int previewStamp: 0

    Process {
        id: accentPreviewer
        command: ["python3", "-I", Quickshell.shellDir + "/scripts/cursor-gen.py", "preview", root.previewDir, root.genColor]
        onExited: root.previewStamp++
    }

    // [{ name, family, variant }] for every installed theme with cursors/,
    // generated QS-* copies excluded (they are offered as the Accent family).
    property var themes: []
    // name -> preview png path
    property var previews: ({})
    readonly property string previewDir: Quickshell.env("HOME") + "/.cache/quickshell/cursor-previews"

    readonly property var families: {
        const seen = ["Accent"];
        for (const t of root.themes)
            if (seen.indexOf(t.family) < 0) seen.push(t.family);
        return seen;
    }

    function variantsOf(family) {
        if (family === "Accent")
            return root.accentStyles.map(v => ({ name: "accent:" + v, family: "Accent", variant: v }));
        return root.themes.filter(t => t.family === family);
    }

    readonly property string currentFamily: {
        if (root.isAccent) return "Accent";
        const t = root.themes.find(x => x.name === root.resolved);
        return t ? t.family : "";
    }

    function classify(name) {
        const rules = [
            [/^Bibata-(Modern|Original)-(\w+?)(-Right)?$/, m => ["Bibata", m[1] + " " + m[2] + (m[3] ? " (left-handed)" : "")]],
            [/^phinger-cursors-(dark|light)(-left)?$/, m => ["Phinger", (m[1] === "dark" ? "Dark" : "Light") + (m[2] ? " (left-handed)" : "")]],
            [/^capitaine-cursors(-light|-white)?$/, m => ["Capitaine", m[1] ? "Light" : "Dark"]],
            [/^DMZ-(White|Black)$/, m => ["DMZ", m[1]]],
            [/^(breeze_cursors|Breeze_Light|Breeze_Snow)$/, m => ["Breeze", m[1] === "breeze_cursors" ? "Dark" : "Light"]],
            [/^(whiteglass|redglass|handhelds)$/, m => ["X11 classic", m[1]]],
        ];
        for (const [re, f] of rules) {
            const m = name.match(re);
            if (m) {
                const [family, variant] = f(m);
                return { name, family, variant };
            }
        }
        return { name, family: name, variant: "" };
    }

    // ---- discovery -----------------------------------------------------------
    function rescan() {
        if (!scanner.running) scanner.running = true;
    }

    Process {
        id: scanner
        command: ["bash", "-c",
            "for d in \"$HOME/.local/share/icons\" \"$HOME/.icons\" /usr/share/icons; do "
            + "for t in \"$d\"/*/cursors; do [ -d \"$t\" ] && basename \"$(dirname \"$t\")\"; done; "
            + "done 2>/dev/null | grep -v '^QS-' | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = this.text.split("\n").filter(n => n.length > 0);
                root.themes = names.map(n => root.classify(n));
                previewer.command = ["python3", "-I", Quickshell.shellDir + "/scripts/cursor-preview.py", root.previewDir].concat(names);
                previewer.running = true;
            }
        }
    }

    Process {
        id: previewer
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of this.text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab > 0) map[line.slice(0, tab)] = "file://" + line.slice(tab + 1);
                }
                root.previews = map;
            }
        }
    }

    // ---- generating the accent themes ------------------------------------------
    property bool generating: false

    Process {
        id: generator
        onExited: (code) => {
            root.generating = false;
            if (code === 0) root.pushNow();
            else console.warn("[cursor] cursor-gen.py failed:", code);
        }
    }

    function generate() {
        if (!root.isAccent) return;
        root.generating = true;
        generator.command = ["python3", "-I", Quickshell.shellDir + "/scripts/cursor-gen.py", root.accentStyle, root.genColor, root.speed];
        generator.running = true;
    }

    // ---- applying --------------------------------------------------------------
    // Set once the user has touched anything here this session, or when the
    // stored setting is already non-default; until then the shell leaves the
    // cursor exactly as login set it.
    property bool engaged: Settings.cursor.theme !== "" || Settings.cursor.size !== 24 || Settings.cursor.hideAfter > 0

    function apply() {
        root.engaged = true;
        debounce.restart();
    }

    Timer {
        id: debounce
        interval: 350
        onTriggered: root.isAccent ? root.generate() : root.pushNow()
    }

    function pushNow() {
        const name = root.resolved;
        const sz = String(root.size);
        runner.exec(["bash", "-c",
            "hyprctl setcursor \"$1\" \"$2\" >/dev/null; "
            // Apps launched from now on inherit Hyprland's environment, and
            // D-Bus/systemd-started ones the activation environment: both get
            // the new theme. Apps already running that load the theme
            // themselves (Chrome, XWayland) keep the old one until restarted.
            + "hyprctl eval \"hl.env('XCURSOR_THEME', '$1') hl.env('XCURSOR_SIZE', '$2')\" >/dev/null; "
            + "XCURSOR_THEME=\"$1\" XCURSOR_SIZE=\"$2\" dbus-update-activation-environment --systemd XCURSOR_THEME XCURSOR_SIZE 2>/dev/null; "
            + "gsettings set org.gnome.desktop.interface cursor-theme \"$1\" 2>/dev/null; "
            + "gsettings set org.gnome.desktop.interface cursor-size \"$2\" 2>/dev/null; true",
            "cursor", name, sz]);
        root.pushHide();
        persist.setText("-- Written by Quickshell (Settings > Cursor); read by autostart.lua at login.\n"
            + "-- Edit there, not here: this file is rewritten whenever the setting changes.\n"
            + "return { theme = \"" + name + "\", size = " + sz + " }\n");
    }

    function pushHide() {
        hideRunner.exec(["hyprctl", "eval",
            "hl.config({ cursor = { inactive_timeout = " + Math.max(0, Settings.cursor.hideAfter) + " } })"]);
    }

    Process { id: runner }
    Process { id: hideRunner }

    FileView {
        id: persist
        path: Quickshell.env("HOME") + "/.config/hypr/cursor.lua"
        blockLoading: false
        printErrors: false
    }

    // ---- reacting --------------------------------------------------------------
    Connections {
        target: Settings.cursor
        function onThemeChanged() { root.apply(); }
        function onSizeChanged() { root.apply(); }
        function onSpeedChanged() { if (root.animated) root.apply(); }
        function onColorChanged() { if (root.isAccent) root.engaged = true; }
        function onHideAfterChanged() { root.engaged = true; root.pushHide(); }
    }

    onColorTagChanged: {
        accentPreviewer.running = true;
        if (root.isAccent && root.engaged) debounce.restart();
    }

    // `hyprctl reload` re-runs looknfeel.lua, which resets inactive_timeout.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded" && Settings.cursor.hideAfter > 0)
                root.pushHide();
        }
    }

    // Press bounce: the plugin swaps in the theme's pop_<shape> cursor on a
    // click. Only Fluent and Circle have those, and it is an animation, so not
    // in saver.
    // Inverted drawing, for the white theme built for it.
    Binding {
        target: Pointer
        property: "wantInvert"
        value: root.isAccent && root.inverted
    }

    Binding {
        target: Pointer
        property: "wantPop"
        value: root.animated && Settings.cursor.press && !Performance.stopAnimations && !Performance.gameMode
    }

    Component.onCompleted: {
        root.rescan();
        accentPreviewer.running = true;
        startup.start();
    }

    // After Settings has loaded the stored values.
    Timer {
        id: startup
        interval: 1500
        // Re-assert a non-default choice at startup: Hyprland may have come up
        // with only the env default, and the accent may have changed meanwhile.
        onTriggered: {
            if (!Settings.loaded) { startup.restart(); return; }
            if (!root.engaged) return;
            if (root.isAccent) root.generate(); else root.pushNow();
        }
    }
}
