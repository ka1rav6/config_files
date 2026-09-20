import QtQuick
import qs

// =============================================================================
// Settings — Components.
// =============================================================================
// The master switches. Every one of these maps to a `Loader { active: ... }`
// in shell.qml, so turning something off does not hide it -- the object is
// never constructed at all. No window, no timers, no service subscriptions,
// no cost.
//
// THE INDEPENDENCE GUARANTEE
//   Turning one off can never break another. They do not reference each other;
//   they all talk through singletons, and a panel that was never constructed
//   simply never registers with services/Shell.qml, so asking to open it is a
//   no-op with a clear message rather than a crash.
//
//   That is testable from the command line:
//       quickshell ipc call shell panels
//   lists exactly what exists right now.
// =============================================================================

Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    SettingsGroup {
        width: parent.width
        title: "SHELL COMPONENTS"
        subtitle: "Disabled components are never loaded, not merely hidden"

        SettingRow {
            width: parent.width
            label: "Control Center"
            description: "Quick settings panel · SUPER + A"
            Toggle {
                checked: Settings.features.controlCenter
                onToggled: (v) => Settings.features.controlCenter = v
            }
        }

        SettingRow {
            width: parent.width
            label: "On-screen display"
            description: "Volume, brightness, microphone and media indicators"
            Toggle {
                checked: Settings.features.osd
                onToggled: (v) => Settings.features.osd = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Launcher"
            description: "Application search · SUPER + SPACE. wofi remains on SUPER + S either way."
            Toggle {
                checked: Settings.features.launcher
                onToggled: (v) => Settings.features.launcher = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Dock"
            description: "Running and pinned applications"
            Toggle {
                checked: Settings.features.dock
                onToggled: (v) => Settings.features.dock = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Dashboard"
            description: "Calendar and system overview · SUPER + SHIFT + D"
            Toggle {
                checked: Settings.features.dashboard
                onToggled: (v) => Settings.features.dashboard = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Desktop widgets"
            description: "Clock, media and system readouts on the wallpaper"
            Toggle {
                checked: Settings.features.widgets
                onToggled: (v) => Settings.features.widgets = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Media controls"
            description: "MPRIS transport in the Control Center and on the desktop"
            Toggle {
                checked: Settings.features.music
                onToggled: (v) => Settings.features.music = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Audio visualizer"
            description: "Spectrum bars on the desktop · SUPER + SHIFT + B"
            Toggle {
                checked: Settings.features.musicVisualizer
                onToggled: (v) => Settings.features.musicVisualizer = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Wallpaper manager"
            description: "Picker and transitions · SUPER + SHIFT + W"
            Toggle {
                checked: Settings.features.wallpaperManager
                onToggled: (v) => Settings.features.wallpaperManager = v
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "LOCK SCREEN"
        subtitle: "SUPER + ESCAPE · hyprlock is the locker"

        SettingRow {
            width: parent.width
            label: "Use the Quickshell lock screen"
            description: "Off, and it should stay off until hypridle.conf is changed — see below. When on, it runs as its own process and authenticates through /etc/pam.d/hyprlock."
            Toggle {
                checked: Settings.features.lockScreen
                onToggled: (v) => Settings.features.lockScreen = v
            }
        }

        // This is not boilerplate caution. This exact thing went wrong, and the
        // blocker is real and is not fixable from inside the shell.
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: Settings.features.lockScreen
                ? "⚠  hypridle runs `pidof hyprlock || hyprlock --grace 5` five minutes into idle. With this locker holding the session that test fails, so hyprlock launches into an already-locked session — which is how the screen got stuck the first time. Change lock_cmd in ~/.config/hypr/hypridle.conf to ~/.local/bin/lock-session before relying on this."
                : "hyprlock is a small dedicated binary; this would be a QML scene. If the locker dies, ext-session-lock keeps the screen locked by design. SUPER + ESCAPE now starts hyprlock automatically if that happens, so it is no longer a trip to a TTY — but hyprlock simply not crashing is better."
            color: Settings.features.lockScreen ? Theme.error : Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
            leftPadding: Appearance.md
            rightPadding: Appearance.md
            bottomPadding: Appearance.sm
        }
    }

    SettingsGroup {
        width: parent.width
        title: "LEFT TO THE EXISTING TOOLS"
        subtitle: "Turned off deliberately — these jobs are already done well elsewhere"

        SettingRow {
            width: parent.width
            label: "Notification daemon"
            description: "mako is the daemon. Two notification daemons on one bus is a race, not a feature. Do-not-disturb in the Control Center drives mako's own mode system."
            enabled: false
            Toggle {
                checked: Settings.features.notifications
                enabled: false
            }
        }
    }
}
