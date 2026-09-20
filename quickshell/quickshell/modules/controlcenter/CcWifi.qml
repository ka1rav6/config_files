import QtQuick
import qs

// =============================================================================
// Control Center — Wi-Fi page.
// =============================================================================
// Replaces ~/.config/waybar/scripts/wifi-menu.sh (167 lines of shell + flock +
// wofi). It keeps that script's one genuinely good idea -- only ask for a
// passphrase when NetworkManager does not already have one -- and drops the
// parts that were working around wofi rather than serving the user.
//
// Scanning is live only while this page is on screen; the Binding that does it
// is in ControlCenter.qml, and the moment you press back the radio stops
// scanning.
// =============================================================================

Column {
    id: root

    signal back()

    spacing: Appearance.gap

    // Which network is awaiting a passphrase. Empty means none.
    property string promptFor: ""
    property string passphrase: ""
    property string errorText: ""

    CcHeader {
        width: parent.width
        title: "Wi-Fi"
        onBack: root.back()

        Toggle {
            checked: Network.wifiEnabled
            enabled: Network.wifiHardwareEnabled
            onToggled: (v) => Network.setWifiEnabled(v)
        }
    }

    // --- hardware kill switch --------------------------------------------
    Text {
        width: parent.width
        visible: !Network.wifiHardwareEnabled
        text: "Wi-Fi is disabled by a hardware switch."
        color: Theme.warning
        font.family: Appearance.font
        font.pixelSize: Appearance.fontSmall
        wrapMode: Text.WordWrap
    }

    // --- scanning indicator ----------------------------------------------
    Row {
        width: parent.width
        visible: Network.wifiEnabled && Network.networks.length === 0
        spacing: Appearance.sm

        Text {
            text: "Searching for networks…"
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall

            SequentialAnimation on opacity {
                running: parent.parent.visible && !Appearance.motionless
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }
    }

    // --- network list ------------------------------------------------------
    Column {
        width: parent.width
        spacing: Appearance.xs
        visible: Network.wifiEnabled

        Repeater {
            // Capped rather than scrolled: a Control Center is for the network
            // you are about to join, which is almost always one of the
            // strongest few. Everything else is what nm-connection-editor is
            // for, and that is one click away in Settings.
            model: Network.networks.slice(0, 7)

            Rectangle {
                required property var modelData

                width: parent.width
                height: row.implicitHeight + Appearance.sm * 2
                radius: Appearance.radiusInner
                color: modelData.connected ? Theme.wash(Theme.accent, 0.16)
                     : netMouse.containsMouse ? Theme.hover : "transparent"

                Behavior on color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationFast }
                }

                Row {
                    id: row

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Appearance.sm
                    anchors.rightMargin: Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.sm

                    Icon {
                        name: "wifi-" + (modelData.signalStrength >= 75 ? 4
                                       : modelData.signalStrength >= 50 ? 3
                                       : modelData.signalStrength >= 25 ? 2 : 1)
                        size: Appearance.iconSize
                        color: modelData.connected ? Theme.accent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Appearance.iconSize * 2.5 - Appearance.sm * 3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            width: parent.width
                            text: modelData.name
                            color: Theme.text
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontBody
                            font.weight: modelData.connected ? Appearance.weightMedium : Appearance.weightNormal
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: modelData.connected || modelData.known
                            text: modelData.connected ? "Connected" : "Saved"
                            color: modelData.connected ? Theme.accent : Theme.muted
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontCaption
                        }
                    }

                    Icon {
                        // A padlock on anything that will want a passphrase,
                        // so it is obvious before you click which ones will
                        // stop and ask.
                        visible: Network.needsPassphrase(modelData)
                        name: "lock"
                        size: Appearance.fontSmall
                        color: Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: netMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.errorText = "";
                        if (modelData.connected) {
                            Network.disconnect();
                        } else if (Network.needsPassphrase(modelData)) {
                            root.promptFor = modelData.name;
                            root.passphrase = "";
                        } else {
                            Network.connect(modelData);
                        }
                    }
                }
            }
        }
    }

    // --- passphrase prompt --------------------------------------------------
    Card {
        width: parent.width
        visible: root.promptFor !== ""
        elevation: 0
        implicitHeight: promptColumn.implicitHeight + Appearance.md * 2

        Column {
            id: promptColumn

            anchors.fill: parent
            anchors.margins: Appearance.md
            spacing: Appearance.sm

            Text {
                width: parent.width
                text: "Password for " + root.promptFor
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                elide: Text.ElideRight
            }

            Rectangle {
                width: parent.width
                height: Appearance.controlHeight
                radius: Appearance.radiusInner
                color: Theme.wash(Theme.bg, 0.6)
                border.width: 1
                border.color: field.activeFocus ? Theme.accent : Theme.wash(Theme.border, 0.4)

                Behavior on border.color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationFast }
                }

                TextInput {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.sm
                    anchors.rightMargin: revealButton.width + Appearance.sm
                    verticalAlignment: TextInput.AlignVCenter
                    // The passphrase is masked by default and never logged,
                    // never written to settings.json, and never passed on a
                    // command line -- it goes straight into NetworkManager
                    // over D-Bus via connectWithPsk.
                    echoMode: revealButton.revealed ? TextInput.Normal : TextInput.Password
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontBody
                    selectByMouse: true
                    focus: root.promptFor !== ""
                    text: root.passphrase
                    onTextChanged: root.passphrase = text
                    onAccepted: connectButton.clicked()
                }

                Button {
                    id: revealButton

                    property bool revealed: false

                    width: Appearance.controlHeight
                    height: Appearance.controlHeight
                    anchors.right: parent.right
                    variant: "ghost"
                    icon: revealButton.revealed ? "eye-off" : "eye"
                    onClicked: revealButton.revealed = !revealButton.revealed
                }
            }

            Text {
                width: parent.width
                visible: root.errorText !== ""
                text: root.errorText
                color: Theme.error
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: Appearance.sm
                layoutDirection: Qt.RightToLeft

                Button {
                    id: connectButton

                    text: "Connect"
                    variant: "accent"
                    enabled: root.passphrase.length >= 8
                    onClicked: {
                        for (const n of Network.networks) {
                            if (n.name === root.promptFor) {
                                Network.connect(n, root.passphrase);
                                break;
                            }
                        }
                        root.promptFor = "";
                        root.passphrase = "";
                    }
                }

                Button {
                    text: "Cancel"
                    variant: "ghost"
                    onClicked: {
                        root.promptFor = "";
                        root.passphrase = "";
                        root.errorText = "";
                    }
                }
            }
        }
    }

    // --- escape hatch --------------------------------------------------------
    // Static IPs, VPNs, editing a saved profile: things a quick panel should
    // not try to be. Same reasoning as the right-click target the old waybar
    // module had.
    Button {
        width: parent.width
        variant: "ghost"
        text: "Advanced network settings"
        icon: "settings"
        onClicked: {
            Quickshell.execDetached(["nm-connection-editor"]);
            Shell.close("control-center");
        }
    }
}
