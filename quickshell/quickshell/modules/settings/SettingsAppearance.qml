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
// THE `auto` THEME
//   Derives its palette from the current wallpaper: three accent hues lifted
//   from the image, transplanted onto the house saturation/value so they stay
//   legible at 11px, then raised until each clears WCAG AA against the
//   generated background. A greyscale wallpaper keeps the previous theme's
//   accents rather than inventing colour out of sensor noise. See the long
//   note in ~/.local/bin/theme-switch.
// =============================================================================

Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    // --- theme -----------------------------------------------------------
    property string applying: ""

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
