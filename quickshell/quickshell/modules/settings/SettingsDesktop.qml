import QtQuick
import Quickshell
import qs

// =============================================================================
// Settings — Desktop.
// =============================================================================
// What is drawn on the wallpaper, under every window. Per-widget enablement
// lives here; where each one sits is decided by dragging it on the desktop
// rather than by typing coordinates into a form.
// =============================================================================

Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    SettingsGroup {
        width: parent.width
        title: "WALLPAPER"

        SettingRow {
            width: parent.width
            label: "Current"
            description: Wallpaper.current === "" ? "none set" : Wallpaper.name
            Button {
                text: "Browse"
                variant: "soft"
                onClicked: {
                    Shell.close("settings");
                    Shell.open("wallpaper");
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Folder"
            description: Settings.wallpaper.directory + " · " + Wallpaper.count + " images"
        }

        SettingRow {
            width: parent.width
            label: "Derive colours from the wallpaper"
            description: "Switches the desktop to the `auto` theme and re-derives it whenever the wallpaper changes. Accent hues come from the image; contrast is enforced to WCAG AA so it stays readable."
            Toggle {
                checked: Theme.name === "auto"
                onToggled: (v) => {
                    if (v) ThemeCatalogue.apply("auto");
                    else ThemeCatalogue.apply("mint");
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "WALLPAPER BEHAVIOUR"

        SettingRow {
            width: parent.width
            label: "Change automatically"
            description: "Picks a different image from the folder at an interval."
            Toggle {
                checked: Settings.wallpaper.random
                onToggled: (v) => Settings.wallpaper.random = v
            }
        }

        SettingRow {
            width: parent.width
            enabled: Settings.wallpaper.random
            label: "Interval"
            Row {
                spacing: Appearance.sm
                Text {
                    text: Settings.wallpaper.randomInterval + " min"
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 200
                    enabled: Settings.wallpaper.random
                    value: (Settings.wallpaper.randomInterval - 5) / 175
                    onMoved: (v) => Settings.wallpaper.randomInterval = Math.round((5 + v * 175) / 5) * 5
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Shuffle now"
            description: Wallpaper.count + " images in the folder"
            Button {
                text: "Random"
                icon: "refresh"
                variant: "soft"
                enabled: Wallpaper.count > 1 && !Wallpaper.applying
                onClicked: Wallpaper.random()
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "WIDGETS"
        subtitle: "Drag them on the desktop to reposition"

        SettingRow {
            width: parent.width
            label: "Clock"
            description: "Time and date"
            Toggle {
                checked: Settings.desktop.clock
                enabled: Settings.features.widgets
                onToggled: (v) => Settings.desktop.clock = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Media"
            description: "Album art and transport for whatever is playing"
            Toggle {
                checked: Settings.desktop.media
                enabled: Settings.features.widgets
                onToggled: (v) => Settings.desktop.media = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Audio visualizer"
            description: "Spectrum bars along the bottom edge"
            Toggle {
                checked: Settings.desktop.visualizer
                enabled: Settings.features.widgets && Settings.features.musicVisualizer
                onToggled: (v) => Settings.desktop.visualizer = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Calendar"
            description: "The current month, on the wallpaper"
            Toggle {
                checked: Settings.desktop.calendar
                enabled: Settings.features.widgets && Settings.features.calendar
                onToggled: (v) => Settings.desktop.calendar = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Network"
            description: "Connection name and signal strength"
            Toggle {
                checked: Settings.desktop.network
                enabled: Settings.features.widgets
                onToggled: (v) => Settings.desktop.network = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Processor"
            description: "A ring gauge of CPU load"
            Toggle {
                checked: Settings.desktop.cpu
                enabled: Settings.features.widgets
                onToggled: (v) => Settings.desktop.cpu = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Memory"
            description: "A ring gauge of RAM in use"
            Toggle {
                checked: Settings.desktop.ram
                enabled: Settings.features.widgets
                onToggled: (v) => Settings.desktop.ram = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Battery"
            description: "Charge and time remaining"
            enabled: Settings.features.widgets && Performance.hasBattery
            Toggle {
                checked: Settings.desktop.battery
                enabled: Settings.features.widgets && Performance.hasBattery
                onToggled: (v) => Settings.desktop.battery = v
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "BEHAVIOUR"

        SettingRow {
            width: parent.width
            label: "Hide widgets when a window is fullscreen"
            description: "Keeps a clock from floating over a video. Separate from Game Mode, which stops the work rather than hiding the pixels."
            Toggle {
                checked: Settings.desktop.hideOnFullscreen
                onToggled: (v) => Settings.desktop.hideOnFullscreen = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Snap to grid"
            description: "Aligns widgets while dragging, so a hand-placed layout still looks composed."
            Toggle {
                checked: Settings.desktop.snapToGrid
                onToggled: (v) => Settings.desktop.snapToGrid = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Arrange widgets"
            description: "Lifts the widgets above your windows so they can be dragged. Click the desktop or press Escape when done."
            Button {
                text: "Arrange"
                variant: "soft"
                enabled: Settings.features.widgets && !!Shell.widgets
                onClicked: {
                    // Close Settings first -- arrange mode raises the widget
                    // layer to Overlay, and this window would be on top of it.
                    Shell.closeAll();
                    if (Shell.widgets) Shell.widgets.edit();
                }
            }
        }

        SettingRow {
            width: parent.width
            label: "Reset widget positions"
            description: "Puts every widget back where it started."
            Button {
                text: "Reset"
                variant: "soft"
                enabled: Settings.features.widgets
                onClicked: Settings.desktop.widgetLayout = ({})
            }
        }
    }
}
