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

    // -----------------------------------------------------------------
    // Semantic colours -- STATE, not decoration.
    //
    // These used to be plain aliases: success = a1, warning = a2, error = a3.
    // That held only because the nine hand-authored palettes happen to be
    // written in that order (mint is a green 156 deg, an amber 36 deg and a
    // coral 11 deg), so the convention was carried by the data rather than by
    // the code -- and the `auto` palette broke it the moment it existed.
    //
    // `theme auto` derives a1/a2/a3 from the WALLPAPER. It enforces WCAG
    // contrast, which is the hard part, but it has no concept of what a colour
    // MEANS. Derived from wallpaper10.jpg it produced:
    //
    //     a1 #7fb5db  205 deg  blue     -> "success"
    //     a2 #7970e0  245 deg  purple   -> "warning"
    //     a3 #ccc05c   54 deg  olive    -> "error"
    //
    // so a battery at 9%, a CPU at 90%, a failed password and an armed
    // Shutdown button all rendered olive-yellow, a charging battery rendered
    // blue, and every warning was purple. Nothing was unreadable -- contrast
    // was fine -- it just no longer said anything.
    //
    // So the HUE is pinned and everything else is borrowed from the theme.
    // Saturation and lightness come from the corresponding accent, so a muted
    // palette gets muted state colours and a vivid one gets vivid ones -- mint
    // resolves to very nearly its original a1/a2/a3, because those were
    // already at these hues. Only palettes that had drifted get corrected.
    //
    // Lightness is clamped: every theme here is dark-grounded, and a state
    // colour that lands too dark stops reading against the background.
    // -----------------------------------------------------------------

    // Re-hue `source` to `hueDegrees`, keeping its saturation and lightness.
    function semantic(hueDegrees, source) {
        return Qt.hsla(hueDegrees / 360,
                       Math.max(0.35, Math.min(1.0, source.hslSaturation)),
                       Math.max(0.58, Math.min(0.78, source.hslLightness)),
                       1.0);
    }

    readonly property color success: root.semantic(145, root.accent)   // green
    readonly property color warning: root.semantic(40, root.accent2)   // amber
    readonly property color error: root.semantic(8, root.accent3)      // red

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
