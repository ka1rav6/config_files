import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.UPower
import qs

// =============================================================================
// LockDashboard — the two wings that open out of the avatar on hover.
// =============================================================================
// Left: a greeting, then CPU, memory and temperature. Right: volume, battery,
// storage, network, connected devices and power. It only shows information.
// The one input it takes is the power row, which is armed and then confirmed,
// as in the power menu.
//
// GEOMETRY
//   This item has zero size and sits on the avatar centre (LockWidget places
//   it). Everything is laid out relative to that point, so the wings stay
//   attached to the avatar even if it moves.
//
// MOTION
//   One linear scalar, `t`, runs 0 -> 1 on open and back on close. The wings
//   and every row read their own eased slice of it, so the stagger is just
//   arithmetic: no per-row animation objects, and closing plays the same
//   choreography in reverse at about three times the speed.
//
// HOVER
//   Open on the avatar after hoverRevealDelay, so a pointer crossing the
//   avatar on its way to the password field does not open the dashboard.
//   Stay open while the pointer is over either wing, or over the band level
//   with the avatar that joins them, and close hoverRevealDelay after leaving
//   all three. Every handler is a passive HoverHandler, so none of them can
//   take a click or the keyboard away from the password field.
//
// SECURITY
//   This reads nothing private and grants nothing. The power actions are what
//   the greeter of any login manager offers; they end the session but
//   never open it.
// =============================================================================

