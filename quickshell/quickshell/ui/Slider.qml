import QtQuick
import qs

// =============================================================================
// Slider — volume, brightness, seek.
// =============================================================================
// One slider for the whole shell, replacing three different ones: waybar's
// GTK slider-popup.py (a 433-line Python program spawned per use), pavucontrol's,
// and whatever the brightness applet drew.
//
// FEEL
//   The track grows taller under the pointer rather than showing a separate
//   handle on hover. That keeps the resting state clean -- a row of thin bars
//   in the Control Center, not a row of bars with knobs -- while still giving
//   a clear affordance the moment the mouse is near. The knob itself only
//   appears while hovering or dragging.
//
// LIVE VALUE VS COMMITTED VALUE
//   `value` is what the slider shows. While dragging, the UI must follow the
//   pointer at 120 Hz, but the device behind it (brightnessctl, PipeWire) must
//   NOT be written that fast. So dragging updates `value` and emits `moved`
//   continuously; the consumer throttles. See services/Brightness.qml, which
//   does exactly that.
//
//   `value` is deliberately NOT bound back from the service while dragging --
//   otherwise a throttled write arriving late snaps the handle backwards under
//   the user's finger.
// =============================================================================

FocusScope {
    id: root

    property real value: 0          // 0..1
    property real stepSize: 0.05

    // Decimal places every emitted value is rounded to.
    //
    // A drag maps a pixel position to a fraction, which lands on values like
    // 0.7594999999999998. Those went straight into settings.json, so the file
    // accumulated long meaningless floats ("opacity": 0.7594999999999998,
    // "smoothing": 0.9041796875) and every sub-pixel twitch of the mouse was a
    // genuinely different value -- a distinct property change, a distinct
    // debounced 400 ms write, and a diff in a file that is meant to be
    // hand-editable.
    //
    // Three places is finer than any of these controls can actually resolve
    // (a 400 px slider is 0.0025 per pixel) so nothing is lost.
    property int precision: 3

    // Round to `precision` and clamp. Every path that changes the value goes
    // through this -- drag, keyboard, scroll -- so no caller can reintroduce
    // the raw float.
    function quantise(v) {
        const clamped = Math.max(0, Math.min(1, v));
        const factor = Math.pow(10, root.precision);
        return Math.round(clamped * factor) / factor;
    }
    property bool enabled: true

    // Optional icon drawn inside the track's left end.
    property string icon: ""

    // Continuous, while dragging. Throttle in the consumer.
    signal moved(real value)
    // Once, when the drag ends or a click lands. For consumers that only want
    // the final value (a settings write, say).
    signal committed(real value)

    readonly property int restHeight: Appearance.compact ? 34 : 40
    readonly property int activeHeight: root.restHeight + 6
    readonly property bool active: mouse.containsMouse || mouse.pressed || root.activeFocus

    implicitWidth: 200
    implicitHeight: root.activeHeight

    activeFocusOnTab: root.enabled

    function setFromX(x) {
        const w = track.width;
        if (w <= 0) return;
        root.value = root.quantise(x / w);
        root.moved(root.value);
    }

    Keys.onLeftPressed: { root.value = root.quantise(root.value - root.stepSize); root.moved(root.value); root.committed(root.value); }
    Keys.onRightPressed: { root.value = root.quantise(root.value + root.stepSize); root.moved(root.value); root.committed(root.value); }

    Rectangle {
        id: track

        anchors.centerIn: parent
        width: parent.width
        height: root.active ? root.activeHeight : root.restHeight
        radius: height / 2

        color: Theme.wash(Theme.surface2, 0.85)
        opacity: root.enabled ? 1 : 0.4
        clip: true

        Behavior on height {
            enabled: !Appearance.motionless
            NumberAnimation {
                duration: Appearance.durationFast
                easing.type: Appearance.easeStandard
            }
        }

        // --- fill -------------------------------------------------------
        Rectangle {
            id: fill

            width: Math.max(parent.height, parent.width * root.value)
            height: parent.height
            radius: parent.radius
            color: Theme.accent

            // No Behavior while dragging: the fill must track the pointer
            // exactly. Animating here is what makes a slider feel like it is
            // lagging behind your hand.
            Behavior on width {
                enabled: !Appearance.motionless && !mouse.pressed
                NumberAnimation {
                    duration: Appearance.durationFast
                    easing.type: Appearance.easeStandard
                }
            }
        }

        // --- icon -------------------------------------------------------
        Icon {
            visible: root.icon !== ""
            name: root.icon === "" ? "info" : root.icon
            anchors.left: parent.left
            anchors.leftMargin: Appearance.sm + 2
            anchors.verticalCenter: parent.verticalCenter
            size: Appearance.iconSize
            // Sits on the fill when the fill has reached it, on the track
            // otherwise -- so it is always readable against whatever is behind.
            color: fill.width > x + width ? Theme.onAccent(Theme.accent) : Theme.muted

            Behavior on color {
                enabled: !Appearance.motionless
                ColorAnimation { duration: Appearance.durationFast }
            }
        }

        // --- knob -------------------------------------------------------
        // Only visible while the slider is engaged. Keeps the resting state
        // as a clean bar.
        Rectangle {
            width: 4
            height: parent.height - 10
            radius: 2
            color: Theme.onAccent(Theme.accent)
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(6, Math.min(parent.width - 10, fill.width - 10))
            opacity: root.active ? 0.9 : 0

            Behavior on opacity {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationFast }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: (e) => { root.forceActiveFocus(); root.setFromX(e.x); }
        onPositionChanged: (e) => { if (pressed) root.setFromX(e.x); }
        onReleased: root.committed(root.value)

        // Scrolling over a slider adjusts it, matching the behaviour the
        // waybar modules already have (scroll on the volume icon).
        onWheel: (e) => {
            const delta = e.angleDelta.y > 0 ? root.stepSize : -root.stepSize;
            root.value = root.quantise(root.value + delta);
            root.moved(root.value);
            root.committed(root.value);
        }
    }
}
