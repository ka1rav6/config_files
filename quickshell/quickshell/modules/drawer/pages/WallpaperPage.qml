import QtQuick
import Quickshell.Widgets
import qs

// =============================================================================
// WallpaperPage — your wallpaper folder as a grid; click one to set it.
// =============================================================================
// The same Wallpaper service as the wallpaper picker (SUPER + SHIFT + W) and
// the same apply script, so this is a smaller view of one thing, not a second
// wallpaper system. Setting one also re-derives the theme if "Derive colours
// from the wallpaper" is on -- the service handles that, not this page.
//
// Thumbnails are the service's cached ones (~/.cache/quickshell/thumbs); a
// missing one is generated on open, in one batch. Until it lands, the image
// itself is shown, decoded down to tile size.
// =============================================================================

Column {
    id: root

    required property var drawer

    spacing: Appearance.lg

    Component.onCompleted: Wallpaper.refresh()

    PageHeader {
        title: "Wallpaper"
        subtitle: Wallpaper.count + (Wallpaper.count === 1 ? " image" : " images") + (Wallpaper.name !== "" ? " · " + Wallpaper.name : "")

        Button {
            text: "Shuffle"
            icon: "refresh"
            variant: "soft"
            enabled: Wallpaper.count > 1 && !Wallpaper.applying
            onClicked: Wallpaper.random()
        }
    }

    Grid {
        width: parent.width
        columns: 2
        spacing: Appearance.sm

        readonly property real cell: (width - spacing) / 2

        Repeater {
            model: Wallpaper.images

            ClippingRectangle {
                id: tile

                required property var modelData
                readonly property bool current: tile.modelData === Wallpaper.current

                width: parent.cell
                height: Math.round(parent.cell * 0.6)
                radius: Appearance.radiusInner
                color: Theme.wash(Theme.text, 0.06)

                Image {
                    anchors.fill: parent
                    source: {
                        const t = Wallpaper.thumbFor(tile.modelData);
                        return "file://" + (t !== "" ? t : tile.modelData);
                    }
                    sourceSize.width: 320
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    scale: tileMouse.containsMouse ? 1.06 : 1

                    Behavior on scale {
                        enabled: !Appearance.motionless
                        NumberAnimation { duration: Appearance.durationNormal; easing.type: Appearance.easeStandard }
                    }
                }

                // Current: an accent ring and a check.
                Rectangle {
                    anchors.fill: parent
                    radius: tile.radius
                    color: "transparent"
                    border.width: tile.current ? 3 : 0
                    border.color: Theme.accent
                }

                Rectangle {
                    visible: tile.current
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Appearance.sm
                    width: 24
                    height: 24
                    radius: 12
                    color: Theme.accent

                    Icon {
                        anchors.centerIn: parent
                        name: "check"
                        size: 14
                        color: Theme.onAccent(Theme.accent)
                    }
                }

                MouseArea {
                    id: tileMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !Wallpaper.applying
                    onClicked: Wallpaper.apply(tile.modelData)
                }
            }
        }
    }
}
