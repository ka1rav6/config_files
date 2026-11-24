import QtQuick
import Quickshell
// NOT `import Quickshell.Networking`: it exports a type named `Network` that
// shadows the Network service singleton for the whole file. Connectivity is
// read as Network.internetState instead -- see services/Network.qml.
import qs

// =============================================================================
// NetworkRadarBody — the radar, its detail sheet and the connection summary.
// =============================================================================
// Everything inside the Wi-Fi radar, without a window around it, so it can
// live in two places: its own centred panel (NetworkRadar.qml) and the
// Network page of the left drawer (modules/drawer). Both are the same object
// tree; only the size differs.
//
// LAYOUT
//   header     title, live status, the Wi-Fi switch
//   banner     why the last join failed, when one did
//   radar      RadarView
//   bottom     RadarSheet for the picked network, otherwise the
//              "connection" summary (network, address, internet)
//
// WHAT IT KEEPS RUNNING, AND WHEN
//   Exactly as long as this object exists -- and both hosts destroy it when
//   it goes off screen (Panel tears its window down, the drawer unloads pages
//   it is not showing):
//     * a Wi-Fi scan demand -- the radio is otherwise left alone;
//     * the IPv4 lookup -- one `ip -j addr` per connection change, no timer;
//     * the radar's pulse, which is itself gated on motion being allowed.
//   Demands are registered under `consumerId`, so the panel and the drawer
//   page never cancel each other's.
// =============================================================================

