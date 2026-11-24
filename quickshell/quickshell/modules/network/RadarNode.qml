import QtQuick
import qs

// =============================================================================
// RadarNode — one network on the radar.
// =============================================================================
// A dot sized by signal strength, a label, and a padlock when joining will ask
// for a password. The item's origin is the dot's centre, so RadarView can place
// it with the same x/y it uses for the constellation lines.
//
// COLOUR CARRIES MEANING, SIZE CARRIES STRENGTH
//   accent, filled       the network you are on
//   accent, hollow ring  a saved network -- joins with one click
//   muted                a stranger
// Size is redundant with distance on purpose: distance alone is hard to read
// for two nodes on opposite sides of the hub.
//
// LABELS
//   Every node labelled is a wall of overlapping text past ten networks, so
//   names are shown for the connected network, saved ones, and the strongest
//   few; everything else names itself on hover. Hover also adds the exact
//   percentage and security type, which is the detail you want right before
//   clicking.
// =============================================================================

Item {
    id: root

    required property var node
    property real t: 1
    property bool selected: false

    signal clicked()

    // The network this node stands for, live, for things that change without
    // a re-layout (a join starting, for instance).
    readonly property bool joining: Network.pendingNetwork !== null
        && Network.pendingNetwork.name === root.node.name

    readonly property real dotSize: 8 + Math.max(0, Math.min(1, root.node.strength)) * 8
    readonly property bool showLabel: root.node.connected || root.node.known
        || root.node.strength >= 0.6 || mouse.containsMouse || root.selected

    // Interpolated position. A zero-size item placed at the dot's centre.
    x: root.node.x0 + (root.node.x1 - root.node.x0) * root.t
    y: root.node.y0 + (root.node.y1 - root.node.y0) * root.t
    width: 0
    height: 0
    z: root.selected || mouse.containsMouse ? 2 : (root.node.connected ? 1 : 0)

    // Halo: for the connected and selected nodes, and while hovered. Also the
    // "joining" pulse -- the only animation a node has, and it runs only for
    // the one node a connection is in flight on.
    Rectangle {
        id: halo

        width: root.dotSize + 14
        height: width
        x: -width / 2
        y: -height / 2
        radius: width / 2
        color: Theme.wash(Theme.accent, root.selected ? 0.28 : 0.16)
        visible: root.node.connected || root.selected || mouse.containsMouse || root.joining

        SequentialAnimation on scale {
            running: root.joining && !Appearance.motionless
            loops: Animation.Infinite
            onRunningChanged: if (!running) halo.scale = 1
            NumberAnimation { to: 1.5; duration: 650; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 650; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        id: dot

        width: root.dotSize
        height: width
        x: -width / 2
        y: -height / 2
        radius: width / 2
        color: root.node.connected ? Theme.accent
             : root.node.known ? Theme.wash(Theme.accent, 0.25)
             : Theme.wash(Theme.text, mouse.containsMouse || root.selected ? 0.8 : 0.5)
        border.width: root.node.known && !root.node.connected ? 1.5 : 0
        border.color: Theme.accent

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation { duration: Appearance.durationFast }
        }
    }

    Icon {
        visible: root.node.locked
        name: "lock"
        size: Appearance.fontCaption - 1
        color: Theme.muted
        x: root.dotSize / 2 - 1
        y: -root.dotSize / 2 - height + 4
    }

    Column {
        x: -width / 2
        y: root.dotSize / 2 + 3
        width: 120
        spacing: 0
        visible: root.showLabel

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.node.name
            color: root.node.connected || root.selected ? Theme.text : Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
            font.weight: root.node.connected ? Appearance.weightMedium : Appearance.weightNormal
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: mouse.containsMouse || root.selected
            text: Math.round(root.node.strength * 100) + "%"
                + (root.node.connected ? " · connected" : root.node.known ? " · saved" : "")
            color: Theme.muted
            font.family: Appearance.fontMono
            font.pixelSize: Appearance.fontCaption - 1
        }
    }

    // Bigger than the dot, because an 8 px target is a miss waiting to happen.
    MouseArea {
        id: mouse

        width: Math.max(Appearance.touchTarget - 8, root.dotSize + 16)
        height: width
        x: -width / 2
        y: -height / 2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
