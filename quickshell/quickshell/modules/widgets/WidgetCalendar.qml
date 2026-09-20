import QtQuick
import qs

// The month, on the wallpaper. Reuses the dashboard's Calendar so there is one
// calendar in this desktop, not two that drift apart.
DesktopWidget {
    id: root

    widgetId: "calendar"
    defaultX: 0.74
    defaultY: 0.10
    contentWidth: 300
    contentHeight: cal.implicitHeight + Appearance.md * 2

    Calendar {
        id: cal
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // Arrow keys belong to the dashboard's copy; this one is for reading.
        focus: false
    }
}
