pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// =============================================================================
// Theme — the shell's colours, read from the existing theme-switch system.
// =============================================================================
// THIS IS NOT A SECOND THEME SYSTEM. ~/.local/bin/theme-switch remains the one
// source of truth for what the desktop looks like; it already retheme's
// ghostty, bat, btop, waybar, wofi, wlogout, mako, tmux and the Hyprland border
// gradient. This file adds Quickshell as one more consumer of the same palette.
//
// THE CONTRACT
//   theme-switch writes ~/.config/quickshell/theme.json on every switch:
//
//     {
//       "name": "mint",
//       "desc": "the original custom palette ...",
//       "bg": "#121418", "surface": "#1b2527", "surface2": "#203332",
//       "border": "#3b4a4d", "text": "#f4f7fa", "muted": "#bec7d0",
//       "a1": "#8ee3c1", "a2": "#f4c47b", "a3": "#ff9b85"
//     }
//
//   Those nine colours are exactly the nine theme-switch already defines per
//   theme -- nothing new was invented for Quickshell, so a theme can never look
//   right in the terminal and wrong in the shell.
//
//   `just theme catppuccin` and the Settings GUI both go through theme-switch,
//   so both end up here. There is no path that changes the shell's colours
//   without changing everything else's.
//
// LIVE RELOAD
//   watchChanges means a theme switch repaints the running shell with no
//   restart. theme-switch does not need to know Quickshell exists beyond
//   writing the file.
//
// FALLBACK
//   If theme.json is missing -- first run, or theme-switch has not been
//   extended yet -- the mint palette below is used. The shell is never
//   colourless, and a broken theme file cannot make it unreadable.
// -----------------------------------------------------------------------------

Singleton {
    id: root

    // -----------------------------------------------------------------
    // Core palette
    //
    // Each reads from the file and falls back to mint. Written as explicit
    // properties rather than a loop over the JSON so that a typo in the file
    // is a visible wrong colour rather than an undefined binding.
    // -----------------------------------------------------------------

    readonly property string name: adapter.name || "mint"

    readonly property color bg: adapter.bg || "#121418"             // deepest ground
    readonly property color surface: adapter.surface || "#1b2527"   // cards
    readonly property color surface2: adapter.surface2 || "#203332" // raised / hover
    readonly property color border: adapter.border || "#3b4a4d"
    readonly property color text: adapter.text || "#f4f7fa"
    readonly property color muted: adapter.muted || "#bec7d0"       // secondary text

    readonly property color accent: adapter.a1 || "#8ee3c1"         // primary / good
    readonly property color accent2: adapter.a2 || "#f4c47b"        // warning
    readonly property color accent3: adapter.a3 || "#ff9b85"        // critical

    // Semantic aliases. Using these rather than accent2/accent3 directly keeps
    // intent readable at the call site, and means a future theme could break
    // the warning colour away from the second accent without touching callers.
    readonly property color success: root.accent
    readonly property color warning: root.accent2
    readonly property color error: root.accent3

    // -----------------------------------------------------------------
    // Derived colours
    //
    // Computed rather than stored so every theme gets them for free and they
    // can never drift from the core nine.
    // -----------------------------------------------------------------

    // Panel grounds, with the alpha the Settings appearance section asks for.
    // Applied to any surface that sits over the wallpaper.
    function panel(opacity) {
        return Qt.rgba(root.bg.r, root.bg.g, root.bg.b, opacity);
    }

    function card(opacity) {
        return Qt.rgba(root.surface.r, root.surface.g, root.surface.b, opacity);
    }

    // A translucent wash of any colour -- hover states, selection fills,
    // slider troughs. Cheaper and more consistent than hand-picking a shade
    // per theme.
    function wash(colour, alpha) {
        return Qt.rgba(colour.r, colour.g, colour.b, alpha);
    }

    // Text that sits ON an accent-filled surface. Accents in every one of the
    // nine themes are light pastels, so near-black is correct for all of them;
    // the luminance test is here so a future dark accent still gets readable
    // text rather than silently failing contrast.
    function onAccent(colour) {
        const luminance = 0.299 * colour.r + 0.587 * colour.g + 0.114 * colour.b;
        return luminance > 0.55 ? root.bg : root.text;
    }

    // Standard states, so every control in the shell highlights identically.
    readonly property color hover: root.wash(root.text, 0.07)
    readonly property color pressed: root.wash(root.text, 0.12)
    readonly property color selected: root.wash(root.accent, 0.16)
    readonly property color separator: root.wash(root.border, 0.5)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)

    // True once the real file has been read, as opposed to the fallbacks
    // above being in use. Nothing should gate rendering on this -- the
    // fallback is a valid palette -- but the Settings UI uses it to say
    // whether theme-switch has been wired up yet.
    readonly property bool fromDisk: file.loaded && !!adapter.name

    // -----------------------------------------------------------------
    // Backing file
    // -----------------------------------------------------------------

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.config/quickshell/theme.json"

        // Read before the first frame, so the shell never paints in fallback
        // colours and then snaps to the real ones.
        preload: true

        // A missing file is the expected state on a fresh install, not an
        // error worth logging on every launch.
        printErrors: false

        // theme-switch rewrites this file; repaint when it does.
        watchChanges: true
        onFileChanged: file.reload()

        // Read-only from the shell's side. Changing a colour means changing
        // the theme, which means going through theme-switch -- never writing
        // here, which would be overwritten on the next switch anyway.
        adapter: JsonAdapter {
            id: adapter

            property string name: ""
            property string desc: ""
            property string bg: ""
            property string surface: ""
            property string surface2: ""
            property string border: ""
            property string text: ""
            property string muted: ""
            property string a1: ""
            property string a2: ""
            property string a3: ""
        }
    }
}
