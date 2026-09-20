import QtQuick
import Quickshell
import qs

// Settings — About. Versions and live diagnostics, so "what is actually
// running" is answerable from inside the desktop rather than from a terminal.
Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    Card {
        width: parent.width
        elevation: 0
        implicitHeight: hero.implicitHeight + Appearance.lg * 2

        Column {
            id: hero

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.lg
            spacing: Appearance.xs

            Text {
                text: "Desktop Shell"
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontHeading
                font.weight: Appearance.weightSemi
                font.letterSpacing: Appearance.trackingHeading
            }

            Text {
                width: parent.width
                text: "Quickshell presentation layer over Hyprland. The compositor owns "
                    + "behaviour — workspaces, scratchpads, window rules, keybindings — and "
                    + "this owns what you see and touch."
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "COMPONENTS"

        SettingRow {
            width: parent.width
            label: "Compositor"
            description: "Hyprland, configured in " + (Hypr.usingLua ? "Lua" : "hyprland.conf")
        }

        SettingRow {
            width: parent.width
            label: "Theme"
            description: Theme.name + (Theme.fromDisk ? "" : "  (fallback — theme-switch has not written theme.json)")
                + " · accent " + Theme.accent
        }

        SettingRow {
            width: parent.width
            label: "Outputs"
            description: Quickshell.screens.map(s => s.name).join(", ")
        }

        SettingRow {
            width: parent.width
            label: "Panels loaded"
            description: Shell.summary
        }
    }

    SettingsGroup {
        width: parent.width
        title: "SERVICES"

        SettingRow {
            width: parent.width
            label: "Audio"
            description: Audio.sinkReady
                ? Audio.sinkName + " · " + Math.round(Audio.volume * 100) + "%"
                : "no output device"
        }

        SettingRow {
            width: parent.width
            label: "Network"
            description: Network.summary
        }

        SettingRow {
            width: parent.width
            label: "Bluetooth"
            description: Bluetooth.summary
        }

        SettingRow {
            width: parent.width
            label: "Media"
            description: Media.available
                ? Media.identity + " — " + (Media.playing ? "playing" : "paused")
                : "no player"
        }

        SettingRow {
            width: parent.width
            label: "Visualizer"
            description: Cava.status
        }
    }

    SettingsGroup {
        width: parent.width
        title: "COMMAND LINE"
        subtitle: "Everything here is reachable without the GUI"

        SettingRow {
            width: parent.width
            label: "just theme <name>"
            description: "Apply a theme. `just theme auto` derives one from the wallpaper; `just theme-palette` previews it."
        }

        SettingRow {
            width: parent.width
            label: "just qs-status / qs-ipc"
            description: "Is the shell alive, and what can keybindings call?"
        }

        SettingRow {
            width: parent.width
            label: "just qs-debug"
            description: "Run the shell in the foreground with errors on stderr — the way to diagnose a QML change."
        }

        SettingRow {
            width: parent.width
            label: "just qs-backup / qs-restore"
            description: "Snapshot and roll back every config this shell touches."
        }
    }
}
