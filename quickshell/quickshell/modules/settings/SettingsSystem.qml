import QtQuick
import Quickshell
import qs

// Settings — System. Shortcuts out to the tools that already do these jobs
// properly, rather than reimplementing them. A settings app that tries to own
// everything ends up owning nothing well.
Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    SettingsGroup {
        width: parent.width
        title: "DISPLAYS"

        SettingRow {
            width: parent.width
            label: "Monitor layout"
            description: {
                const names = Quickshell.screens.map(s =>
                    s.name + " " + s.width + "x" + s.height);
                return names.join("  ·  ");
            }
        }

        SettingRow {
            width: parent.width
            label: "Arrangement"
            description: "Mirror and position are bound to SUPER+SHIFT+X and SUPER+CTRL+SHIFT+arrows, handled by ~/.config/hypr/scripts/display-layout.sh. Resolution and scale live in ~/.config/hypr/monitors.lua."
            Button {
                text: "Toggle mirror"
                variant: "soft"
                onClicked: Quickshell.execDetached(
                    [Quickshell.env("HOME") + "/.config/hypr/scripts/display-layout.sh", "toggle-mirror"])
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "EXTERNAL TOOLS"
        subtitle: "These do their jobs better than a panel could"

        SettingRow {
            width: parent.width
            label: "Network connections"
            description: "Static IPs, VPNs, editing saved profiles"
            Button {
                text: "Open"
                variant: "soft"
                onClicked: {
                    Quickshell.execDetached(["nm-connection-editor"]);
                    Shell.close("settings");
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Audio routing"
            description: "Per-application volume, input/output routing, profiles"
            Button {
                text: "Open"
                variant: "soft"
                onClicked: {
                    Quickshell.execDetached(["pavucontrol"]);
                    Shell.close("settings");
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Bluetooth manager"
            description: "Full device management, file transfer"
            Button {
                text: "Open"
                variant: "soft"
                onClicked: {
                    Quickshell.execDetached(["blueman-manager"]);
                    Shell.close("settings");
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "CONFIGURATION FILES"
        subtitle: "Everything here is editable by hand; the GUI is a front-end, not a replacement"

        SettingRow {
            width: parent.width
            label: "Shell settings"
            description: "~/.config/quickshell/settings.json — watched, so edits apply live"
        }

        SettingRow {
            width: parent.width
            label: "Compositor"
            description: "~/.config/hypr/*.lua — keybindings, workspaces, scratchpads, monitors. Not touched by this app."
        }

        SettingRow {
            width: parent.width
            label: "Themes"
            description: "~/.local/bin/theme-switch — the single source of truth for colours. `just theme <name>` and this app run the same command."
        }

        SettingRow {
            width: parent.width
            label: "Reset shell settings"
            description: "Restores every option in this app to its default. Themes and compositor config are unaffected."
            Button {
                text: "Reset"
                variant: "danger"
                onClicked: resetConfirm.armed = !resetConfirm.armed
            }
        }

        SettingRow {
            id: resetConfirm

            property bool armed: false

            width: parent.width
            visible: armed
            label: "Are you sure?"
            description: "This cannot be undone. The shell will reload."
            Button {
                text: "Yes, reset everything"
                variant: "danger"
                onClicked: {
                    Quickshell.execDetached(["sh", "-c",
                        "rm -f ~/.config/quickshell/settings.json && ~/.local/bin/qs-reload"]);
                }
            }
        }
    }
}
