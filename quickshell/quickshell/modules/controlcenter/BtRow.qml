import QtQuick
import qs

// One Bluetooth device. Click connects or disconnects; the trash button forgets
// a paired device, behind a confirmation because re-pairing a headset means
// putting it back into pairing mode and is genuinely annoying to undo.
Rectangle {
    id: root

    required property var device

    property bool confirmingForget: false

    readonly property bool paired: !!(device && (device.paired || device.bonded))
    readonly property bool connected: !!(device && device.connected)
    readonly property string label: device ? (device.deviceName || device.name || device.address) : ""

    height: content.implicitHeight + Appearance.sm * 2
    radius: Appearance.radiusInner
    color: root.connected ? Theme.wash(Theme.accent, 0.16)
         : mouse.containsMouse ? Theme.hover : "transparent"

    Behavior on color {
        enabled: !Appearance.motionless
        ColorAnimation { duration: Appearance.durationFast }
    }

    Row {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Appearance.sm
        anchors.rightMargin: Appearance.sm
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.sm

        Icon {
            name: {
                const kind = Bluetooth.kind(root.device);
                if (kind === "audio") return "headphones";
                if (kind === "keyboard") return "terminal";
                if (kind === "phone") return "monitor";
                return "bluetooth";
            }
            size: Appearance.iconSize
            color: root.connected ? Theme.accent : Theme.muted
            anchors.verticalCenter: parent.verticalCenter

            // Pulse while pairing or connecting, so a device that takes ten
            // seconds does not look like a dead row.
            SequentialAnimation on opacity {
                running: !!(root.device && root.device.pairing) && !Appearance.motionless
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }
        }

        Column {
            width: parent.width - Appearance.iconSize * 1.25 - actions.width - Appearance.sm * 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: root.label
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
                font.weight: root.connected ? Appearance.weightMedium : Appearance.weightNormal
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: {
                    if (root.confirmingForget) return "Forget this device?";
                    if (root.device && root.device.pairing) return "Pairing…";
                    if (root.connected) {
                        // Headset battery, when the device reports it. Genuinely
                        // useful and one of the few things blueman was good for.
                        if (root.device.batteryAvailable)
                            return "Connected · " + Math.round(root.device.battery * 100) + "%";
                        return "Connected";
                    }
                    if (root.paired) return "Not connected";
                    return "";
                }
                color: root.confirmingForget ? Theme.error
                     : root.connected ? Theme.accent : Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                elide: Text.ElideRight
            }
        }

        Row {
            id: actions

            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.xs

            Button {
                visible: root.confirmingForget
                width: visible ? implicitWidth : 0
                height: Appearance.controlHeightSmall
                text: "Forget"
                variant: "danger"
                onClicked: {
                    Bluetooth.forgetDevice(root.device);
                    root.confirmingForget = false;
                }
            }

            Button {
                visible: root.paired
                width: visible ? Appearance.controlHeightSmall : 0
                height: Appearance.controlHeightSmall
                variant: "ghost"
                icon: root.confirmingForget ? "close" : "trash"
                onClicked: root.confirmingForget = !root.confirmingForget
            }
        }
    }

    // Covers everything except the action buttons, so clicking the row
    // connects while clicking the trash button does not.
    //
    // `actions` lives inside the `content` Row, which makes it neither this
    // item's parent nor its sibling -- anchoring to it is rejected at runtime
    // ("Cannot anchor to an item that isn't a parent or sibling") and the
    // MouseArea silently ends up zero-width. Its width is computed instead.
    MouseArea {
        id: mouse

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width - actions.width - Appearance.sm * 2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.confirmingForget) { root.confirmingForget = false; return; }
            if (root.connected) Bluetooth.disconnectDevice(root.device);
            else Bluetooth.connectDevice(root.device);
        }
    }

    // Drop an unconfirmed "forget" after a few seconds, so a stray click does
    // not leave a red armed button sitting there indefinitely.
    Timer {
        running: root.confirmingForget
        interval: 5000
        onTriggered: root.confirmingForget = false
    }
}
