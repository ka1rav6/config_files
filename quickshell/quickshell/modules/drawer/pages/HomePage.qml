import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

// =============================================================================
// HomePage — the drawer's first page.
// =============================================================================
//   hero       your wallpaper, darkened at the foot, with a greeting, the time
//              and the date over it
//   toggles    Wi-Fi, Bluetooth, Do not disturb, Night light, Equalizer,
//              desktop visualizer -- tap to switch, the arrow to jump to the
//              page or panel that has the details
//   playing    a strip for whatever is playing; tap it for the Media page
//   calendar   the month
//   actions    themes, wallpaper, settings, power
//
// Costs nothing while closed and almost nothing while open: the clock is at
// minute resolution (no seconds tick), the hero is a downscaled thumbnail,
// and everything else is a binding to a service that is event-driven anyway.
// =============================================================================

Column {
    id: root

    required property var drawer

    spacing: Appearance.lg

    readonly property string greeting: {
        const h = Time.now.getHours();
        if (h < 5) return "Good night";
        if (h < 12) return "Good morning";
        if (h < 17) return "Good afternoon";
        if (h < 22) return "Good evening";
        return "Good night";
    }

    // --- hero -------------------------------------------------------------------
    ClippingRectangle {
        width: parent.width
        height: 196
        radius: Appearance.radius
        color: Theme.wash(Theme.accent, 0.18)

        Image {
            anchors.fill: parent
            // The cached thumbnail when there is one: the full wallpaper is a
            // multi-megapixel decode for a 500 px card.
            source: {
                const t = Wallpaper.thumbFor(Wallpaper.current);
                return t !== "" ? "file://" + t : (Wallpaper.current !== "" ? "file://" + Wallpaper.current : "");
            }
            sourceSize.width: 640
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }

        // Shade the lower half so the text holds on any wallpaper.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.05) }
                GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.25) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.lg
            spacing: 0

            Text {
                text: root.greeting + ","
                color: Qt.rgba(1, 1, 1, 0.82)
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
            }

            Text {
                text: Quickshell.env("USER").charAt(0).toUpperCase() + Quickshell.env("USER").slice(1)
                color: "white"
                font.family: Appearance.font
                font.pixelSize: Appearance.size(22)
                font.weight: Appearance.weightBold
            }
        }

        Column {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.lg
            spacing: -4

            Text {
                anchors.right: parent.right
                text: Time.time
                color: "white"
                font.family: Appearance.font
                font.pixelSize: Appearance.size(52)
                font.weight: Appearance.weightBold
                font.letterSpacing: Appearance.trackingDisplay
                font.features: ({ "tnum": 1 })
            }

            Text {
                anchors.right: parent.right
                text: Time.longDate
                color: Qt.rgba(1, 1, 1, 0.82)
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
            }
        }

        // Uptime, top left.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Appearance.md
            visible: SysInfo.uptimeText !== ""
            width: upRow.implicitWidth + Appearance.md * 2
            height: Appearance.controlHeightSmall - 4
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.38)

            Row {
                id: upRow

                anchors.centerIn: parent
                spacing: Appearance.xs

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "clock"
                    size: Appearance.fontCaption
                    color: "white"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "up " + SysInfo.uptimeText
                    color: "white"
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                }
            }
        }
    }

    // --- toggles ------------------------------------------------------------------
    Grid {
        width: parent.width
        columns: 2
        spacing: Appearance.sm

        readonly property real cell: (width - spacing) / 2

        QuickTile {
            width: parent.cell
            icon: Network.wiredConnected ? "ethernet"
                : Network.wifiEnabled ? "wifi-" + Network.signalBars : "wifi-off"
            label: "Wi-Fi"
            detail: Network.summary
            active: Network.wifiEnabled || Network.wiredConnected
            enabled: Network.wifiHardwareEnabled
            expandable: true
            onToggled: Network.toggleWifi()
            onExpand: root.drawer.page = "network"
        }

        QuickTile {
            width: parent.cell
            icon: Bluetooth.anyConnected ? "bluetooth-connected"
                : Bluetooth.enabled ? "bluetooth" : "bluetooth-off"
            label: "Bluetooth"
            detail: Bluetooth.summary
            active: Bluetooth.enabled
            enabled: Bluetooth.available
            expandable: true
            onToggled: Bluetooth.toggle()
            onExpand: {
                Shell.open("control-center");
                if (Shell.has("control-center")) Shell.panels["control-center"].page = "bluetooth";
            }
        }

        QuickTile {
            width: parent.cell
            icon: Notifications.dnd ? "bell-off" : "bell"
            label: "Do not disturb"
            detail: Notifications.dnd ? "Popups silenced" : Notifications.count + " in history"
            active: Notifications.dnd
            onToggled: Notifications.setDnd(!Notifications.dnd)
        }

        QuickTile {
            width: parent.cell
            icon: "night-light"
            label: "Night light"
            detail: !NightLight.available ? "Unavailable"
                : NightLight.active ? NightLight.temperature + " K" : "Off"
            active: NightLight.active
            enabled: NightLight.available
            onToggled: NightLight.toggle()
        }

        QuickTile {
            width: parent.cell
            icon: "equalizer"
            label: "Equalizer"
            detail: Equalizer.enabled ? Equalizer.preset : "Off"
            active: Equalizer.enabled
            expandable: true
            onToggled: Equalizer.toggle()
            onExpand: root.drawer.page = "media"
        }

        QuickTile {
            width: parent.cell
            icon: "music"
            label: "Visualizer"
            detail: Settings.desktop.visualizer ? "On the desktop" : "Off"
            active: Settings.desktop.visualizer
            enabled: Settings.features.musicVisualizer
            onToggled: Settings.desktop.visualizer = !Settings.desktop.visualizer
        }
    }

    // --- now playing -----------------------------------------------------------------
    Rectangle {
        width: parent.width
        height: 64
        visible: Media.available && Settings.features.music
        radius: Appearance.radiusInner
        color: playMouse.containsMouse ? Theme.wash(Theme.accent, 0.12) : Theme.wash(Theme.text, 0.05)

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation { duration: Appearance.durationFast }
        }

        MouseArea {
            id: playMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.drawer.page = "media"
        }

        ClippingRectangle {
            id: miniArt

            anchors.left: parent.left
            anchors.leftMargin: Appearance.sm
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48
            radius: Appearance.radiusSmall
            color: Theme.wash(Theme.text, 0.08)

            Image {
                anchors.fill: parent
                source: Media.artUrl
                sourceSize.width: 96
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            anchors.left: miniArt.right
            anchors.leftMargin: Appearance.md
            anchors.right: miniPlay.left
            anchors.rightMargin: Appearance.sm
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: Media.title || Media.identity
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
                font.weight: Appearance.weightMedium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: Media.artist
                visible: text !== ""
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                elide: Text.ElideRight
            }
        }

        Button {
            id: miniPlay

            anchors.right: parent.right
            anchors.rightMargin: Appearance.sm
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.controlHeight
            height: Appearance.controlHeight
            icon: Media.playing ? "pause" : "play"
            variant: "soft"
            onClicked: Media.playPause()
        }
    }

    // --- calendar ------------------------------------------------------------------------
    Card {
        width: parent.width
        elevation: 0
        implicitHeight: calendar.implicitHeight + Appearance.md * 2

        Calendar {
            id: calendar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            focus: true
        }
    }

    DashActions {
        width: parent.width
    }
}
