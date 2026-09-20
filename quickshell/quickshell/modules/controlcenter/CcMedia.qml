import QtQuick
import qs

// =============================================================================
// Control Center — the now-playing card.
// =============================================================================
// Album art, title, artist, transport and a seek bar. The art is loaded
// asynchronously and at a capped resolution: MPRIS art URLs are frequently
// full-size album covers, and decoding a 3000px JPEG to draw it at 56px is a
// real stall on a panel that is meant to open instantly.
// =============================================================================

Card {
    id: root

    elevation: 0
    implicitHeight: layout.implicitHeight + Appearance.md * 2

    Column {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.md
        spacing: Appearance.sm

        Row {
            width: parent.width
            spacing: Appearance.md

            // --- art ------------------------------------------------------
            Rectangle {
                id: artFrame

                width: 56
                height: 56
                radius: Appearance.radiusSmall
                color: Theme.wash(Theme.text, 0.06)
                clip: true

                Image {
                    anchors.fill: parent
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    // Never block the panel opening on a network or disk read.
                    asynchronous: true
                    // Decode at the size actually drawn. Without this a large
                    // cover is decoded at full resolution into memory.
                    sourceSize.width: 112
                    sourceSize.height: 112
                    visible: status === Image.Ready

                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity {
                        enabled: !Appearance.motionless
                        NumberAnimation { duration: Appearance.durationSlow }
                    }
                }

                // Shown until the art arrives, and for players that supply none.
                Icon {
                    anchors.centerIn: parent
                    name: "music"
                    size: Appearance.iconSizeLarge
                    color: Theme.muted
                    visible: Media.artUrl === ""
                }
            }

            // --- text -----------------------------------------------------
            Column {
                width: parent.width - artFrame.width - Appearance.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: Media.title !== "" ? Media.title : "Nothing playing"
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontLabel
                    font.weight: Appearance.weightMedium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: Media.artist !== ""
                    text: Media.artist
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSmall
                    elide: Text.ElideRight
                }

                Row {
                    spacing: Appearance.xs

                    Button {
                        width: Appearance.controlHeightSmall
                        height: Appearance.controlHeightSmall
                        variant: "ghost"
                        icon: "previous"
                        enabled: Media.available && Media.player.canGoPrevious
                        onClicked: Media.previous()
                    }

                    Button {
                        width: Appearance.controlHeightSmall
                        height: Appearance.controlHeightSmall
                        variant: Media.playing ? "accent" : "soft"
                        icon: Media.playing ? "pause" : "play"
                        enabled: Media.available && Media.player.canTogglePlaying
                        onClicked: Media.playPause()
                    }

                    Button {
                        width: Appearance.controlHeightSmall
                        height: Appearance.controlHeightSmall
                        variant: "ghost"
                        icon: "next"
                        enabled: Media.available && Media.player.canGoNext
                        onClicked: Media.next()
                    }
                }
            }
        }

        // --- seek --------------------------------------------------------
        Item {
            width: parent.width
            visible: Media.hasPosition
            implicitHeight: 14

            Rectangle {
                id: seekTrack

                width: parent.width
                height: 4
                radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.wash(Theme.border, 0.4)

                Rectangle {
                    width: parent.width * Media.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent

                    // Follows a once-a-second position read, so a linear
                    // animation of exactly that length makes it glide instead
                    // of stepping.
                    Behavior on width {
                        enabled: !Appearance.motionless && Media.playing
                        NumberAnimation { duration: 1000; easing.type: Easing.Linear }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: Media.available && Media.player.canSeek
                onClicked: (e) => Media.seek(e.x / width)
            }
        }

        Item {
            width: parent.width
            visible: Media.hasPosition
            implicitHeight: elapsed.implicitHeight

            Text {
                id: elapsed
                anchors.left: parent.left
                text: Media.formatTime(Media.position)
                color: Theme.muted
                font.family: Appearance.fontMono
                font.pixelSize: Appearance.fontCaption
            }

            Text {
                anchors.right: parent.right
                text: Media.formatTime(Media.length)
                color: Theme.muted
                font.family: Appearance.fontMono
                font.pixelSize: Appearance.fontCaption
            }
        }
    }
}
