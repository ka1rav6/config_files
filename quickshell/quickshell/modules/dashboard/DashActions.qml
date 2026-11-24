import QtQuick
import qs

// =============================================================================
// DashActions — the four quick-action tiles
// =============================================================================
// One section of the dashboard, split out so the left drawer's pages
// (modules/drawer) can show the very same thing instead of a copy that drifts.
// It reads services only; whatever it needs polled (seconds, /proc, the MPRIS
// position) is demanded by its HOST while the host is on screen -- see
// Dashboard.qml and modules/drawer/Drawer.qml.
// =============================================================================

// The four things most often wanted straight from a glance at the
// clock. Deliberately few: this is a dashboard, and a wall of buttons
// would make it a control panel.
Row {
    width: parent.width
    spacing: Appearance.sm

    readonly property real cell: (width - spacing * 3) / 4

    Repeater {
        model: [
            { icon: "palette",   label: "Themes",   target: "settings",  page: "appearance" },
            { icon: "wallpaper", label: "Wallpaper", target: "wallpaper", page: "" },
            { icon: "settings",  label: "Settings",  target: "settings",  page: "" },
            { icon: "power",     label: "Power",     target: "power",     page: "" }
        ]

        Rectangle {
            required property var modelData

            width: parent.cell
            height: 62
            radius: Appearance.radiusInner
            color: actionMouse.containsMouse ? Theme.wash(Theme.accent, 0.16)
                                             : Theme.wash(Theme.text, 0.06)

            Behavior on color {
                enabled: !Appearance.motionless
                ColorAnimation { duration: Appearance.durationFast }
            }

            scale: actionMouse.pressed ? 0.95 : 1.0
            Behavior on scale {
                enabled: !Appearance.motionless
                NumberAnimation {
                    duration: Appearance.durationFast
                    easing.type: Appearance.easeStandard
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Appearance.xs

                Icon {
                    name: modelData.icon
                    size: Appearance.iconSize
                    color: actionMouse.containsMouse ? Theme.accent : Theme.text
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: modelData.label
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                id: actionMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Shell.open(modelData.target);
                    if (modelData.page !== "" && Shell.has(modelData.target))
                        Shell.panels[modelData.target].page = modelData.page;
                }
            }
        }
    }
}
