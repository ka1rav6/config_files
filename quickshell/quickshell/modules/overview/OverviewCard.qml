import QtQuick
import Quickshell
import qs

// One workspace on the ring: its number, its name, and what is open on it.
//
// Sized once and never relaid out -- the carousel animates x/scale/opacity/z
// only, so nothing here re-measures while the ring spins.
Item {
    id: root

    required property var workspace
    property bool isActive: false     // the workspace you are currently on
    property bool isSelected: false   // the card at the front of the ring

    signal clicked()

    width: 300
    height: 200

    transformOrigin: Item.Center

    Behavior on scale {
        enabled: !Appearance.motionless
        NumberAnimation { duration: Appearance.durationFast }
    }

    Behavior on opacity {
        enabled: !Appearance.motionless
        NumberAnimation { duration: Appearance.durationFast }
    }

    Rectangle {
        id: face

        anchors.fill: parent
        radius: Appearance.radius + 4

        color: root.isSelected ? Theme.wash(Theme.surface, 0.96)
                               : Theme.wash(Theme.surface, 0.80)

        // The current workspace keeps the accent even when it is not the one
        // at the front, so you never lose track of where you started.
        border.width: root.isSelected ? 2 : 1
        border.color: root.isSelected ? Theme.accent
            : root.isActive ? Theme.wash(Theme.accent, 0.55)
            : Theme.wash(Theme.border, 0.35)

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation { duration: Appearance.durationFast }
        }

        Behavior on border.color {
            enabled: !Appearance.motionless
            ColorAnimation { duration: Appearance.durationFast }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Appearance.lg
            spacing: Appearance.md

            // --- header ---------------------------------------------------
            Item {
                width: parent.width
                height: 34

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.workspace.name
                    color: root.isSelected ? Theme.accent : Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.size(28)
                    font.weight: Appearance.weightBold
                    font.letterSpacing: Appearance.trackingDisplay
                }

                // "you are here", without needing a legend.
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.isActive
                    width: current.implicitWidth + Appearance.md
                    height: 20
                    radius: 10
                    color: Theme.wash(Theme.accent, 0.20)

                    Text {
                        id: current
                        anchors.centerIn: parent
                        text: "current"
                        color: Theme.accent
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        font.weight: Appearance.weightMedium
                    }
                }
            }

            // --- windows ----------------------------------------------------
            Flow {
                width: parent.width
                spacing: Appearance.sm
                visible: root.workspace.windows.length > 0

                Repeater {
                    // Six is what fits on two rows at this size; the caption
                    // below carries the real count.
                    model: root.workspace.windows.slice(0, 6)

                    Rectangle {
                        required property var modelData

                        width: 46
                        height: 46
                        radius: Appearance.radiusInner
                        color: Theme.wash(Theme.text, 0.07)

                        Image {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            asynchronous: true
                            smooth: true
                            sourceSize.width: 60
                            sourceSize.height: 60
                            source: {
                                const entry = DesktopEntries.heuristicLookup(modelData.cls);
                                return Quickshell.iconPath(
                                    entry ? entry.icon : modelData.cls,
                                    "application-x-executable");
                            }
                        }

                        // Floating windows are marked, because "what is on this
                        // workspace" and "what is tiled on this workspace" are
                        // different questions and the layout depends on it.
                        Rectangle {
                            visible: modelData.floating
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 3
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.accent2
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.workspace.windows.length > 6
                text: "+" + (root.workspace.windows.length - 6) + " more"
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontCaption
            }

            // --- empty state -------------------------------------------------
            Item {
                width: parent.width
                height: 74
                visible: root.workspace.windows.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Appearance.xs

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "desktop"
                        size: 24
                        color: Theme.wash(Theme.text, 0.22)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "empty"
                        color: Theme.wash(Theme.text, 0.30)
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
