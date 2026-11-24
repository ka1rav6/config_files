import QtQuick
import qs

// =============================================================================
// WidgetMetric — one system reading, as a ring or as a bar.
// =============================================================================
// Replaces WidgetGauge.qml, which was a ring that Widgets.qml filled in by hand
// three times (CPU, memory, battery). Now the widget knows its own metric, so
// the picker can place any number of them, in either style:
//
//   metric   cpu | ram | disk | temp | battery
//   style    ring   the 168 px ring gauge the old widgets were
//            bar    a compact 240 x 84 card: label, value, a thin bar
//
// The numbers come from SysInfo (/proc, polled only while some widget that
// needs it is on screen -- Widgets.qml holds that demand) or UPower for the
// battery, which is event-driven and costs nothing.
//
// The ring's Canvas repaints only when its value or colour changes; the value
// is smoothed with a Behavior so a 2 s poll reads as motion, not a jump.
// =============================================================================

DesktopWidget {
    id: root

    property string metric: "cpu"
    property string style: "ring"

    defaultX: 0.62
    defaultY: 0.40

    contentWidth: root.style === "ring" ? 168 : 240
    contentHeight: root.style === "ring" ? 168 : 84

    // --- the reading ---------------------------------------------------------
    readonly property real value: {
        switch (root.metric) {
        case "cpu":     return SysInfo.cpuUsage;
        case "ram":     return SysInfo.memoryUsage;
        case "disk":    return SysInfo.diskUsage;
        // Scaled against 100 °C, roughly where this CPU throttles.
        case "temp":    return SysInfo.cpuTempC > 0 ? Math.min(1, SysInfo.cpuTempC / 100) : 0;
        case "battery": return Performance.batteryPercent;
        }
        return 0;
    }

    readonly property string label: {
        switch (root.metric) {
        case "cpu":     return "PROCESSOR";
        case "ram":     return "MEMORY";
        case "disk":    return "DISK";
        case "temp":    return "TEMPERATURE";
        case "battery": return Performance.batteryCharging ? "CHARGING" : "BATTERY";
        }
        return "";
    }

    readonly property string icon: {
        switch (root.metric) {
        case "cpu":     return "cpu";
        case "ram":     return "ram";
        case "disk":    return "folder";
        case "temp":    return "temperature";
        case "battery": return Performance.batteryCharging ? "battery-charging" : "battery-full";
        }
        return "";
    }

    readonly property string detail: {
        switch (root.metric) {
        case "cpu":     return Math.round(SysInfo.cpuUsage * 100) + "%";
        case "ram":     return SysInfo.memoryUsedGb.toFixed(1) + "G";
        case "disk":    return Math.round(SysInfo.diskUsage * 100) + "%";
        case "temp":    return SysInfo.cpuTempC > 0 ? Math.round(SysInfo.cpuTempC) + "°" : "–";
        case "battery": return Math.round(Performance.batteryPercent * 100) + "%";
        }
        return "";
    }

    // Accent normally; amber then red as it gets bad. For the battery "bad"
    // is LOW, and charging is always fine.
    readonly property color tint: {
        const v = root.value;
        if (root.metric === "battery") {
            if (Performance.batteryCharging) return Theme.success;
            if (v <= 0.15) return Theme.error;
            if (v <= 0.30) return Theme.warning;
            return Theme.accent;
        }
        const warn = root.metric === "ram" || root.metric === "disk" ? 0.75 : 0.6;
        const crit = root.metric === "ram" || root.metric === "disk" ? 0.9 : 0.85;
        if (v > crit) return Theme.error;
        if (v > warn) return Theme.warning;
        return Theme.accent;
    }

    property real shown: 0
    onValueChanged: root.shown = root.value
    Component.onCompleted: root.shown = root.value

    Behavior on shown {
        enabled: !Appearance.motionless
        NumberAnimation { duration: Appearance.duration(500); easing.type: Appearance.easeStandard }
    }

    // --- ring --------------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: root.style === "ring"

        Canvas {
            id: ring

            anchors.fill: parent
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
                ctx.arc(cx, cy, r, start, start + Math.PI * 2 * Math.min(1, ring.fraction));
                ctx.stroke();
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.icon
                size: Appearance.iconSize
                color: root.tint
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.detail
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.size(20)
                font.weight: Appearance.weightSemi
                font.features: ({ "tnum": 1 })
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.label
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                font.letterSpacing: Appearance.trackingLabel
            }
        }
    }

    // --- bar ------------------------------------------------------------------------
    Column {
        anchors.fill: parent
        visible: root.style === "bar"
        spacing: Appearance.sm

        Item {
            width: parent.width
            height: Math.max(barIcon.height, barValue.implicitHeight)

            Icon {
                id: barIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                size: Appearance.iconSize
                color: root.tint
            }

            Text {
                anchors.left: barIcon.right
                anchors.leftMargin: Appearance.sm
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
                font.letterSpacing: Appearance.trackingLabel
            }

            Text {
                id: barValue

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.detail
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.size(20)
                font.weight: Appearance.weightSemi
                font.features: ({ "tnum": 1 })
            }
        }

        Rectangle {
            width: parent.width
            height: 8
            radius: 4
            color: Theme.wash(Theme.text, 0.10)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.shown))
                height: parent.height
                radius: 4
                color: root.tint
            }
        }
    }
}
