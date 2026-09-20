import QtQuick
import qs

// =============================================================================
// WidgetGauge — a ring gauge. Used for CPU, memory and battery.
// =============================================================================
// One component rather than three, because the only thing that differs between
// them is where the number comes from.
//
// The ring is a Shape-free implementation: two stacked arcs would need
// QtQuick.Shapes and a renderer pass, so instead the track and the fill are
// Canvas strokes redrawn only when the value actually changes. A gauge updates
// about once a second, so this is nothing like the visualiser's 60 Hz problem.
// =============================================================================

DesktopWidget {
    id: root

    contentWidth: 168
    contentHeight: 168

    property real value: 0              // 0..1
    property string label: ""
    property string detail: ""
    property string icon: ""
    property color tint: Theme.accent

    // Animated separately from `value` so the arc glides to a new reading
    // instead of jumping on every sample.
    property real shown: 0
    onValueChanged: root.shown = root.value
    Component.onCompleted: root.shown = root.value

    Behavior on shown {
        enabled: !Appearance.motionless
        NumberAnimation { duration: Appearance.duration(500); easing.type: Appearance.easeStandard }
    }

    Item {
        anchors.fill: parent

        Canvas {
            id: ring

            anchors.fill: parent
            // Repaints are driven by the properties below, not by a timer.
            renderStrategy: Canvas.Cooperative

            readonly property real fraction: root.shown
            readonly property color tint: root.tint
            readonly property color track: Theme.wash(Theme.text, 0.10)

            onFractionChanged: ring.requestPaint()
            onTintChanged: ring.requestPaint()
            onTrackChanged: ring.requestPaint()

            onPaint: {
                const ctx = ring.getContext("2d");
                ctx.reset();

                const cx = ring.width / 2;
                const cy = ring.height / 2;
                const stroke = 9;
                const r = Math.min(cx, cy) - stroke / 2 - 2;

                // Start at the top, sweep clockwise.
                const start = -Math.PI / 2;

                ctx.lineCap = "round";
                ctx.lineWidth = stroke;

                ctx.strokeStyle = ring.track;
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.stroke();

                if (ring.fraction <= 0) return;

                ctx.strokeStyle = ring.tint;
                ctx.beginPath();
                ctx.arc(cx, cy, r, start,
                        start + Math.PI * 2 * Math.min(1, ring.fraction));
                ctx.stroke();
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Icon {
                name: root.icon
                size: Appearance.iconSize
                color: root.tint
                visible: root.icon !== ""
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: root.detail
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.size(20)
                font.weight: Appearance.weightSemi
                font.features: ({ "tnum": 1 })
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: root.label
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                font.letterSpacing: Appearance.trackingLabel
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