Item {
    id: root

    property bool avatarHovered: false
    property string name: ""
    property real clearance: 200
    property real avatarRadius: 52

    property bool open: false
    property real t: 0
    property string arming: ""

    // White-on-scrim tiers, the same ones LockSurface and LockWidget use.
    readonly property color ink: "white"
    readonly property color inkMuted: Qt.rgba(1, 1, 1, 0.55)
    readonly property color inkFaint: Qt.rgba(1, 1, 1, 0.4)

    width: 0
    height: 0

    // --- timing -------------------------------------------------------------

    function seg(start, span) { return Math.max(0, Math.min(1, (root.t - start) / span)); }
    // Row i of a wing: starts a little after the wing, 50 ms of stagger each.
    function rowAt(i) {
        const x = root.seg(Math.min(0.2 + i * 0.05, 0.58), 0.42);
        return 1 - Math.pow(1 - x, 3);
    }

    onOpenChanged: {
        if (root.open) {
            retract.stop();
            // Reopening a half-closed dashboard only plays the remaining distance.
            expand.duration = Appearance.duration(640 * (1 - root.t));
            expand.start();
        } else {
            expand.stop();
            retract.duration = Appearance.duration(220 * root.t);
            retract.start();
            root.arming = "";
        }
    }

    NumberAnimation { id: expand; target: root; property: "t"; to: 1 }
    NumberAnimation { id: retract; target: root; property: "t"; to: 0 }

    // --- hover ----------------------------------------------------------------

    readonly property bool hovering: root.avatarHovered || left.hovered
                                     || right.hovered || bridge.hovered

    onHoveringChanged: {
        if (root.hovering) {
            hideTimer.stop();
            if (!root.open) revealTimer.restart();
        } else {
            revealTimer.stop();
            if (root.open) hideTimer.restart();
        }
    }

    Timer { id: revealTimer; interval: Appearance.hoverRevealDelay; onTriggered: root.open = true }
    // The short delay is safe: the bridge band already covers the gap to each wing.
    Timer { id: hideTimer; interval: Appearance.hoverRevealDelay; onTriggered: root.open = false }

    // The gap between the avatar and each wing. Only live while open, so it
    // cannot open the dashboard by itself.
    Item {
        x: -root.clearance - left.width
        y: -root.avatarRadius
        width: 2 * (root.clearance + left.width)
        height: 2 * root.avatarRadius

        HoverHandler { id: bridge; enabled: root.open }
    }

    // --- data -----------------------------------------------------------------

    // Warm for the life of the lock rather than only while open: the CPU figure
    // is a delta between two reads, so asking on hover would show 0% for a whole
    // poll interval every time the dashboard opened.
    Component.onCompleted: SysInfo.want("lock-dashboard")
    Component.onDestruction: SysInfo.drop("lock-dashboard")

    readonly property string salutation: {
        const h = Time.now.getHours();
        if (h < 5) return "Up late";
        if (h < 12) return "Good morning";
        if (h < 17) return "Good afternoon";
        if (h < 22) return "Good evening";
        return "Up late";
    }

    // Bluetooth from BlueZ (with its battery, where the device reports one), plus
    // UPower's non-Bluetooth peripherals, e.g. a Logitech receiver's keyboard.
    // The UPower entries that ARE Bluetooth are skipped; BlueZ already listed them.
    readonly property var devices: {
        const out = [];
        for (const d of Bluetooth.connectedDevices) {
            const kind = Bluetooth.kind(d);
            out.push({
                icon: kind === "audio" ? "headphones" : kind === "keyboard" ? "keyboard" : "bluetooth-connected",
                label: Bluetooth.label(d),
                detail: d.batteryAvailable ? Math.round(d.battery * 100) + "%" : ""
            });
        }
        for (const u of UPower.devices.values) {
            if (u.powerSupply || u.isLaptopBattery || !u.isPresent || !u.model) continue;
            if (u.nativePath.indexOf("/org/bluez") === 0) continue;
            out.push({
                icon: u.type === UPowerDeviceType.Keyboard ? "keyboard" : "link",
                label: u.model,
                // hidpp reports a coarse level, not a percentage (`upower -i`
                // says "should be ignored"), so no figure is shown.
                detail: ""
            });
        }
        return out;
    }

    readonly property var powerActions: [
        { id: "suspend",  label: "Suspend",   icon: "suspend", key: "", confirm: false, cmd: ["systemctl", "suspend"] },
        { id: "reboot",   label: "Restart",   icon: "restart", key: "", confirm: true,  cmd: ["systemctl", "reboot"] },
        { id: "shutdown", label: "Shut down", icon: "power",   key: "", confirm: true,  cmd: ["systemctl", "poweroff"] }
    ]

    function activate(action) {
        if (action.confirm && root.arming !== action.id) {
            root.arming = action.id;
            disarm.restart();
            return;
        }
        root.arming = "";
        Quickshell.execDetached(action.cmd);
    }

    // Same rule as the power menu: an armed action that is ignored disarms itself.
    Timer { id: disarm; interval: 4000; onTriggered: root.arming = "" }

    // --- pieces ---------------------------------------------------------------

    component Caption: Text {
        color: Qt.rgba(1, 1, 1, 0.4)
        font.family: Appearance.font
        font.pixelSize: Appearance.fontCaption
        font.weight: Appearance.weightMedium
        font.letterSpacing: Appearance.trackingLabel
    }

    component Stat: StatBar {
        textColor: "white"
        mutedColor: Qt.rgba(1, 1, 1, 0.55)
    }

    // ==========================================================================
    // LEFT — greeting and processor
    // ==========================================================================
    LockWing {
        id: left

        side: -1
        progress: root.seg(0, 0.62)
        clearance: root.clearance
        avatarRadius: root.avatarRadius
        contentHeight: Math.max(greeting.implicitHeight + Appearance.xl + system.implicitHeight,
                                status.implicitHeight)

        // Ambient light behind the greeting, drifting slowly while open.
        Shape {
            id: glow

            width: 240
            height: 240
            x: -110
            y: -130
            opacity: 0.9 * root.rowAt(0)

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 120; centerY: 120; centerRadius: 120
                    focalX: 120; focalY: 120
                    GradientStop { position: 0.0; color: Theme.wash(Theme.accent, 0.30) }
                    GradientStop { position: 1.0; color: Theme.wash(Theme.accent, 0.0) }
                }
                PathAngleArc { centerX: 120; centerY: 120; radiusX: 120; radiusY: 120; startAngle: 0; sweepAngle: 360 }
            }

            SequentialAnimation on x {
                running: root.open && !Appearance.motionless
                loops: Animation.Infinite
                NumberAnimation { to: -40; duration: 9000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -110; duration: 9000; easing.type: Easing.InOutSine }
            }
        }

        Column {
            id: greeting

            width: parent.width
            spacing: Appearance.xs
            opacity: root.rowAt(0)
            transform: Translate { y: (1 - root.rowAt(0)) * 12 }

            Caption { text: root.salutation.toUpperCase() }

            Row {
                spacing: Appearance.sm

                Text {
                    text: "Hello,"
                    color: root.inkMuted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.size(30)
                    font.weight: Font.Light
                    font.letterSpacing: Appearance.trackingHeading
                }

                Text {
                    text: root.name
                    color: root.ink
                    font.family: Appearance.font
                    font.pixelSize: Appearance.size(30)
                    font.weight: Appearance.weightSemi
                    font.letterSpacing: Appearance.trackingHeading
                }
            }

            // Draws itself in after the greeting lands.
            Rectangle {
                width: 44 * root.rowAt(1)
                height: 2
                radius: 1
                color: Theme.accent
            }
        }

        Column {
            id: system

            anchors.bottom: parent.bottom
            width: parent.width
            spacing: Appearance.sm

            Item {
                width: parent.width
                implicitHeight: 16
                opacity: root.rowAt(2)

                Row {
                    spacing: Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter

                    // A slow pulse that says the numbers below are live.
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            running: root.open && !Appearance.motionless
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 1100; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
                        }
                    }

                    Caption { text: "SYSTEM" }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: SysInfo.uptimeText === "" ? "" : "up " + SysInfo.uptimeText
                    color: root.inkFaint
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                }
            }

            Stat {
                width: parent.width
                opacity: root.rowAt(3)
                icon: "cpu"
                label: "Processor"
                value: SysInfo.cpuUsage
                detail: Math.round(SysInfo.cpuUsage * 100) + "%"
            }

            Stat {
                width: parent.width
                opacity: root.rowAt(4)
                icon: "ram"
                label: "Memory"
                value: SysInfo.memoryUsage
                detail: SysInfo.memoryUsedGb.toFixed(1) + " / " + SysInfo.memoryTotalGb.toFixed(1) + " GB"
            }

            Stat {
                width: parent.width
                visible: SysInfo.cpuTempC >= 0
                opacity: root.rowAt(5)
                icon: "temperature"
                label: "Temperature"
                value: SysInfo.cpuTempC / 100
                detail: Math.round(SysInfo.cpuTempC) + " °C"
                tint: SysInfo.cpuTempC >= 90 ? Theme.error
                    : SysInfo.cpuTempC >= 75 ? Theme.warning : Theme.accent
            }
        }
    }

    // ==========================================================================
    // RIGHT — status, devices and power
    // ==========================================================================
    LockWing {
        id: right

        side: 1
        progress: root.seg(0, 0.62)
        clearance: root.clearance
        avatarRadius: root.avatarRadius
        contentHeight: left.contentHeight

        Column {
            id: status

            width: parent.width
            spacing: Appearance.sm

            Caption { text: "STATUS"; opacity: root.rowAt(0); height: 16; verticalAlignment: Text.AlignVCenter }

            Stat {
                width: parent.width
                opacity: root.rowAt(1)
                icon: Audio.muted ? "volume-mute" : Audio.volume > 0.5 ? "volume-high"
                    : Audio.volume > 0 ? "volume-low" : "volume-off"
                label: "Volume"
                value: Audio.muted ? 0 : Audio.volume
                detail: Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"
            }

            Stat {
                width: parent.width
                visible: Performance.hasBattery
                opacity: root.rowAt(2)
                icon: Performance.batteryCharging ? "battery-charging" : "battery-full"
                label: "Battery"
                value: Performance.batteryPercent
                detail: Math.round(Performance.batteryPercent * 100) + "%"
                      + (Performance.batteryCharging ? " · charging" : "")
                // Same thresholds as the dashboard and waybar.
                tint: {
                    const p = Performance.batteryPercent * 100;
                    if (Performance.batteryCharging) return Theme.success;
                    if (p <= 15) return Theme.error;
                    if (p <= 30) return Theme.warning;
                    return Theme.accent;
                }
            }

            Stat {
                width: parent.width
                visible: SysInfo.diskTotalGb > 0
                opacity: root.rowAt(3)
                icon: "folder"
                label: "Storage"
                value: SysInfo.diskUsage
                detail: (SysInfo.diskTotalGb - SysInfo.diskUsedGb).toFixed(0) + " GB free"
                tint: SysInfo.diskUsage > 0.9 ? Theme.error
                    : SysInfo.diskUsage > 0.75 ? Theme.warning : Theme.accent
            }

            // Network: one line, the same icon logic as the status line below.
            Item {
                width: parent.width
                height: 28
                opacity: root.rowAt(4)

                Icon {
                    id: netIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    name: Network.wiredConnected ? "ethernet"
                        : Network.wifiEnabled ? "wifi-" + Network.signalBars : "wifi-off"
                    size: Appearance.iconSize
                    color: Network.connected ? Theme.accent : root.inkMuted
                }

                Text {
                    anchors.left: netIcon.right
                    anchors.leftMargin: Appearance.sm
                    anchors.right: netDetail.left
                    anchors.rightMargin: Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                    text: Network.summary
                    elide: Text.ElideRight
                    color: root.ink
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSmall
                }

                Text {
                    id: netDetail
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Network.wiredConnected ? "Ethernet"
                        : Network.wifiConnected ? "Wi-Fi · " + Network.signalStrength + "%" : ""
                    color: root.inkMuted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontCaption
                }
            }

            Column {
                width: parent.width
                spacing: Appearance.xs
                topPadding: Appearance.xs
                opacity: root.rowAt(5)

                Caption { text: "DEVICES"; height: 16; verticalAlignment: Text.AlignVCenter }

                Text {
                    visible: root.devices.length === 0
                    text: "Nothing connected"
                    color: root.inkFaint
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSmall
                }

                Repeater {
                    model: root.devices

                    Item {
                        required property var modelData

                        width: parent.width
                        height: 24

                        Icon {
                            id: devIcon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.icon
                            size: Appearance.fontLabel
                            color: root.inkMuted
                        }

                        Text {
                            anchors.left: devIcon.right
                            anchors.leftMargin: Appearance.sm
                            anchors.right: devDetail.left
                            anchors.rightMargin: Appearance.sm
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            elide: Text.ElideRight
                            color: root.ink
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontSmall
                        }

                        Text {
                            id: devDetail
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.detail
                            color: root.inkMuted
                            font.family: Appearance.fontMono
                            font.pixelSize: Appearance.fontCaption
                        }
                    }
                }
            }

            // Power. Restart and Shut down arm first and commit on the second
            // press, as in the power menu; Shut down carries a red rim at rest.
            Row {
                width: parent.width
                spacing: Appearance.sm
                topPadding: Appearance.sm
                opacity: root.rowAt(6)
                transform: Translate { y: (1 - root.rowAt(6)) * 10 }

                readonly property real cell: (width - spacing * 2) / 3

                Repeater {
                    model: root.powerActions

                    PowerTile {
                        required property var modelData

                        width: parent.cell
                        height: 58
                        action: modelData
                        armed: root.arming === modelData.id
                        border.width: modelData.id === "shutdown" && !armed ? 1 : 0
                        border.color: Theme.wash(Theme.error, 0.6)
                        onTriggered: root.activate(modelData)
                    }
                }
            }
        }
    }
}
