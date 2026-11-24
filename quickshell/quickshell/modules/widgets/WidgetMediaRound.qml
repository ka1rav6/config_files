import QtQuick
import Quickshell.Widgets
import qs

// =============================================================================
// WidgetMediaRound — album art in a circle, with progress around the rim.
// =============================================================================
// The compact player from Anserin's picker: a disc of the cover art, a ring
// that fills as the track plays, the title underneath, and play/pause in the
// middle on hover. Previous / next on the sides of the title. Interactive, so
// Widgets.qml punches it out of the click-through mask.
//
// The progress ring needs the playback position, which Media only polls while
// someone wants it; this widget wants it under its own id for exactly as long
// as it exists. The ring's Canvas repaints when the progress changes and at
// no other time.
// =============================================================================

DesktopWidget {
    id: root

    defaultX: 0.035
    defaultY: 0.34
    contentWidth: 196
    contentHeight: 250
    bare: true
    interactive: true

    readonly property string consumer: "desktop-media-round-" + root.widgetId
    Component.onCompleted: Media.wantPosition(root.consumer)
    Component.onDestruction: Media.dropPosition(root.consumer)

    readonly property real discSize: root.contentWidth - Appearance.md * 2

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: Appearance.sm

        Item {
            width: root.discSize
            height: root.discSize

            // Progress around the rim.
            Canvas {
                id: rim

                anchors.fill: parent
                renderStrategy: Canvas.Cooperative

                readonly property real progress: Media.progress
                readonly property color tint: Theme.accent
                readonly property color track: Theme.wash(Theme.text, 0.14)

                onProgressChanged: rim.requestPaint()
                onTintChanged: rim.requestPaint()

                onPaint: {
                    const ctx = rim.getContext("2d");
                    ctx.reset();
                    const c = rim.width / 2, r = c - 4;
                    ctx.lineWidth = 5;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = rim.track;
                    ctx.beginPath();
                    ctx.arc(c, c, r, 0, Math.PI * 2);
                    ctx.stroke();
                    if (rim.progress <= 0) return;
                    ctx.strokeStyle = rim.tint;
                    ctx.beginPath();
                    ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * rim.progress);
                    ctx.stroke();
                }
            }

            // The art, clipped to a real circle. ClippingRectangle (from
            // Quickshell.Widgets) clips its children to its rounded shape in
            // a shader, without an offscreen layer -- a plain Rectangle with
            // `clip` would only clip to its square bounding box.
            ClippingRectangle {
                id: disc

                anchors.centerIn: parent
                width: parent.width - 18
                height: width
                radius: width / 2
                color: Theme.wash(Theme.surface, 0.9)

                Image {
                    anchors.fill: parent
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: Media.artUrl !== ""
                    // Decoded at the size it is shown, not at the 1000+ px
                    // some players hand over.
                    sourceSize.width: 256
                    sourceSize.height: 256
                }

                Icon {
                    anchors.centerIn: parent
                    visible: Media.artUrl === ""
                    name: "music"
                    size: Appearance.iconSizeLarge * 2
                    color: Theme.muted
                }

                // Play / pause on hover.
                Rectangle {
                    anchors.centerIn: parent
                    width: 56
                    height: 56
                    radius: 28
                    color: Theme.wash(Theme.bg, 0.7)
                    opacity: discMouse.containsMouse && !root.editing ? 1 : 0

                    Behavior on opacity {
                        enabled: !Appearance.motionless
                        NumberAnimation { duration: Appearance.durationFast }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: Media.playing ? "pause" : "play"
                        size: Appearance.iconSizeLarge
                        color: Theme.text
                    }
                }

                MouseArea {
                    id: discMouse

                    anchors.fill: parent
                    hoverEnabled: !root.editing
                    enabled: !root.editing && !root.preview && Media.available
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.playPause()
                }
            }
        }

        Item {
            width: root.discSize
            height: titleColumn.implicitHeight

            Icon {
                id: prevButton

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "previous"
                size: Appearance.iconSize
                color: prevMouse.containsMouse ? Theme.accent : Theme.muted

                MouseArea {
                    id: prevMouse

                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    enabled: !root.editing && !root.preview
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.previous()
                }
            }

            Column {
                id: titleColumn

                anchors.left: prevButton.right
                anchors.right: nextButton.left
                anchors.leftMargin: Appearance.xs
                anchors.rightMargin: Appearance.xs
                spacing: 0

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Media.title || "Nothing playing"
                    color: Theme.text
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontBody
                    font.weight: Appearance.weightSemi
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Media.artist
                    visible: text !== ""
                    color: Theme.muted
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    elide: Text.ElideRight
                }
            }

            Icon {
                id: nextButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: "next"
                size: Appearance.iconSize
                color: nextMouse.containsMouse ? Theme.accent : Theme.muted

                MouseArea {
                    id: nextMouse

                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    enabled: !root.editing && !root.preview
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.next()
                }
            }
        }
    }
}
