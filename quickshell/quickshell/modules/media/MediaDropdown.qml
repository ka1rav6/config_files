import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs

// =============================================================================
// MediaDropdown — now playing, hanging from the bar.
// =============================================================================
// Opened by hovering the bar's media pill (see the bar hover notes in
// ~/.config/waybar), by clicking it, or `quickshell ipc call media toggle`.
// It drops out of the bar like the clock's dashboard (ui/Panel.qml, "drop
// entrance") and is the compact sibling of the drawer's Media page: blurred
// cover backdrop, cover, title, seek bar, transport, and a small live spectrum.
//
// MOTION
//   On a track change the cover crossfades to the new art with a small settle,
//   and the title and artist slide in. All of it routes through Appearance's
//   durations, so it is instant with motion off or in battery saver.
//
// WHAT RUNS, AND ONLY WHILE IT IS OPEN
//   The MPRIS position tick (seek bar) and a 24-band cava demand for the
//   spectrum strip; both are dropped the moment it closes. Panel is a lazy
//   loader, so while closed nothing here exists at all.
// =============================================================================
Panel {
    id: root

    name: "media"
    panelWidth: 380
    placement: "top-center"

    readonly property string consumerId: "media-dropdown"
    readonly property int bands: 24

    onOpened: {
        Media.wantPosition(root.consumerId);
        Cava.want(root.consumerId, root.bands);
    }
    onClosed: {
        Media.dropPosition(root.consumerId);
        Cava.drop(root.consumerId);
    }
    Component.onDestruction: {
        Media.dropPosition(root.consumerId);
        Cava.drop(root.consumerId);
    }

    content: Item {
        implicitHeight: Media.available ? body.implicitHeight : empty.implicitHeight

        // --- nothing playing ---------------------------------------------
        Column {
            id: empty

            visible: !Media.available
            width: parent.width
            topPadding: Appearance.lg
            bottomPadding: Appearance.lg
            spacing: Appearance.sm

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "music"
                size: Appearance.iconSizeLarge * 2
                color: Theme.wash(Theme.muted, 0.6)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing playing"
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
            }
        }

        // --- player --------------------------------------------------------
        ClippingRectangle {
            id: body

            visible: Media.available
            width: parent.width
            implicitHeight: column.implicitHeight + Appearance.md * 2
            radius: Appearance.radiusInner
            color: Theme.wash(Theme.surface2, 0.6)

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
                id: column

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.md
                spacing: Appearance.sm

                Row {
                    width: parent.width
                    spacing: Appearance.md

                    // Cover: two slots, the new art fades in over the old.
                    ClippingRectangle {
                        id: cover

                        width: 84
                        height: 84
                        radius: Appearance.radiusInner
                        color: Theme.wash(Theme.text, 0.08)

                        property string shown: Media.artUrl
                        property bool flip: false

                        onShownChanged: {
                            cover.flip = !cover.flip;
                            (cover.flip ? artB : artA).source = cover.shown;
                            settle.restart();
                        }
                        Component.onCompleted: artA.source = cover.shown

                        Image {
                            id: artA
                            anchors.fill: parent
                            sourceSize.width: 168
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: cover.flip ? 0 : 1
                            Behavior on opacity {
                                enabled: !Appearance.motionless
                                NumberAnimation { duration: Appearance.durationSlow; easing.type: Appearance.easeStandard }
                            }
                        }
                        Image {
                            id: artB
                            anchors.fill: parent
                            sourceSize.width: 168
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: cover.flip ? 1 : 0
                            Behavior on opacity {
                                enabled: !Appearance.motionless
                                NumberAnimation { duration: Appearance.durationSlow; easing.type: Appearance.easeStandard }
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: Media.artUrl === ""
                            name: "music"
                            size: Appearance.iconSizeLarge * 1.5
                            color: Theme.muted
                        }

                        // A small settle on each new cover.
                        SequentialAnimation {
                            id: settle
                            NumberAnimation { target: cover; property: "scale"; to: 0.94; duration: Appearance.duration(90); easing.type: Appearance.easeStandard }
                            NumberAnimation { target: cover; property: "scale"; to: 1; duration: Appearance.durationSlow; easing.type: Appearance.easeEmphasised }
                        }
                    }

                    // Title and artist; slide in on a track change.
                    Item {
                        id: info

                        width: parent.width - cover.width - parent.spacing
                        height: cover.height
                        clip: true

                        readonly property string key: Media.title + "\n" + Media.artist
                        property real slide: 0

                        onKeyChanged: if (!Appearance.motionless) { info.slide = 1; slideIn.restart(); }

                        NumberAnimation {
                            id: slideIn
                            target: info
                            property: "slide"
                            to: 0
                            duration: Appearance.durationSlow
                            easing.type: Appearance.easeEnter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            spacing: 2
                            opacity: 1 - info.slide
                            transform: Translate { x: info.slide * 24 }

                            Text {
                                width: parent.width
                                text: Media.title || "Unknown title"
                                color: Theme.text
                                font.family: Appearance.font
                                font.pixelSize: Appearance.size(16)
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
                                font.pixelSize: Appearance.fontSmall
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: Media.identity
                                visible: text !== ""
                                color: Theme.muted
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fontCaption
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Seek bar: click anywhere on it to jump.
                Column {
                    width: parent.width
                    spacing: 2
                    visible: Media.hasPosition

                    Item {
                        width: parent.width
                        height: 14

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
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
                            width: seekMouse.containsMouse ? 12 : 8
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
                        width: 46
                        height: 46
                        radius: 23
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

                // A small live spectrum while it plays.
                Row {
                    id: spectrum

                    width: parent.width
                    height: 24
                    spacing: 3
                    visible: Media.playing && Performance.allowVisualizer

                    readonly property real barWidth: (width - spacing * (root.bands - 1)) / root.bands

                    Repeater {
                        model: spectrum.visible ? root.bands : 0

                        Rectangle {
                            required property int index
                            readonly property real level: {
                                const l = Cava.levels;
                                if (!l || l.length === 0) return 0;
                                return l[Math.floor(index * l.length / root.bands)] || 0;
                            }
                            anchors.bottom: parent.bottom
                            width: spectrum.barWidth
                            height: Math.max(2, level * spectrum.height)
                            radius: Math.min(2, width / 2)
                            color: Theme.wash(Theme.accent, 0.45 + level * 0.55)
                        }
                    }
                }
            }
        }
    }
}
