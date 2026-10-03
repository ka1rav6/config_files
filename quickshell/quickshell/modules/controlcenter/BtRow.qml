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
    readonly property string address: device && device.address ? device.address : ""

    // Bluetooth.label() rather than `deviceName || name || address`, because
    // that chain cannot do what it looks like it does -- BlueZ substitutes the
    // ADDRESS into the alias for a device that has never reported a name, so
    // `name` is truthy and the row rendered a MAC address as if it were the
    // device's name. See the long comment on hasRealName() in
    // services/Bluetooth.qml.
    readonly property string label: Bluetooth.label(root.device)

    // No name of its own -- almost always a BLE beacon. The address is still
    // worth showing for these, but on the second line and labelled as what it
    // is, not impersonating a name on the first.
    readonly property bool anonymous: !!root.device && !Bluetooth.hasRealName(root.device)

    // Pairing goes out to a subprocess (it needs a BlueZ agent this shell does
    // not register), so its progress arrives on the service rather than on the
    // device object -- device.pairing only ever reflects Quickshell's own
    // pair(), which is no longer the path taken.
    readonly property bool pairing: root.address !== ""
                                    && Bluetooth.pairingAddress === root.address
    readonly property bool failed: root.address !== ""
                                   && Bluetooth.pairingErrorAddress === root.address
                                   && Bluetooth.pairingError !== ""

    // Some other device is mid-pairing: one agent, one pairing at a time.
    readonly property bool blocked: Bluetooth.pairingBusy && !root.pairing

    height: content.implicitHeight + Appearance.sm * 2
    radius: Appearance.radiusInner
    color: root.failed ? Theme.wash(Theme.error, 0.12)
         : root.connected || root.pairing ? Theme.wash(Theme.accent, 0.16)
         : mouse.containsMouse ? Theme.hover : "transparent"

    opacity: root.blocked ? 0.45 : 1.0

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
                running: (root.pairing || !!(root.device && root.device.pairing))
                         && !Appearance.motionless
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
                    if (root.pairing) return Bluetooth.pairingStatus || "Pairing…";
                    if (root.failed) return Bluetooth.pairingError;
                    if (root.device && root.device.pairing) return "Pairing…";
                    if (root.connected) {
                        // Headset battery, when the device reports it. Genuinely
                        // useful and one of the few things blueman was good for.
                        if (root.device.batteryAvailable)
                            return "Connected · " + Math.round(root.device.battery * 100) + "%";
                        return "Connected";
                    }
                    if (root.paired) return "Not connected";
                    // Unpaired. An anonymous device gets its address here --
                    // the one place it is honest -- and a named one gets told
                    // what clicking will do, since "click a row to pair" is not
                    // obvious when every other row in the panel is a toggle.
                    if (root.anonymous) return root.address + " · no name";
                    return "Click to pair";
                }
                color: root.confirmingForget || root.failed ? Theme.error
                     : root.connected || root.pairing ? Theme.accent : Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                // A failure reason is a sentence and needs the room; every
                // other state here is short enough to elide on one line.
                wrapMode: root.failed ? Text.WordWrap : Text.NoWrap
                maximumLineCount: root.failed ? 3 : 1
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
            // Clicking the row that is already pairing cancels it -- otherwise
            // a device that is never going to answer holds the only agent for
            // the full 60-second timeout.
            if (root.pairing) { Bluetooth.cancelPairing(); return; }
            if (root.blocked) return;
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
