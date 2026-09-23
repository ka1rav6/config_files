import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// Settings — Appearance.
// =============================================================================
// The theme picker is the headline: `just theme catppuccin` becomes a click.
//
// IT DRIVES theme-switch, IT DOES NOT REPLACE IT
//   Picking a theme here runs `theme-switch <name>`, exactly as the Justfile
//   recipe does. That one command rethemes ghostty, bat, btop, waybar, wofi,
//   wlogout, mako, tmux, the Hyprland border gradient AND Quickshell -- so the
//   GUI cannot possibly leave the desktop half-themed, and the CLI cannot
//   possibly disagree with the GUI. There is one source of truth and it is not
//   this file.
//
//   The shell repaints on its own once theme-switch writes
//   ~/.config/quickshell/theme.json, because services/Theme.qml watches it.
//   Nothing here pushes colours into the shell.
//
// THE `auto` THEME, AND THE MATUGEN SECTION UNDER IT
//   `auto` derives its palette from the current wallpaper using matugen --
//   Google's Material Color Utilities -- and then maps the Material You scheme
//   onto the nine house colours, re-checking every one against WCAG before it
//   is used. The MATUGEN group below exposes the three knobs that derivation
//   has: which algorithm, dark or light, and how much contrast.
//
//   Those knobs only affect `auto`. Catppuccin, Gruvbox and the rest are
//   hand-picked upstream palettes; re-deriving them from a seed colour would
//   replace them with something merely Catppuccin-flavoured, so theme-switch
//   does not. Changing a knob still rethemes everything, because matugen also
//   writes the GTK3/GTK4 CSS for whichever theme is active.
// =============================================================================

Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    // --- theme -----------------------------------------------------------
    property string applying: ""

    // Local copy of the contrast slider while it is being dragged. Committed to
    // matugen on release -- see the slider below for why.
    property real contrastDraft: Matugen.contrast

    // Step through the scheme list rather than opening a dropdown: there are
    // nine of them, each retheme is visible immediately, and comparing two
    // adjacent ones is the actual task.
    function cycleScheme(step) {
        const list = Matugen.schemes;
        if (!list || list.length === 0) return;
        let i = 0;
        for (let n = 0; n < list.length; n++)
            if (list[n].id === Matugen.scheme) { i = n; break; }
        Matugen.setScheme(list[(i + step + list.length) % list.length].id);
    }

    SettingsGroup {
        width: parent.width
        title: "THEME"
        subtitle: "Applies to the terminal, bar, notifications, window borders and this shell"

        Grid {
            width: parent.width
            columns: 3
            spacing: Appearance.sm

            readonly property real cell: (width - spacing * 2) / 3

            Repeater {
                model: ThemeCatalogue.themes

                ThemeSwatch {
                    required property var modelData

                    width: parent.cell
                    theme: modelData
                    current: Theme.name === modelData.id
                    busy: root.applying === modelData.id
                    onChosen: {
                        if (root.applying !== "") return;   // one at a time
                        root.applying = modelData.id;
                        ThemeCatalogue.apply(modelData.id);
                    }
                }
            }
        }

        Text {
            width: parent.width
            topPadding: Appearance.sm
            visible: root.applying !== ""
            text: "Applying " + root.applying + " — retheming every application…"
            color: Theme.accent
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
        }
    }

    Connections {
        target: ThemeCatalogue
        function onApplied(name, ok, message) {
            root.applying = "";
            if (!ok) console.warn("[settings] theme-switch failed:", message);
        }
    }

    // --- matugen -----------------------------------------------------------
    // Only meaningful while `auto` is the active theme, and said so rather
    // than hidden: hiding it would leave no way to set the scheme up BEFORE
    // switching to auto, which is exactly when you want to.
    SettingsGroup {
        width: parent.width
        title: "MATUGEN"
        subtitle: Matugen.installed
            ? (Theme.name === "auto"
               ? "Deriving the palette from " + Wallpaper.name
               : "Applies when the theme is set to auto")
            : "matugen is not installed — auto is using the built-in fallback"

        // The one case where nothing below will do anything. Say so once, at
        // the top, with the command that fixes it.
        SettingRow {
            width: parent.width
            visible: Matugen.loaded && !Matugen.installed
            label: "Not installed"
            description: "Run  just theme-install-matugen  in a terminal, then reopen this page."
            Button {
                text: "Recheck"
                variant: "soft"
                onClicked: Matugen.refresh()
            }
        }

        SettingRow {
            width: parent.width
            enabled: Matugen.installed
            label: "Scheme"
            description: Matugen.schemeDesc
            Row {
                spacing: Appearance.xs
                Button {
                    text: "Prev"
                    variant: "ghost"
                    enabled: Matugen.installed && !Matugen.busy
                    onClicked: root.cycleScheme(-1)
                }
                Text {
                    width: 110
                    horizontalAlignment: Text.AlignHCenter
                    text: Matugen.shortName(Matugen.scheme)
                    color: Theme.accent
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Button {
                    text: "Next"
                    variant: "ghost"
                    enabled: Matugen.installed && !Matugen.busy
                    onClicked: root.cycleScheme(1)
                }
            }
        }

        SettingRow {
            width: parent.width
            enabled: Matugen.installed
            label: "Mode"
            description: "Light mode inverts the whole desktop, not just this shell."
            Row {
                spacing: Appearance.xs
                Button {
                    text: "Dark"
                    variant: Matugen.mode === "dark" ? "accent" : "soft"
                    enabled: Matugen.installed && !Matugen.busy
                    onClicked: Matugen.setMode("dark")
                }
                Button {
                    text: "Light"
                    variant: Matugen.mode === "light" ? "accent" : "soft"
                    enabled: Matugen.installed && !Matugen.busy
                    onClicked: Matugen.setMode("light")
                }
            }
        }

        SettingRow {
            width: parent.width
            enabled: Matugen.installed
            label: "Contrast"
            description: "Material's own contrast offset. The WCAG floors apply on top of it regardless."
            Row {
                spacing: Appearance.sm
                Text {
                    text: root.contrastDraft.toFixed(2)
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    enabled: Matugen.installed && !Matugen.busy
                    // -1..1 across the track, so standard contrast is the middle.
                    value: (root.contrastDraft + 1) / 2
                    // Dragging is local only. Committing on every frame would
                    // queue a full desktop retheme per pixel of travel.
                    onMoved: (v) => root.contrastDraft = Math.round((v * 2 - 1) * 20) / 20
                    onCommitted: Matugen.setContrast(root.contrastDraft)
                }
            }
        }

        SettingRow {
            width: parent.width
            enabled: Matugen.installed
            label: "Seed colour"
            description: "Which colour in the wallpaper the scheme is built from."
            Row {
                spacing: Appearance.xs
                Repeater {
                    model: Matugen.preferences
                    Button {
                        required property var modelData
                        text: modelData.id === "less-saturation" ? "muted"
                            : modelData.id === "saturation" ? "vivid"
                            : modelData.id
                        variant: Matugen.prefer === modelData.id ? "accent" : "soft"
                        enabled: Matugen.installed && !Matugen.busy
                        onClicked: Matugen.setPrefer(modelData.id)
                    }
                }
            }
        }

        SettingRow {
            width: parent.width
            enabled: Matugen.installed
            label: "Re-derive now"
            description: "Rebuild the palette from the current wallpaper without changing a setting."
            Button {
                text: "Re-derive"
                variant: "soft"
                busy: Matugen.busy || ThemeCatalogue.busy
                enabled: Matugen.installed && !Matugen.busy && !ThemeCatalogue.busy
                onClicked: ThemeCatalogue.refreshAuto()
            }
        }

        Text {
            width: parent.width
            topPadding: Appearance.sm
            visible: Matugen.busy
            text: "Re-deriving and retheming every application…"
            color: Theme.accent
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
        }
    }

    // --- surfaces ----------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "SURFACES"

        SettingRow {
            width: parent.width
            label: "Corner radius"
            description: "Rounding of panels and cards. Controls inside scale from it."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.appearance.radius + " px"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: (Settings.appearance.radius - 4) / 24
                    onMoved: (v) => Settings.appearance.radius = Math.round(4 + v * 24)
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Transparency"
            description: "Panel background opacity. Lower values need blur to stay readable."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Math.round(Settings.appearance.opacity * 100) + "%"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: (Settings.appearance.opacity - 0.35) / 0.63
                    onMoved: (v) => Settings.appearance.opacity = 0.35 + v * 0.63
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Blur behind panels"
            description: "The compositor's most expensive effect. Turned off automatically in Battery Saver."
            Toggle {
                checked: Settings.appearance.blur
                onToggled: (v) => Settings.appearance.blur = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Shadows"
            description: "Depth under floating surfaces."
            Toggle {
                checked: Settings.appearance.shadows
                onToggled: (v) => Settings.appearance.shadows = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Density"
            description: "Tightens spacing without shrinking text."
            Row {
                spacing: Appearance.xs
                Button {
                    text: "Comfortable"
                    variant: Settings.appearance.density === "comfortable" ? "accent" : "soft"
                    onClicked: Settings.appearance.density = "comfortable"
                }
                Button {
                    text: "Compact"
                    variant: Settings.appearance.density === "compact" ? "accent" : "soft"
                    onClicked: Settings.appearance.density = "compact"
                }
            }
        }
    }

    // --- motion ------------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "MOTION"

        SettingRow {
            width: parent.width
            label: "Animation speed"
            description: "0 disables motion entirely. Every transition in the shell scales from this."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.appearance.motion <= 0 ? "off"
                        : Settings.appearance.motion.toFixed(1) + "x"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    // 0..2x mapped across the track, so 1x sits at the middle.
                    value: Settings.appearance.motion / 2
                    onMoved: (v) => Settings.appearance.motion = Math.round(v * 20) / 10
                }
            }
        }
    }

    // --- type --------------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "TYPE"

        SettingRow {
            width: parent.width
            label: "Text size"
            description: "Scales every label in the shell. For readability, not zoom."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Math.round(Settings.appearance.fontScale * 100) + "%"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    value: (Settings.appearance.fontScale - 0.8) / 0.7
                    onMoved: (v) => Settings.appearance.fontScale = 0.8 + v * 0.7
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Interface font"
            description: Settings.appearance.font + " · monospace: " + Settings.appearance.fontMono
            Button {
                text: "Reset"
                variant: "ghost"
                onClicked: {
                    Settings.appearance.font = "Inter";
                    Settings.appearance.fontMono = "JetBrainsMono Nerd Font";
                }
            }
        }
    }
}
