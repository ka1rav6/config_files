import QtQuick
import qs

// =============================================================================
// LockWing — one side of the lock-screen dashboard.
// =============================================================================
// A glass panel in the lock screen's own material (white over the scrim, as the
// password pill is) that grows out of the avatar. At progress 0 its inner edge
// sits on the avatar's rim, shrunk and transparent; at 1 it rests `clearance`
// px from the avatar centre, clear of the clock and the password field.
//
// The slide uses an out-back curve, so the panel lands slightly past its rest
// position and settles back. Scale and fade use plain out-cubic: an overshoot
// on those reads as a wobble, not a spring.
// =============================================================================

Rectangle {
    id: wing

    property int side: -1               // -1 left of the avatar, +1 right
    property real progress: 0           // 0..1, linear; easing happens here
    property real clearance: 200        // avatar centre -> inner edge, at rest
    property real avatarRadius: 52
    property real contentHeight: 0

    default property alias body: area.data
    readonly property alias hovered: hover.hovered

    readonly property real eased: 1 - Math.pow(1 - wing.progress, 3)
    // Out-back. 1.2 is ~5% overshoot on a ~150 px travel: felt, not watched.
    readonly property real sprung: {
        const y = wing.progress - 1, s = 1.2;
        return 1 + (s + 1) * y * y * y + s * y * y;
    }

    width: 300
    height: wing.contentHeight + Appearance.lg * 2
    x: wing.side < 0 ? -wing.clearance - wing.width : wing.clearance
    // Top edge a little above the avatar, so the greeting lines up beside it.
    y: -wing.avatarRadius - Appearance.xl

    visible: wing.progress > 0
    opacity: wing.eased
    clip: true

    radius: Appearance.radius
    border.width: Appearance.borderWidth
    border.color: Qt.rgba(1, 1, 1, 0.14)
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.11) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.05) }
    }

    transform: [
        // Scaled about the point level with the avatar centre on the inner
        // edge, so it visibly unfolds from the avatar.
        Scale {
            origin.x: wing.side < 0 ? wing.width : 0
            origin.y: wing.avatarRadius + Appearance.xl
            xScale: 0.6 + 0.4 * wing.eased
            yScale: 0.6 + 0.4 * wing.eased
        },
        Translate {
            x: -wing.side * (1 - wing.sprung) * (wing.clearance - wing.avatarRadius)
        }
    ]

    // Passive: the pointer over a wing keeps the dashboard open without the
    // wing taking any click away from what is under it.
    HoverHandler { id: hover }

    Item {
        id: area
        anchors.fill: parent
        anchors.margins: Appearance.lg
    }
}
