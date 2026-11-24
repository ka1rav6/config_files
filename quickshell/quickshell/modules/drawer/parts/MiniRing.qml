import QtQuick
import qs

// =============================================================================
// MiniRing — a small ring gauge with a number in the middle and a label under.
// =============================================================================
// The System page's top row. Same drawing as the desktop's ring widget
// (WidgetMetric), sized for four across a drawer. The Canvas repaints only when
// the smoothed value or the colour changes.
// =============================================================================

Item {
    id: root

    property real value: 0          // 0..1
    property string detail: ""
    property string label: ""
    property string icon: ""
    property color tint: Theme.accent

    implicitWidth: 96
    implicitHeight: ringBox.height + labelText.implicitHeight + Appearance.xs

    property real shown: 0
    onValueChanged: root.shown = root.value
    Component.onCompleted: root.shown = root.value

    Behavior on shown {
        enabled: !Appearance.motionless
        NumberAnimation { duration: Appearance.duration(600); easing.type: Appearance.easeStandard }
    }

    Item {
        id: ringBox

        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width, 84)
        height: width

        Canvas {
            id: ring

            anchors.fill: parent
            renderStrategy: Canvas.Cooperative

            readonly property real fraction: root.shown
            readonly property color tint: root.tint
            readonly property color track: Theme.wash(Theme.text, 0.09)

            onFractionChanged: requestPaint()
            onTintChanged: requestPaint()
            onTrackChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2, stroke = 7, r = c - stroke / 2 - 1;
                ctx.lineCap = "round";
                ctx.lineWidth = stroke;
                ctx.strokeStyle = ring.track;
                ctx.beginPath();
                ctx.arc(c, c, r, 0, Math.PI * 2);
                ctx.stroke();
                if (ring.fraction <= 0) return;
                ctx.strokeStyle = ring.tint;
                ctx.beginPath();
                ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, ring.fraction));
                ctx.stroke();
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.icon !== ""
                name: root.icon
                size: Appearance.fontSmall
                color: root.tint
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.detail
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.size(17)
                font.weight: Appearance.weightSemi
                font.features: ({ "tnum": 1 })
            }
        }
    }

    Text {
        id: labelText

        anchors.top: ringBox.bottom
        anchors.topMargin: Appearance.xs
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        color: Theme.muted
        font.family: Appearance.font
        font.pixelSize: Appearance.fontCaption
        font.letterSpacing: Appearance.trackingLabel
    }
}