Column {
    id: root

    // Name this body registers its scan/address demands under. Must differ
    // between hosts.
    required property string consumerId

    property int radarHeight: 360

    // The header's close button. Hidden where the host has its own way out.
    property bool showClose: true

    signal closeRequested()

    // Name of the network picked on the radar, or "" for the summary.
    property string selectedName: ""

    Component.onCompleted: {
        Network.wantScan(root.consumerId);
        Network.wantAddress(root.consumerId);
    }

    Component.onDestruction: {
        Network.dropScan(root.consumerId);
        Network.dropAddress(root.consumerId);
    }
    spacing: Appearance.gap

    // --- header ---------------------------------------------------------------
    Item {
        width: parent.width
        implicitHeight: Appearance.controlHeight

        Icon {
            id: headerIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: "radar"
            size: Appearance.iconSizeLarge
            color: Theme.accent
        }

        Column {
            anchors.left: headerIcon.right
            anchors.leftMargin: Appearance.sm
            anchors.right: headerActions.left
            anchors.rightMargin: Appearance.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                text: "Wi-Fi"
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontTitle
                font.weight: Appearance.weightSemi
                font.letterSpacing: Appearance.trackingHeading
            }

            Text {
                width: parent.width
                text: {
                    if (!Network.wifiHardwareEnabled) return "Blocked by a hardware switch";
                    if (!Network.wifiEnabled) return "Off";
                    const count = Network.networks.length;
                    return (Network.scanning ? "Scanning · " : "")
                        + count + (count === 1 ? " network" : " networks") + " in range";
                }
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                elide: Text.ElideRight
            }
        }

        Row {
            id: headerActions

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.sm

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Network.wifiEnabled
                enabled: Network.wifiHardwareEnabled
                onToggled: (v) => Network.setWifiEnabled(v)
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showClose
                width: visible ? Appearance.controlHeight : 0
                height: Appearance.controlHeight
                icon: "close"
                variant: "ghost"
                onClicked: root.closeRequested()
            }
        }
    }

    // --- why the last join failed ---------------------------------------------
    // Above the radar, not in the sheet: the failure that matters most is a
    // saved network whose stored key went stale, and that happens with no
    // sheet open -- the join just quietly does not happen.
    Rectangle {
        width: parent.width
        visible: Network.lastError !== ""
        height: visible ? errorText.implicitHeight + Appearance.sm * 2 : 0
        radius: Appearance.radiusInner
        color: Theme.wash(Theme.error, 0.14)

        Text {
            id: errorText

            anchors.left: parent.left
            anchors.right: errorClose.left
            anchors.margins: Appearance.sm
            anchors.verticalCenter: parent.verticalCenter
            text: (Network.lastErrorSsid === "" ? "Connection failed. "
                   : "Couldn't join " + Network.lastErrorSsid + ". ") + Network.lastError
            color: Theme.text
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            wrapMode: Text.WordWrap
        }

        Button {
            id: errorClose

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "close"
            variant: "ghost"
            onClicked: Network.clearError()
        }
    }

    // --- the radar ---------------------------------------------------------------
    Rectangle {
        width: parent.width
        height: root.radarHeight
        radius: Appearance.radiusInner
        color: Theme.wash(Theme.bg, 0.35)
        clip: true

        RadarView {
            id: radar

            anchors.fill: parent
            visible: Network.wifiEnabled
            selectedName: root.selectedName
            onNodeClicked: (name) => root.selectedName = (root.selectedName === name ? "" : name)
            onBackgroundClicked: root.selectedName = ""
        }

        // Wi-Fi off: say so, and offer the one thing to do about it.
        Column {
            anchors.centerIn: parent
            spacing: Appearance.md
            visible: !Network.wifiEnabled

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "wifi-off"
                size: Appearance.iconSizeLarge * 2
                color: Theme.muted
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Network.wifiHardwareEnabled ? "Wi-Fi is off"
                    : "Wi-Fi is disabled by a hardware switch"
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Network.wifiHardwareEnabled
                text: "Turn on"
                variant: "accent"
                onClicked: Network.setWifiEnabled(true)
            }
        }
    }

    // --- bottom: the picked network, or the connection summary -----------------
    Loader {
        width: parent.width
        sourceComponent: root.selectedName !== "" ? sheetComponent : summaryComponent
    }

    Component {
        id: sheetComponent

        RadarSheet {
            name: root.selectedName
            onDismissed: root.selectedName = ""
        }
    }

    Component {
        id: summaryComponent

        Column {
            spacing: Appearance.sm

            Item {
                width: parent.width
                implicitHeight: Appearance.controlHeight

                Icon {
                    id: summaryIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    name: Network.wifiConnected ? "wifi-" + Network.signalBars
                        : Network.wiredConnected ? "ethernet" : "wifi-0"
                    size: Appearance.iconSizeLarge
                    color: Network.connected ? Theme.accent : Theme.muted
                }

                Column {
                    anchors.left: summaryIcon.right
                    anchors.leftMargin: Appearance.sm
                    anchors.right: summaryActions.left
                    anchors.rightMargin: Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        width: parent.width
                        text: Network.wifiConnected ? Network.ssid
                            : Network.wiredConnected ? "Connected by cable"
                            : "Not connected"
                        color: Theme.text
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontTitle
                        font.weight: Appearance.weightSemi
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Network.wifiConnected
                            ? Network.signalStrength + "% · " + Network.securityLabel(Network.activeNetwork)
                            : Network.wiredConnected ? "Ethernet"
                            : Network.wifiEnabled ? "Pick a network on the radar" : ""
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: summaryActions

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.sm

                    Button {
                        visible: Network.wifiConnected
                        text: "Disconnect"
                        variant: "soft"
                        onClicked: Network.disconnect()
                    }

                    Button {
                        // Static IPs, VPNs, proxies: not this panel's job.
                        text: "Advanced"
                        icon: "settings"
                        variant: "ghost"
                        onClicked: {
                            Quickshell.execDetached(["nm-connection-editor"]);
                            root.closeRequested();
                        }
                    }
                }
            }

            // Address + internet, as chips. Only when there is a connection
            // to describe.
            Flow {
                width: parent.width
                spacing: Appearance.sm
                visible: Network.connected

                Rectangle {
                    visible: Network.ipv4 !== ""
                    width: ipRow.implicitWidth + Appearance.md * 2
                    height: Appearance.controlHeightSmall
                    radius: Appearance.radiusFull
                    color: Theme.wash(Theme.surface2, 0.7)

                    Row {
                        id: ipRow

                        anchors.centerIn: parent
                        spacing: Appearance.xs

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "ip"
                            size: Appearance.fontSmall
                            color: Theme.muted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Network.ipv4
                            color: Theme.text
                            font.family: Appearance.fontMono
                            font.pixelSize: Appearance.fontCaption
                        }
                    }
                }

                Rectangle {
                    id: internetChip

                    readonly property color tint: Network.internetState === "full" ? Theme.success
                        : Network.internetState === "portal" ? Theme.warning
                        : Network.internetState === "unknown" ? Theme.muted
                        : Theme.error

                    width: netRow.implicitWidth + Appearance.md * 2
                    height: Appearance.controlHeightSmall
                    radius: Appearance.radiusFull
                    color: Theme.wash(tint, 0.16)

                    Row {
                        id: netRow

                        anchors.centerIn: parent
                        spacing: Appearance.xs

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "web"
                            size: Appearance.fontSmall
                            color: internetChip.tint
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Network.internetLabel
                            color: Theme.text
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontCaption
                        }
                    }
                }

                // A captive portal is the one case where there is an obvious
                // next step: load any plain-HTTP page so the network can
                // redirect it to its sign-in form. neverssl.com exists for
                // exactly that -- an HTTPS page cannot be redirected.
                Button {
                    visible: Network.portal
                    height: Appearance.controlHeightSmall
                    text: "Open sign-in page"
                    variant: "accent"
                    onClicked: {
                        Quickshell.execDetached(["xdg-open", "http://neverssl.com"]);
                        root.closeRequested();
                    }
                }
            }
        }
    }
}
