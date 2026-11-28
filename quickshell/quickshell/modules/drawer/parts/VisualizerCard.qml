import QtQuick
import qs

// =============================================================================
// VisualizerCard — the music visualizers, on the Super + D Media page.
// =============================================================================
// On/off for the desktop visualizer, one tile per style (a tiny static drawing
// of each, so they can be told apart without trying them), and the ring round
// the pointer. Everything here is a setting; nothing animates or runs while
// the drawer is open -- the visualizer itself is gated in
// modules/visualizer/Visualizer.qml (only while music plays, only on monitors
// whose wallpaper is actually showing).
// =============================================================================
Card {
    id: root

    elevation: 0
    implicitHeight: column.implicitHeight + Appearance.md * 2

    readonly property bool on: Settings.desktop.visualizer && Settings.features.musicVisualizer

    // Why it is not drawing right now, when it is on but nothing shows.
    readonly property string why: !Settings.features.musicVisualizer ? "Off in Settings › Components"
        : !Settings.desktop.visualizer ? ""
        : !Performance.allowVisualizer ? (Performance.gameMode ? "Paused while a window is fullscreen" : "Paused by Battery Saver")
        : !Hypr.anyDesktopVisible ? "Waiting — windows cover the wallpaper"
        : !Media.playing ? "Starts when music plays"
        : "Drawing on the wallpaper"

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.md
        spacing: Appearance.sm

        Item {
            width: parent.width
            height: Math.max(header.implicitHeight, toggle.implicitHeight)

            Column {
                id: header
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "VISUALIZER"
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.letterSpacing: Appearance.trackingLabel
                }
                Text {
                    visible: root.why !== ""
                    text: root.why
                    color: Theme.wash(Theme.muted, 0.8)
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                }
            }

            Toggle {
                id: toggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Settings.desktop.visualizer
                onToggled: (v) => Settings.desktop.visualizer = v
            }
        }

        // Style tiles.
        Grid {
            id: grid

            width: parent.width
            columns: 4
            spacing: Appearance.xs
            opacity: root.on ? 1 : 0.45

            Behavior on opacity {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationFast }
            }

            Repeater {
                model: Settings.visualizerStyles

                Rectangle {
                    id: tile

                    required property var modelData
                    readonly property bool selected: Settings.visualizer.style === modelData.id

                    width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
                    height: 58
                    radius: Appearance.radiusInner
                    color: selected ? Theme.wash(Theme.accent, 0.16) : tileMouse.containsMouse ? Theme.hover : Theme.wash(Theme.text, 0.04)
                    border.width: selected ? 1.5 : 0
                    border.color: Theme.accent

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }

                    // A still drawing of the style: 9 fixed sample levels.
                    Item {
                        id: sketch

                        readonly property var levels: [0.35, 0.7, 0.95, 0.6, 0.8, 0.45, 0.65, 0.3, 0.5]
                        readonly property color ink: tile.selected ? Theme.accent : Theme.muted
                        readonly property string style: tile.modelData.id

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        width: 46
                        height: 26

                        Repeater {
                            model: sketch.style === "ring" ? 0 : sketch.levels.length

                            Item {
                                required property int index
                                readonly property real lv: {
                                    if (sketch.style !== "center") return sketch.levels[index];
                                    const mid = 4;
                                    return sketch.levels[Math.abs(index - mid) * 2 % 9];
                                }
                                x: index * 5.2
                                width: 3
                                height: sketch.height

                                Rectangle {   // bar / stem / dot
                                    readonly property bool dot: sketch.style === "dots"
                                    readonly property bool mirror: sketch.style === "mirror"
                                    width: sketch.style === "line" ? 1.2 : 3
                                    x: (parent.width - width) / 2
                                    height: dot ? 3 : mirror ? Math.max(3, lv * parent.height) : Math.max(2, lv * parent.height)
                                    y: dot ? parent.height - lv * parent.height
                                       : mirror ? (parent.height - height) / 2
                                       : parent.height - height
                                    radius: width / 2
                                    color: sketch.ink
                                }
                                Rectangle {   // peak cap / lollipop head
                                    visible: sketch.style === "peaks" || sketch.style === "line"
                                    width: sketch.style === "line" ? 4 : 3
                                    height: sketch.style === "line" ? 4 : 1.5
                                    radius: sketch.style === "line" ? 2 : 0.5
                                    x: (parent.width - width) / 2
                                    y: sketch.style === "line" ? parent.height - lv * parent.height - 2
                                                               : Math.max(0, parent.height - Math.min(1, lv + 0.15) * parent.height)
                                    color: sketch.ink
                                }
                            }
                        }

                        // Ring sketch: 16 short bars round a circle.
                        Repeater {
                            model: sketch.style === "ring" ? 16 : 0
                            Item {
                                required property int index
                                x: sketch.width / 2
                                y: sketch.height / 2
                                rotation: index * 22.5
                                Rectangle {
                                    width: 2
                                    height: 3 + sketch.levels[index % 9] * 5
                                    radius: 1
                                    x: -1
                                    y: -7 - height
                                    color: sketch.ink
                                }
                            }
                        }
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.label
                        color: tile.selected ? Theme.text : Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Settings.visualizer.style = tile.modelData.id;
                            Settings.desktop.visualizer = true;
                        }
                    }
                }
            }
        }

        // The ring round the pointer -- music too, so it lives here as well.
        Item {
            width: parent.width
            height: Math.max(ringLabel.implicitHeight, ringToggle.implicitHeight)

            Column {
                id: ringLabel
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: "Ring round the pointer"
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontBody
                }
                Text {
                    text: !Pointer.available ? "Needs the qs-pointer plugin" : "Style and size in Settings › Cursor"
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                }
            }

            Toggle {
                id: ringToggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Settings.cursor.ring
                onToggled: (v) => Settings.cursor.ring = v
            }
        }
    }
}
