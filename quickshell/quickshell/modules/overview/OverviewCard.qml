import QtQuick
import Quickshell
// For ScreencopyView, the window thumbnails below.
import Quickshell.Wayland
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

    // Sized so four 16:9 thumbnails fit in two rows under the header:
    // (320 - 2*lg - sm) / 2 = 139 wide, 78 tall, 162 with the row gap, against
    // 248 - 2*lg - 34 header - md = 166 of body. Change one and check the other.
    width: 320
    height: 248

    readonly property real tileW: Math.floor((root.width - Appearance.lg * 2 - Appearance.sm) / 2)
    readonly property real tileH: Math.round(root.tileW * 9 / 16)

    // Four tiles, two rows. The overflow count is drawn over the grid rather
    // than added below it, so the card's body height never changes.
    readonly property var tiles: root.workspace.windows.slice(0, 4)
    readonly property int overflow: root.workspace.windows.length - 4

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
            Item {
                width: parent.width
                height: grid.height
                visible: root.workspace.windows.length > 0

                Grid {
                    id: grid

                    width: parent.width
                    columns: 2
                    spacing: Appearance.sm

                    Repeater {
                        model: root.tiles

                        Rectangle {
                            id: tile

                            required property var modelData

                            width: root.tileW
                            height: root.tileH
                            radius: Appearance.radiusInner
                            color: Theme.wash(Theme.text, 0.07)
                            // The capture is the window's own aspect, not the
                            // tile's, so without this a tall window bleeds out
                            // over the rounded corners.
                            clip: true

                            ScreencopyView {
                                id: thumb

                                anchors.fill: parent
                                // Null until Hyprland reports the address; the
                                // icon below covers that window.
                                captureSource: tile.modelData.toplevel
                                    ? tile.modelData.toplevel.wayland : null
                                // One streaming card at a time -- isSelected is
                                // true only at the front of the ring. Going
                                // false stops asking for frames and leaves the
                                // last one on screen, so a card you have spun
                                // past keeps a still.
                                live: root.isSelected
                                visible: thumb.hasContent
                            }

                            // What a window's icon resolves to, or "" when
                            // nothing does.
                            //
                            // The `true` overload is used rather than the
                            // two-argument fallback form, because that form
                            // builds a request like
                            // "com.scratchpad.ghostty?fallback=application-x-executable"
                            // which resolves to NOTHING and logged a warning
                            // per card per open. It mattered less when this was
                            // decoration; now it is the fallback for a window
                            // with no frame, so a failed lookup meant an empty
                            // tile.
                            readonly property string iconSource: {
                                const entry = DesktopEntries.heuristicLookup(tile.modelData.cls);
                                if (entry && entry.icon !== "") {
                                    const viaEntry = Quickshell.iconPath(entry.icon, true);
                                    if (viaEntry !== "") return viaEntry;
                                }
                                if (tile.modelData.cls !== "") {
                                    const viaClass = Quickshell.iconPath(tile.modelData.cls, true);
                                    if (viaClass !== "") return viaClass;
                                }
                                return Quickshell.iconPath("application-x-executable", true);
                            }

                            // Fallback, and the only thing drawn for a window
                            // that never yields a frame.
                            Image {
                                visible: !thumb.hasContent && tile.iconSource !== ""
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                asynchronous: true
                                smooth: true
                                sourceSize.width: 60
                                sourceSize.height: 60
                                source: tile.iconSource
                            }

                            // Last resort, so a tile is never simply blank.
                            Icon {
                                visible: !thumb.hasContent && tile.iconSource === ""
                                anchors.centerIn: parent
                                name: "apps"
                                size: 24
                                color: Theme.wash(Theme.text, 0.35)
                            }

                            // Floating windows are marked, because "what is on
                            // this workspace" and "what is tiled on this
                            // workspace" are different questions and the layout
                            // depends on it.
                            Rectangle {
                                visible: tile.modelData.floating
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

                // "and this many more", over the corner of the grid.
                Rectangle {
                    visible: root.overflow > 0
                    anchors.right: grid.right
                    anchors.bottom: grid.bottom
                    anchors.margins: Appearance.xs
                    width: more.implicitWidth + Appearance.sm
                    height: 18
                    radius: 9
                    color: Theme.wash(Theme.surface, 0.92)

                    Text {
                        id: more

                        anchors.centerIn: parent
                        text: "+" + root.overflow
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        font.weight: Appearance.weightMedium
                    }
                }
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
