import QtQuick
import qs

// =============================================================================
// Toggle — the on/off switch.
// =============================================================================
// Deliberately spring-loaded rather than linear: a switch is a physical
// metaphor and it should feel like the knob has mass. The overshoot is small
// (Appearance.overshoot, 0.6 rather than QML's cartoonish 1.7 default) so it
// settles rather than bounces.
//
// The track colour crossfades on the same curve as the knob travels, so the
// two read as one movement instead of a slide plus a separate recolour.
//
// ACCESSIBILITY
//   Focusable and operable from the keyboard (Space/Return), with a visible
//   focus ring. The hit area is padded out to Appearance.touchTarget, which is
//   larger than the drawn switch -- this is a convertible and these get tapped.
// =============================================================================

FocusScope {
    id: root

    property bool checked: false
    property bool enabled: true

    // Emitted only on user action, never when `checked` is changed in code.
    // Binding a setting directly to `checked` and also reacting to
    // onCheckedChanged is how you get a feedback loop; use this instead.
    signal toggled(bool value)

    readonly property int trackWidth: Appearance.compact ? 40 : 46
    readonly property int trackHeight: Appearance.compact ? 22 : 26
    readonly property int knobSize: root.trackHeight - 6

    implicitWidth: root.trackWidth
    implicitHeight: Math.max(root.trackHeight, Appearance.touchTarget)

    activeFocusOnTab: root.enabled

    function toggle() {
        if (!root.enabled) return;
        root.checked = !root.checked;
        root.toggled(root.checked);
    }

    Keys.onSpacePressed: root.toggle()
    Keys.onReturnPressed: root.toggle()

    Rectangle {
        id: track

        anchors.centerIn: parent
        width: root.trackWidth
        height: root.trackHeight
        radius: height / 2

        color: root.checked ? Theme.accent : Theme.wash(Theme.border, 0.45)
        opacity: root.enabled ? 1.0 : 0.4

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation {
                duration: Appearance.durationNormal
                easing.type: Appearance.easeStandard
            }
        }

        Behavior on opacity {
            enabled: !Appearance.motionless
            NumberAnimation { duration: Appearance.durationFast }
        }

        // Focus ring, outside the track so it never overlaps the knob.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 8
            height: parent.height + 8
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.wash(Theme.accent, 0.6)
            visible: root.activeFocus
        }

        Rectangle {
            id: knob

            y: 3
            width: root.knobSize
            height: root.knobSize
            radius: height / 2
            color: root.checked ? Theme.onAccent(Theme.accent) : Theme.muted

            // The whole animation, in one property.
            x: root.checked ? track.width - width - 3 : 3

            Behavior on x {
                enabled: !Appearance.motionless
                NumberAnimation {
                    duration: Appearance.durationNormal
                    easing.type: Appearance.easeEmphasised
                    easing.overshoot: Appearance.overshoot
                }
            }

            Behavior on color {
                enabled: !Appearance.motionless
                ColorAnimation { duration: Appearance.durationNormal }
            }

            // Squash slightly while held, like a real button under a thumb.
            scale: mouse.pressed ? 0.88 : 1.0
            Behavior on scale {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationFast }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus();
            root.toggle();
        }
    }
}
