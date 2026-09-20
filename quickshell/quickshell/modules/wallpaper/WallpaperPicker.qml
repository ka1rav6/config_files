import QtQuick
import Quickshell
import qs

// =============================================================================
// Wallpaper picker.  SUPER + SHIFT + W  (and Settings > Desktop > Browse)
// =============================================================================
// A grid of thumbnails over the folder in Settings.wallpaper.directory.
// Choosing one runs ~/.config/hypr/scripts/apply-wallpaper.sh, which is the
// same path the command line uses -- see services/Wallpaper.qml for why there
// is no second wallpaper daemon here.
//
// THUMBNAILS
//   Image with sourceSize set, and asynchronous: true. That decodes each file
//   once at roughly display size rather than at full resolution -- the folder
//   contains a 6.3 MB JPEG and a 3.2 MB PNG, and decoding those at native size
//   to draw them 200px wide would stall the panel for a visible moment and hold
//   tens of megabytes while it was open.
//
//   `cache: false` because these are large and looked at rarely; letting Qt
//   keep every wallpaper in its pixmap cache would leave that memory resident
//   long after the picker closed.
//
// DERIVED COLOURS
//   If the active theme is `auto`, apply-wallpaper.sh re-derives the palette
//   from the new image automatically. The toggle at the bottom switches the
//   desktop into that mode, so picking a wallpaper and having the whole desktop
//   follow it is one click away rather than a separate concept.
// =============================================================================

Panel {
    id: root

    name: "wallpaper"
    placement: "center"
    panelWidth: 900
    panelHeight: 620
    scrim: true

    // Rescan on open: the folder is not watched (see services/Wallpaper.qml),
    // so this is the moment to find out what is actually in it.
    onOpened: Wallpaper.refresh()

    content: Item {

        // --- header -------------------------------------------------------
        Item {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            implicitHeight: Appearance.controlHeight

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "Wallpaper"
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontHeading
                    font.weight: Appearance.weightSemi
                    font.letterSpacing: Appearance.trackingHeading
                }

                Text {
                    text: Wallpaper.count + " images · " + Settings.wallpaper.directory
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    elide: Text.ElideMiddle
                    width: header.width - 240
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.sm

                Button {
                    text: "Random"
                    icon: "refresh"
                    variant: "soft"
                    enabled: Wallpaper.count > 1 && !Wallpaper.applying
                    onClicked: Wallpaper.random()
                }

                Button {
                    width: Appearance.controlHeight
                    height: Appearance.controlHeight
                    icon: "close"
                    variant: "ghost"
                    onClicked: root.hide()
                }
            }
        }

        // --- grid ----------------------------------------------------------
        GridView {
            id: grid

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: Appearance.md
            anchors.bottom: footer.top
            anchors.bottomMargin: Appearance.md

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 400

            readonly property int columns: 4
            cellWidth: Math.floor(width / columns)
            cellHeight: Math.floor(cellWidth * 0.62)

            model: Wallpaper.images

            delegate: Item {
                required property string modelData
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight

                readonly property bool current: modelData === Wallpaper.current
                readonly property string fileName: {
                    const parts = modelData.split("/");
                    return parts[parts.length - 1];
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Appearance.xs
                    radius: Appearance.radiusInner
                    color: Theme.wash(Theme.text, 0.05)
                    clip: true

                    border.width: parent.current ? 2 : 0
                    border.color: Theme.accent

                    scale: cellMouse.pressed ? 0.97 : (cellMouse.containsMouse ? 1.02 : 1.0)
                    Behavior on scale {
                        enabled: !Appearance.motionless
                        NumberAnimation {
                            duration: Appearance.durationFast
                            easing.type: Appearance.easeStandard
                        }
                    }

                    Image {
                        id: thumb

                        anchors.fill: parent
                        // A generated JPEG thumbnail, never the source file --
                        // see the long note in services/Wallpaper.qml. This Qt
                        // build cannot decode .webp or .avif at all, and the
                        // folder contains both.
                        source: {
                            const t = Wallpaper.thumbFor(modelData);
                            return t === "" ? "" : "file://" + t;
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: 420
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            enabled: !Appearance.motionless
                            NumberAnimation { duration: Appearance.durationSlow }
                        }
                    }

                    // Shown while the thumbnail is being generated, and for
                    // anything ImageMagick could not read either.
                    Item {
                        anchors.centerIn: parent
                        visible: thumb.status !== Image.Ready

                        Icon {
                            anchors.centerIn: parent
                            name: Wallpaper.generating ? "refresh" : "wallpaper"
                            size: Appearance.iconSizeLarge
                            color: Theme.muted

                            RotationAnimator on rotation {
                                running: Wallpaper.generating && !Appearance.motionless
                                loops: Animation.Infinite
                                from: 0; to: 360
                                duration: 1400
                            }
                        }
                    }

                    // Name plate, over a scrim so it stays readable on a light
                    // wallpaper.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 26
                        color: Qt.rgba(0, 0, 0, 0.55)
                        visible: cellMouse.containsMouse || parent.parent.current

                        Text {
                            anchors.fill: parent
                            anchors.margins: Appearance.sm
                            text: parent.parent.parent.fileName
                            color: "white"
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontCaption
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideMiddle
                        }
                    }

                    // Current-wallpaper marker.
                    Rectangle {
                        visible: parent.parent.current
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
                            size: Appearance.fontSmall
                            color: Theme.onAccent(Theme.accent)
                        }
                    }

                    MouseArea {
                        id: cellMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !Wallpaper.applying
                        onClicked: Wallpaper.apply(parent.parent.modelData)
                    }
                }
            }

            // Empty state, rather than a blank rectangle that looks broken.
            Text {
                anchors.centerIn: parent
                visible: Wallpaper.count === 0
                text: "No images in " + Settings.wallpaper.directory
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
            }
        }

        // --- footer ---------------------------------------------------------
        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            implicitHeight: Appearance.controlHeight

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.sm

                Toggle {
                    checked: Theme.name === "auto"
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: (v) => ThemeCatalogue.apply(v ? "auto" : "mint")
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: "Match the desktop to the wallpaper"
                        color: Theme.text
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontBody
                    }

                    Text {
                        text: Theme.name === "auto"
                            ? "Colours re-derive on every change · contrast enforced to WCAG AA"
                            : "Currently using the " + Theme.name + " theme"
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallpaper.applying || ThemeCatalogue.busy
                text: Wallpaper.applying ? "Applying…" : "Deriving colours…"
                color: Theme.accent
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
            }
        }
    }
}
