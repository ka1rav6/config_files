import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs

// =============================================================================
// MediaPage — now playing, the sound itself, and the equalizer.
// =============================================================================
//   player      big cover art over a blurred copy of itself, title, artist,
//               a seek bar you can click, transport buttons
//   spectrum    live bars from the shared cava process, while something plays
//   output      volume, mute, and which device it is going to
//   equalizer   parts/EqualizerCard.qml -- see services/Equalizer.qml
//
// WHAT RUNS, AND ONLY WHILE THIS PAGE IS UP
//   * the MPRIS position tick (for the seek bar)
//   * a cava demand for 32 bands, which shares the one cava process with the
//     desktop visualizer; cava itself still idles when nothing is playing
//   * the backdrop blur: one MultiEffect over a 128 px thumbnail, which is
//     about as cheap as a blur gets
// The equalizer is the exception by design: it is audio processing, not
// decoration, so when it is on it runs whether this page is open or not.
// =============================================================================

Column {
    id: root

    required property var drawer

    spacing: Appearance.lg

    readonly property int spectrumBands: 32

    Component.onCompleted: {
        Media.wantPosition("drawer-media");
        Cava.want("drawer-media", root.spectrumBands);
    }
    Component.onDestruction: {
        Media.dropPosition("drawer-media");
        Cava.drop("drawer-media");
    }

    readonly property bool hasMedia: Media.available && Settings.features.music

    PageHeader {
        title: "Media"
        subtitle: root.hasMedia ? "Playing in " + Media.identity : "Nothing playing"
    }

    // --- player --------------------------------------------------------------------
    ClippingRectangle {
        width: parent.width
        height: playerColumn.implicitHeight + Appearance.lg * 2
        radius: Appearance.radius
        color: Theme.wash(Theme.surface2, 0.6)
        visible: root.hasMedia

        // Backdrop: the cover, blurred and dimmed, filling the card.
        Image {
            id: backdropArt

            anchors.fill: parent
            source: Media.artUrl
            sourceSize.width: 128
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: backdropArt
            visible: Media.artUrl !== ""
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.2
            brightness: -0.25
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.wash(Theme.bg, 0.45)
        }

        Column {
            id: playerColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.lg
            spacing: Appearance.md

            Row {
                width: parent.width
                spacing: Appearance.lg

                ClippingRectangle {
                    id: art

                    width: 132
                    height: 132
                    radius: Appearance.radiusInner
                    color: Theme.wash(Theme.text, 0.08)

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        sourceSize.width: 264
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: Media.artUrl === ""
                        name: "music"
                        size: Appearance.iconSizeLarge * 2
                        color: Theme.muted
                    }
                }

                Column {
                    width: parent.width - art.width - parent.spacing
                    anchors.verticalCenter: art.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: Media.title || "Unknown title"
                        color: Theme.text
                        font.family: Appearance.font
                        font.pixelSize: Appearance.size(19)
                        font.weight: Appearance.weightBold
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Media.artist
                        visible: text !== ""
                        color: Theme.text
                        opacity: 0.8
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontBody
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Media.album
                        visible: text !== ""
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        elide: Text.ElideRight
                    }
                }
            }

            // Seek bar.
            Column {
                width: parent.width
                spacing: 4
                visible: Media.hasPosition

                Item {
                    width: parent.width
                    height: 14

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 5
                        radius: 2.5
                        color: Theme.wash(Theme.text, 0.15)

                        Rectangle {
                            width: parent.width * Media.progress
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                        }
                    }

                    Rectangle {
                        x: parent.width * Media.progress - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: seekMouse.containsMouse ? 14 : 10
                        height: width
                        radius: width / 2
                        color: Theme.accent

                        Behavior on width {
                            enabled: !Appearance.motionless
                            NumberAnimation { duration: Appearance.durationFast }
                        }
                    }

                    MouseArea {
                        id: seekMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: (mouse) => Media.seek(mouse.x / width)
                    }
                }

                Item {
                    width: parent.width
                    height: posText.implicitHeight

                    Text {
                        id: posText

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

            // Transport.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Appearance.lg

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Appearance.controlHeight
                    height: Appearance.controlHeight
                    icon: "previous"
                    variant: "ghost"
                    onClicked: Media.previous()
                }

                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    color: Theme.accent
                    scale: playMouse.pressed ? 0.92 : playMouse.containsMouse ? 1.06 : 1

                    Behavior on scale {
                        enabled: !Appearance.motionless
                        NumberAnimation { duration: Appearance.durationFast; easing.type: Appearance.easeStandard }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: Media.playing ? "pause" : "play"
                        size: Appearance.iconSizeLarge
                        color: Theme.onAccent(Theme.accent)
                    }

                    MouseArea {
                        id: playMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.playPause()
                    }
                }

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Appearance.controlHeight
                    height: Appearance.controlHeight
                    icon: "next"
                    variant: "ghost"
                    onClicked: Media.next()
                }
            }

            // Spectrum.
            Row {
                id: spectrum

                width: parent.width
                height: 42
                spacing: 3
                visible: Media.playing

                readonly property real barWidth: (width - spacing * (root.spectrumBands - 1)) / root.spectrumBands

                Repeater {
                    model: root.spectrumBands

                    Rectangle {
                        required property int index

                        // cava serves the finest resolution anyone asked for,
                        // which may be more than 32 -- sample across it.
                        readonly property real level: {
                            const l = Cava.levels;
                            if (!l || l.length === 0) return 0;
                            return l[Math.floor(index * l.length / root.spectrumBands)] || 0;
                        }

                        anchors.bottom: parent.bottom
                        width: spectrum.barWidth
                        height: Math.max(3, level * spectrum.height)
                        radius: Math.min(2, width / 2)
                        color: Theme.wash(Theme.accent, 0.45 + level * 0.55)
                    }
                }
            }
        }
    }

    // Nothing playing.
    Card {
        width: parent.width
        elevation: 0
        visible: !root.hasMedia
        implicitHeight: 150

        Column {
            anchors.centerIn: parent
            spacing: Appearance.sm

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "music"
                size: Appearance.iconSizeLarge * 2
                color: Theme.wash(Theme.muted, 0.6)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Settings.features.music ? "Start something in any player" : "Media controls are off in Settings"
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
            }
        }
    }

    // --- output --------------------------------------------------------------------
    Card {
        width: parent.width
        elevation: 0
        implicitHeight: outColumn.implicitHeight + Appearance.md * 2

        Column {
            id: outColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            spacing: Appearance.sm

            Item {
                width: parent.width
                height: outLabel.implicitHeight

                Text {
                    id: outLabel

                    text: "OUTPUT"
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.letterSpacing: Appearance.trackingLabel
                }

                Text {
                    anchors.right: parent.right
                    anchors.left: outLabel.right
                    anchors.leftMargin: Appearance.md
                    horizontalAlignment: Text.AlignRight
                    text: Audio.sinkName
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    elide: Text.ElideLeft
                }
            }

            Slider {
                width: parent.width
                icon: Audio.muted ? "volume-mute" : "volume-high"
                value: Audio.muted ? 0 : Audio.volume
                onMoved: (v) => Audio.setVolume(v)
            }
        }
    }

    // --- equalizer -----------------------------------------------------------------
    EqualizerCard {
        width: parent.width
    }
}
