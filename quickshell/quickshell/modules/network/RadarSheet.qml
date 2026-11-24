import QtQuick
import Quickshell
import qs

// =============================================================================
// RadarSheet — what you can do with the network picked on the radar.
// =============================================================================
// Sits under the radar while a node is selected. Same rules as the Control
// Center's Wi-Fi page (modules/controlcenter/CcWifi.qml) and for the same
// reasons, all of which live as comments in services/Network.qml:
//
//   * a saved network joins with no prompt;
//   * an unsaved secured one asks for a passphrase -- but only if it is a PSK
//     network, because connectWithPsk silently refuses anything else;
//   * enterprise / WEP networks are sent to nm-connection-editor instead of
//     being given a password box that cannot work;
//   * a saved network can have its passphrase replaced (router password
//     changed) or be forgotten, and forgetting asks first;
//   * the connected network cannot have its passphrase rewritten, because
//     NetworkManager will not do it, so the button is not offered.
//
// The selection is held as an SSID, never as a WifiNetwork object: the list is
// rebuilt on every scan and a captured object can be replaced underneath us
// between click and confirm. `network` turns the name back into the live one.
// =============================================================================

Column {
    id: root

    required property string name

    signal dismissed()

    spacing: Appearance.sm

    readonly property var network: {
        for (const n of Network.networks) {
            if (n.name === root.name) return n;
        }
        return null;
    }

    readonly property bool joining: Network.pendingNetwork !== null
        && Network.pendingNetwork.name === root.name

    // "prompt" | "change" | "forget" | ""
    property string mode: ""
    property string passphrase: ""

    // A different node was picked: start clean rather than carrying a
    // half-typed password across to another network.
    onNameChanged: {
        root.mode = "";
        root.passphrase = "";
    }

    function startJoin() {
        const n = root.network;
        if (!n) return;
        Network.clearError();
        if (Network.needsPassphrase(n)) {
            if (Network.canUsePassphrase(n)) root.mode = "prompt";
            // else: the enterprise note below is already showing.
        } else {
            Network.connect(n);
        }
    }

    function submitPassphrase() {
        const n = root.network;
        if (n && root.passphrase.length >= 8) Network.connect(n, root.passphrase);
        root.mode = "";
        root.passphrase = "";
    }

    // --- title row ------------------------------------------------------------
    Item {
        width: parent.width
        implicitHeight: Appearance.controlHeight

        Icon {
            id: signalIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: "wifi-" + Network.signalBarsFor(root.network)
            size: Appearance.iconSizeLarge
            color: root.network && root.network.connected ? Theme.accent : Theme.text
        }

        Column {
            anchors.left: signalIcon.right
            anchors.leftMargin: Appearance.sm
            anchors.right: closeButton.left
            anchors.rightMargin: Appearance.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: root.name
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontTitle
                font.weight: Appearance.weightSemi
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: {
                    const n = root.network;
                    if (!n) return "Out of range";
                    const parts = [Network.signalPercent(n) + "%", Network.securityLabel(n)];
                    if (root.joining) parts.push("Connecting…");
                    else if (n.connected) parts.push("Connected");
                    else if (n.known) parts.push("Saved");
                    return parts.join(" · ");
                }
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                elide: Text.ElideRight
            }
        }

        Button {
            id: closeButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.controlHeight
            height: Appearance.controlHeight
            icon: "close"
            variant: "ghost"
            onClicked: root.dismissed()
        }
    }

    // --- primary actions --------------------------------------------------------
    Row {
        width: parent.width
        spacing: Appearance.sm
        visible: root.network !== null && root.mode === ""

        Button {
            visible: !!root.network && !root.network.connected
                && !(Network.needsPassphrase(root.network) && !Network.canUsePassphrase(root.network))
            text: root.joining ? "Connecting…" : "Connect"
            busy: root.joining
            variant: "accent"
            enabled: !root.joining
            onClicked: root.startJoin()
        }

        Button {
            visible: !!root.network && root.network.connected
            text: "Disconnect"
            variant: "soft"
            onClicked: Network.disconnect()
        }

        Button {
            // Not on the connected row: NetworkManager refuses to rewrite the
            // secret of a live connection, so this would do nothing visible.
            visible: !!root.network && root.network.known && !root.network.connected
                && Network.canUsePassphrase(root.network)
            text: "Change password"
            icon: "key"
            variant: "ghost"
            onClicked: { root.passphrase = ""; root.mode = "change"; Network.clearError(); }
        }

        Button {
            visible: !!root.network && root.network.known
            text: "Forget"
            icon: "trash"
            variant: "ghost"
            onClicked: root.mode = "forget"
        }
    }

    // --- enterprise / WEP: not a one-field job ------------------------------------
    Row {
        width: parent.width
        spacing: Appearance.sm
        visible: !!root.network && Network.needsPassphrase(root.network)
            && !Network.canUsePassphrase(root.network)

        Text {
            width: parent.width - editorButton.width - Appearance.sm
            anchors.verticalCenter: parent.verticalCenter
            text: "This network needs enterprise credentials (identity, certificate), which a password box cannot provide."
            color: Theme.warning
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
            wrapMode: Text.WordWrap
        }

        Button {
            id: editorButton

            anchors.verticalCenter: parent.verticalCenter
            text: "Set up"
            variant: "soft"
            onClicked: {
                Quickshell.execDetached(["nm-connection-editor"]);
                Shell.close("network");
            }
        }
    }

    // --- passphrase ------------------------------------------------------------------
    Column {
        width: parent.width
        spacing: Appearance.sm
        visible: root.mode === "prompt" || root.mode === "change"

        Text {
            width: parent.width
            visible: root.mode === "change"
            text: "This replaces the saved password for this network."
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
        }

        Row {
            width: parent.width
            spacing: Appearance.sm

            Rectangle {
                width: parent.width - joinButton.width - cancelButton.width - Appearance.sm * 2
                height: Appearance.controlHeight
                radius: Appearance.radiusInner
                color: Theme.wash(Theme.bg, 0.6)
                border.width: 1
                border.color: field.activeFocus ? Theme.accent : Theme.wash(Theme.border, 0.4)

                TextInput {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.sm
                    anchors.rightMargin: reveal.width + Appearance.xs
                    verticalAlignment: TextInput.AlignVCenter
                    // Masked by default, never logged, never saved by the shell,
                    // never on a command line: straight to NetworkManager over
                    // D-Bus via connectWithPsk.
                    echoMode: reveal.revealed ? TextInput.Normal : TextInput.Password
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontBody
                    selectByMouse: true
                    text: root.passphrase
                    onTextChanged: root.passphrase = text
                    onAccepted: if (joinButton.enabled) root.submitPassphrase()
                    Keys.onEscapePressed: (event) => { root.mode = ""; event.accepted = true; }
                }

                // Pull focus in as soon as the box appears, so you can type
                // straight after clicking Connect.
                onVisibleChanged: if (visible) field.forceActiveFocus()

                Button {
                    id: reveal

                    property bool revealed: false

                    anchors.right: parent.right
                    width: Appearance.controlHeight
                    height: Appearance.controlHeight
                    variant: "ghost"
                    icon: reveal.revealed ? "eye-off" : "eye"
                    onClicked: reveal.revealed = !reveal.revealed
                }
            }

            Button {
                id: joinButton

                // WPA's own minimum; below it NetworkManager rejects the
                // profile rather than the router rejecting the key.
                text: root.mode === "change" ? "Save" : "Join"
                variant: "accent"
                enabled: root.passphrase.length >= 8
                onClicked: root.submitPassphrase()
            }

            Button {
                id: cancelButton

                text: "Cancel"
                variant: "ghost"
                onClicked: { root.mode = ""; root.passphrase = ""; }
            }
        }
    }

    // --- forget, confirmed ------------------------------------------------------------
    // Not undoable from here -- you need the key again to get back on -- so it
    // asks, inline, in the place the button was.
    Row {
        width: parent.width
        spacing: Appearance.sm
        visible: root.mode === "forget"

        Text {
            width: parent.width - forgetYes.width - forgetNo.width - Appearance.sm * 2
            anchors.verticalCenter: parent.verticalCenter
            text: "Delete the saved password?"
                + (root.network && root.network.connected ? " You will be disconnected." : "")
            color: Theme.text
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            wrapMode: Text.WordWrap
        }

        Button {
            id: forgetYes

            anchors.verticalCenter: parent.verticalCenter
            text: "Forget"
            variant: "danger"
            onClicked: { Network.forget(root.network); root.mode = ""; }
        }

        Button {
            id: forgetNo

            anchors.verticalCenter: parent.verticalCenter
            text: "Cancel"
            variant: "ghost"
            onClicked: root.mode = ""
        }
    }
}
