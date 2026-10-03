import QtQuick
// Quickshell, for execDetached() -- see the handler that opens the external
// tool below. WITHOUT THIS IMPORT the `Quickshell` name is simply undefined,
// the click handler dies on a ReferenceError, and the button does nothing at
// all with no visible error: the qmldir header's warning about singletons,
// one level up.
import Quickshell
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
//
// A SAVED NETWORK IS NOT A FINISHED NETWORK, which this page used to assume.
//   "Only prompt when NetworkManager has no passphrase" is right up until the
//   router's password changes. From then on the stored secret is wrong, the
//   row is still `known` so it never prompts, the join fails with no visible
//   error, and there is no way from here to type the new key or to throw the
//   old one away -- the network is simply unjoinable from the shell. So every
//   saved row now carries the two actions that fix it:
//     key    re-enter the passphrase (an edit of the saved profile)
//     trash  forget it entirely (delete the profile)
//   and a failed join finally says why it failed instead of doing nothing
//   visible at all. See services/Network.qml for both halves.
// =============================================================================

Column {
    id: root

    signal back()

    spacing: Appearance.gap

    // Which network is awaiting a passphrase. Empty means none.
    property string promptFor: ""

    // Whether that prompt is REPLACING a stored passphrase rather than asking
    // for a first one. Only the wording and the button label differ -- the
    // call underneath is the same connectWithPsk either way, because that is
    // an in-place profile edit when settings already exist.
    property bool promptIsChange: false

    property string passphrase: ""

    // Which network is awaiting a "yes really, forget it". Empty means none.
    property string confirmForget: ""

    // Set to an SSID this panel cannot join on its own. An enterprise network
    // needs an identity, a CA certificate and an inner auth method, none of
    // which belong in a one-field popover -- saying so beats a password box
    // that connectWithPsk throws away.
    property string needsEditor: ""

    // The list is rebuilt constantly while scanning, so the panel's own state
    // is held as an SSID string rather than an object reference -- a captured
    // WifiNetwork can be replaced out from under us between click and confirm.
    // This is the one place that turns a name back into the live object.
    function networkNamed(name) {
        for (const n of Network.networks) {
            if (n.name === name) return n;
        }
        return null;
    }

    function openPrompt(name, isChange) {
        root.confirmForget = "";
        root.needsEditor = "";
        root.promptFor = name;
        root.promptIsChange = isChange;
        root.passphrase = "";
        Network.clearError();
    }

    function closePrompt() {
        root.promptFor = "";
        root.promptIsChange = false;
        root.passphrase = "";
    }

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

    // --- why the last join failed -----------------------------------------
    // Sits above the list rather than inside the passphrase card, because the
    // failure that matters most happens when no card is open: clicking a saved
    // network whose stored key has gone stale. Before this, that was a click
    // that did nothing at all.
    Rectangle {
        width: parent.width
        visible: Network.lastError !== ""
        height: visible ? errorRow.implicitHeight + Appearance.sm * 2 : 0
        radius: Appearance.radiusInner
        color: Theme.wash(Theme.error, 0.14)

        Row {
            id: errorRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Appearance.sm
            anchors.rightMargin: Appearance.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.sm

            Column {
                width: parent.width - retryButton.width - dismissButton.width - Appearance.sm * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    width: parent.width
                    text: Network.lastErrorSsid === "" ? "Connection failed"
                        : "Couldn't join " + Network.lastErrorSsid
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSmall
                    font.weight: Appearance.weightMedium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: Network.lastError
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    wrapMode: Text.WordWrap
                }
            }

            Button {
                id: retryButton

                // Offered only when a new passphrase could plausibly be the
                // fix AND this network can actually take one -- an EAP network
                // would get a box that connectWithPsk refuses outright.
                visible: Network.lastErrorWasAuth
                    && Network.canUsePassphrase(root.networkNamed(Network.lastErrorSsid))
                width: visible ? implicitWidth : 0
                text: "Enter password"
                variant: "soft"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    const n = root.networkNamed(Network.lastErrorSsid);
                    root.openPrompt(Network.lastErrorSsid, !!n && n.known);
                }
            }

            Button {
                id: dismissButton

                icon: "close"
                variant: "ghost"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Network.clearError()
            }
        }
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

                // DECLARED BEFORE THE CONTENT, unlike everywhere else in this
                // shell, and that ordering is load-bearing: later siblings sit
                // on top, so a row-filling MouseArea written last would eat
                // the clicks meant for the key and trash buttons. The labels
                // and icons above it do not accept mouse events, so a click on
                // the row body still falls through to here.
                MouseArea {
                    id: netMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Network.clearError();
                        root.confirmForget = "";
                        root.needsEditor = "";
                        if (modelData.connected) {
                            Network.disconnect();
                        } else if (Network.needsPassphrase(modelData)) {
                            // A secured network we have never saved. If it is
                            // not a PSK network there is no point opening a
                            // box connectWithPsk will refuse -- say so and
                            // point at the editor that can do it.
                            if (Network.canUsePassphrase(modelData))
                                root.openPrompt(modelData.name, false);
                            else
                                root.needsEditor = modelData.name;
                        } else {
                            Network.connect(modelData);
                        }
                    }
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
                        id: signalIcon

                        // Via the service, not modelData.signalStrength
                        // directly: that property is a 0.0-1.0 fraction, so
                        // comparing it against 75/50/25 here always picked the
                        // weakest icon.
                        name: "wifi-" + Network.signalBarsFor(modelData)
                        size: Appearance.iconSize
                        color: modelData.connected ? Theme.accent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        // Everything to the right of the name is optional --
                        // the padlock only on unsaved secured networks, the
                        // two action buttons only on saved ones -- and a Row
                        // gives no gap to a hidden child, so the spacing is
                        // counted per VISIBLE trailing item rather than as a
                        // fixed four. Getting that wrong does not misplace
                        // anything, it just elides long SSIDs earlier than it
                        // needs to.
                        readonly property real trailing:
                              (lockIcon.visible ? lockIcon.width + Appearance.sm : 0)
                            + (changeButton.visible ? changeButton.width + Appearance.sm : 0)
                            + (forgetButton.visible ? forgetButton.width + Appearance.sm : 0)

                        width: Math.max(0, parent.width - signalIcon.width
                                           - Appearance.sm - trailing)
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
                        id: lockIcon

                        // A padlock on anything that will want a passphrase,
                        // so it is obvious before you click which ones will
                        // stop and ask.
                        visible: Network.needsPassphrase(modelData)
                        width: visible ? Appearance.fontSmall * 1.25 : 0
                        name: "lock"
                        size: Appearance.fontSmall
                        color: Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Button {
                        id: changeButton

                        // Re-type the passphrase of a network we already have
                        // saved -- the router-changed-its-password case.
                        //
                        // Hidden on the CONNECTED row on purpose, and not for
                        // tidiness: WifiNetwork::connectWithPsk refuses to
                        // rewrite the secret of a live connection and returns
                        // with nothing but a log line, so the button would do
                        // visibly nothing. If it is connected, the stored key
                        // is by definition still correct.
                        visible: modelData.known && !modelData.connected
                            && Network.canUsePassphrase(modelData)
                        width: visible ? Appearance.controlHeight : 0
                        height: Appearance.controlHeight
                        icon: "key"
                        variant: "ghost"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.openPrompt(modelData.name, true)
                    }

                    Button {
                        id: forgetButton

                        visible: modelData.known
                        width: visible ? Appearance.controlHeight : 0
                        height: Appearance.controlHeight
                        icon: "trash"
                        variant: "ghost"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            root.closePrompt();
                            Network.clearError();
                            root.needsEditor = "";
                            root.confirmForget = modelData.name;
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
                text: (root.promptIsChange ? "New password for " : "Password for ") + root.promptFor
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.promptIsChange
                text: "This replaces the saved password for this network."
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                wrapMode: Text.WordWrap
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
                    onAccepted: if (connectButton.enabled) connectButton.clicked()
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

            Row {
                width: parent.width
                spacing: Appearance.sm
                layoutDirection: Qt.RightToLeft

                Button {
                    id: connectButton

                    // WPA's own floor. Below it NetworkManager would reject
                    // the profile rather than the router rejecting the key.
                    text: root.promptIsChange ? "Save and connect" : "Connect"
                    variant: "accent"
                    enabled: root.passphrase.length >= 8
                    onClicked: {
                        const n = root.networkNamed(root.promptFor);
                        if (n) Network.connect(n, root.passphrase);
                        root.closePrompt();
                    }
                }

                Button {
                    text: "Cancel"
                    variant: "ghost"
                    onClicked: {
                        root.closePrompt();
                        Network.clearError();
                    }
                }
            }
        }
    }

    // --- forget confirmation -------------------------------------------------
    // Deleting a saved passphrase is not undoable from here -- you need the key
    // again to get back on -- so it asks, in the same card shape as the prompt
    // rather than in a dialog that would need its own window.
    Card {
        width: parent.width
        visible: root.confirmForget !== ""
        elevation: 0
        implicitHeight: forgetColumn.implicitHeight + Appearance.md * 2

        Column {
            id: forgetColumn

            anchors.fill: parent
            anchors.margins: Appearance.md
            spacing: Appearance.sm

            Text {
                width: parent.width
                text: "Forget " + root.confirmForget + "?"
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                font.weight: Appearance.weightMedium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: {
                    const n = root.networkNamed(root.confirmForget);
                    const base = "Its saved password is deleted and this machine stops joining it automatically.";
                    return n && n.connected ? base + " You will be disconnected." : base;
                }
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: Appearance.sm
                layoutDirection: Qt.RightToLeft

                Button {
                    text: "Forget"
                    variant: "danger"
                    onClicked: {
                        Network.forget(root.networkNamed(root.confirmForget));
                        root.confirmForget = "";
                    }
                }

                Button {
                    text: "Cancel"
                    variant: "ghost"
                    onClicked: root.confirmForget = ""
                }
            }
        }
    }

    // --- things this panel deliberately cannot do ----------------------------
    Text {
        width: parent.width
        visible: root.needsEditor !== ""
        text: root.needsEditor + " needs enterprise credentials. Open advanced settings below."
        color: Theme.warning
        font.family: Appearance.font
        font.pixelSize: Appearance.fontCaption
        wrapMode: Text.WordWrap
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
