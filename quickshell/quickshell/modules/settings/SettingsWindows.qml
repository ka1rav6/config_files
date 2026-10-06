import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// Settings — Windows.
// =============================================================================
// Three things that are all really one thing: what the desktop does with a
// window. The control cluster that hangs off a window's corner, the mouse
// gesture that pops a tiled window out of the layout, and what closing the lid
// does to the display the windows are on.
//
// WHERE EACH SETTING ACTUALLY LANDS
//   Window controls   this process, immediately. modules/windowcontrols reads
//                     Settings directly.
//   Window behaviour  the compositor's Lua state, via services/WindowPolicy.qml
//                     pushing with `hyprctl eval`. Also immediate; see that
//                     file's header for why it is a push.
//   Lid               ~/.config/hypr/scripts/lid.sh, read with jq on the next
//                     lid event. Nothing to reload, nothing to restart.
// =============================================================================

Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    // --- window controls ---------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "WINDOW CONTROLS"
        subtitle: "Close, minimize and maximize on the active window's top-right corner"

        SettingRow {
            width: parent.width
            label: "Enabled"
            description: "Hyprland has no titlebars, so these are drawn on a layer surface over "
                + "the window's corner. Input is masked to the cluster itself — everywhere else "
                + "stays click-through. Off means the surface is never created at all."
            Toggle {
                checked: Settings.windows.controls
                onToggled: (v) => Settings.windows.controls = v
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.windows.controls
            label: "Position"
            description: "Top right, on purpose — the left corner is where applications put "
                + "their own controls."
            Row {
                spacing: Appearance.xs
                Button {
                    text: "Top right"
                    variant: "accent"
                    enabled: Settings.windows.controls
                    onClicked: Settings.windows.controlsPosition = "top-right"
                }
                Button {
                    text: "Top left"
                    variant: "soft"
                    // Not implemented rather than not wanted: the whole feature
                    // exists because the macOS left corner is the wrong corner
                    // here. Left visible so the choice is legible.
                    enabled: false
                }
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.windows.controls
            label: "Show on floating windows"
            description: "Floating windows are usually something you summoned and will dismiss "
                + "with the same key. Scratchpads are excluded either way."
            Toggle {
                checked: Settings.windows.controlsOnFloating
                enabled: Settings.windows.controls
                onToggled: (v) => Settings.windows.controlsOnFloating = v
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.windows.controls
            label: "Dot size"
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.windows.controlsSize + " px"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    enabled: Settings.windows.controls
                    value: (Settings.windows.controlsSize - 9) / 9
                    onMoved: (v) => Settings.windows.controlsSize = Math.round(9 + v * 9)
                }
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.windows.controls
            label: "Inset"
            description: "Distance from the corner. Raise it if an application's own controls "
                + "sit underneath."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.windows.controlsInset + " px"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    enabled: Settings.windows.controls
                    value: Settings.windows.controlsInset / 40
                    onMoved: (v) => Settings.windows.controlsInset = Math.round(v * 40)
                }
            }
        }

        // Why the cluster is not on screen right now. This is the one piece of
        // this page that pays for itself: every "it's not working" question has
        // its answer here, in words, rather than in a log.
        SettingRow {
            width: parent.width
            label: "Status"
            description: WindowPolicy.visible
                ? "Showing on " + (WindowPolicy.active ? WindowPolicy.active.cls : "the active window")
                  + (WindowPolicy.trackingFast ? " — following at 8 Hz (floating)" : " — event-driven")
                : "Hidden: " + WindowPolicy.suppressedBecause
            Text {
                text: WindowPolicy.visible ? "visible" : "hidden"
                color: WindowPolicy.visible ? Theme.success : Theme.muted
                font.family: Appearance.fontMono
                font.pixelSize: Appearance.fontSmall
            }
        }
    }

    // --- window behaviour --------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "WINDOW BEHAVIOUR"
        subtitle: "Turning a tiled window into a floating one with the mouse"

        SettingRow {
            width: parent.width
            label: "SUPER + SHIFT + drag floats a tiled window"
            description: "Grab any tiled window with SUPER + SHIFT and the left button: it pops "
                + "out of the layout, shrinks around the pointer and follows it. Plain SUPER + "
                + "drag is untouched — a tiled window stays tiled and swaps place in the layout, "
                + "so the others reflow around it. SUPER + right-drag still resizes."
            Toggle {
                checked: Settings.windows.dragToFloat
                onToggled: (v) => Settings.windows.dragToFloat = v
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.windows.dragToFloat
            label: "Floating size"
            description: "A ceiling, as a share of the monitor. A window already smaller than "
                + "this keeps the size it had."
            Row {
                spacing: Appearance.sm
                Text {
                    text: Math.round(Settings.windows.floatScale * 100) + "%"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    enabled: Settings.windows.dragToFloat
                    value: (Settings.windows.floatScale - 0.3) / 0.6
                    onMoved: (v) => Settings.windows.floatScale =
                        Math.round((0.3 + v * 0.6) * 100) / 100
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Back to tiling"
            description: "SUPER + T tiles the focused window; SUPER + SHIFT + SPACE toggles it. "
                + "The green window-control dot does it too: it un-maximizes first if the window "
                + "is maximized, then puts it back in the layout. Keybinds, not settings — "
                + "listed here so the set is discoverable."
            Text {
                text: "SUPER + T"
                color: Theme.muted
                font.family: Appearance.fontMono
                font.pixelSize: Appearance.fontSmall
            }
        }
    }

    // --- lid ---------------------------------------------------------------
    SettingsGroup {
        width: parent.width
        title: "LAPTOP LID"
        subtitle: "logind is set to ignore the lid, which is what stops it suspending a running "
            + "job. Everything it therefore leaves undone is decided here."

        SettingRow {
            width: parent.width
            label: "Handle the lid"
            description: "Off returns the lid to doing nothing at all."
            Toggle {
                checked: Settings.lid.enabled
                onToggled: (v) => Settings.lid.enabled = v
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.lid.enabled
            label: "Keep the session on an external monitor"
            description: "Lid closed with a monitor attached: the internal panel is switched off "
                + "and everything — windows, workspaces, the lock screen — carries on out there."
            Toggle {
                checked: Settings.lid.keepSessionOnExternal
                enabled: Settings.lid.enabled
                onToggled: (v) => Settings.lid.keepSessionOnExternal = v
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.lid.enabled
            label: "Switch the internal display off"
            description: "With an external monitor attached the eDP output is disabled outright. "
                + "With no external it is only DPMS-blanked — disabling the last remaining output "
                + "is how a session gets lost, so the script never does it."
            Toggle {
                checked: Settings.lid.disableInternal
                enabled: Settings.lid.enabled
                onToggled: (v) => Settings.lid.disableInternal = v
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.lid.enabled
            label: "Lock when closed with no external monitor"
            description: "Goes through ~/.local/bin/lock-session like every other lock path, so "
                + "it can never stack a second locker on a live one."
            Toggle {
                checked: Settings.lid.lockOnClose
                enabled: Settings.lid.enabled
                onToggled: (v) => Settings.lid.lockOnClose = v
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.lid.enabled && root.cameraGuardInstalled
            label: "Disable the camera while closed"
            description: root.cameraGuardInstalled
                ? "Deauthorizes the camera's USB device, and authorizes it again when the lid "
                  + "opens. Reversible, and nothing is changed permanently."
                : "Needs a one-time root helper. Run: "
                  + "~/.config/hypr/scripts/install-camera-guard.sh"
            Toggle {
                checked: Settings.lid.disableCamera && root.cameraGuardInstalled
                enabled: Settings.lid.enabled && root.cameraGuardInstalled
                onToggled: (v) => Settings.lid.disableCamera = v
            }
        }
    }

    // ---------------------------------------------------------------------
    // Is the root camera helper present?
    //
    // Probed rather than assumed, because the answer decides whether the toggle
    // above is a setting or a lie. One `test -x` when the page opens.
    // ---------------------------------------------------------------------

    property bool cameraGuardInstalled: false

    Process {
        id: guardProbe

        command: ["test", "-x", "/usr/local/lib/hypr/camera-guard"]
        running: true
        onExited: (code) => root.cameraGuardInstalled = (code === 0)
    }
}
