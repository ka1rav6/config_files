import QtQuick
import qs

// =============================================================================
// Now playing — a real player, not a readout.
// =============================================================================
// This is the one desktop widget that takes input. The widget layer is
// click-through everywhere else (see Widgets.qml); this widget's rectangle is
// punched out of that mask, so its buttons and its seek bar work while the rest
// of the desktop stays click-through.
//
// Everything it drives goes through services/Media.qml, which is guarded on
// the player's own can* properties -- so a player that cannot seek gets a bar
// that does not pretend to, rather than a control that silently does nothing.
// =============================================================================

DesktopWidget {
    id: root

    widgetId: "media"
    defaultX: 0.035
    defaultY: 0.34
    contentWidth: 352
    contentHeight: 134

    // The seek bar needs a position to show, and the position tick is
    // reference-counted -- so ask for it only while this widget is actually on
    // screen. An unshown media widget costs no D-Bus reads at all.
    onVisibleChanged: {
        if (root.visible) Media.wantPosition("desktop-media");
        else Media.dropPosition("desktop-media");
    }

    Component.onCompleted: if (root.visible) Media.wantPosition("desktop-media")
    Component.onDestruction: Media.dropPosition("desktop-media")

    Row {
        anchors.fill: parent
        spacing: Appearance.md

        // --- artwork ------------------------------------------------------
        // Clicking it raises the player window, which is what you want when
        // the widget has told you what is playing and you now want the app.
        Rectangle {
            id: artFrame

            width: parent.height
            height: parent.height
            radius: Appearance.radiusInner
            color: Theme.wash(Theme.text, 0.08)
            clip: true

            Image {
                id: art

                anchors.fill: parent
                source: Media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: art.status === Image.Ready

                opacity: art.status === Image.Ready ? 1 : 0
                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationSlow }
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "music"
                size: Appearance.iconSizeLarge
                color: Theme.muted
                visible: art.status !== Image.Ready
            }

            // Hover veil with a "go to the app" hint. Only offered when the
            // player actually supports being raised.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.55)
                opacity: artMouse.containsMouse && !root.editing ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationFast }
                }

                Icon {
                    anchors.centerIn: parent
                    name: "monitor"
                    size: Appearance.iconSize
                    color: "white"
                }
            }

            MouseArea {
                id: artMouse

                anchors.fill: parent
                hoverEnabled: !root.editing
                enabled: !root.editing
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.raise()
            }
        }

        // --- text, seek bar, transport --------------------------------------
        Column {
            width: parent.width - parent.height - Appearance.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.xs

            Text {
                width: parent.width
                text: Media.title !== "" ? Media.title : "Nothing playing"
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontLabel
                font.weight: Appearance.weightSemi
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: Media.artist !== "" ? Media.artist : Media.identity
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                elide: Text.ElideRight
            }

            // --- seek bar ---------------------------------------------------
            // Click anywhere on it to jump; drag the head to scrub. The bar
            // thickens on hover so there is something to aim at without it
            // being a heavy element the rest of the time.
            Item {
                id: seek

                width: parent.width
                height: 16
                visible: Media.hasPosition

                // While scrubbing, the bar follows the pointer rather than the
                // player -- otherwise the 1 Hz position tick fights the drag
                // and the head stutters back under your cursor.
                property bool scrubbing: false
                property real scrubValue: 0
                readonly property real shown: seek.scrubbing ? seek.scrubValue : Media.progress

                Rectangle {
                    id: track

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekMouse.containsMouse || seek.scrubbing ? 6 : 3
                    radius: height / 2
                    color: Theme.wash(Theme.text, 0.14)

                    Behavior on height {
                        enabled: !Appearance.motionless
                        NumberAnimation { duration: Appearance.durationFast }
                    }

                    Rectangle {
                        width: parent.width * seek.shown
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent

                        // Never animate a drag -- the head has to stay under
                        // the cursor. Only the 1 Hz playback tick glides.
                        Behavior on width {
                            enabled: !Appearance.motionless && !seek.scrubbing
                            NumberAnimation { duration: Appearance.durationNormal }
                        }
                    }
                }

                Rectangle {
                    id: head

                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.accent
                    anchors.verticalCenter: track.verticalCenter
                    x: Math.max(0, Math.min(track.width - width,
                                            track.width * seek.shown - width / 2))
                    opacity: seekMouse.containsMouse || seek.scrubbing ? 1 : 0

                    Behavior on opacity {
                        enabled: !Appearance.motionless
                        NumberAnimation { duration: Appearance.durationFast }
                    }

                    Behavior on x {
                        enabled: !Appearance.motionless && !seek.scrubbing
                        NumberAnimation { duration: Appearance.durationNormal }
                    }
                }

                MouseArea {
                    id: seekMouse

                    anchors.fill: parent
                    hoverEnabled: !root.editing
                    // A player that cannot seek gets a progress bar, not a
                    // control that quietly ignores you.
                    enabled: !root.editing && Media.available
                        && Media.player && Media.player.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                    function fractionAt(mx) {
                        return Math.max(0, Math.min(1, mx / Math.max(1, track.width)));
                    }

                    onPressed: (mouse) => {
                        seek.scrubValue = seekMouse.fractionAt(mouse.x);
                        seek.scrubbing = true;
                    }

                    onPositionChanged: (mouse) => {
                        if (seek.scrubbing) seek.scrubValue = seekMouse.fractionAt(mouse.x);
                    }

                    onReleased: {
                        Media.seek(seek.scrubValue);
                        seek.scrubbing = false;
                    }

                    onCanceled: seek.scrubbing = false
                }
            }

            // --- transport + times ---------------------------------------------
            Item {
                width: parent.width
                height: 30

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.formatTime(seek.scrubbing
                        ? seek.scrubValue * Media.length : Media.position)
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.features: ({ "tnum": 1 })
                    visible: Media.hasPosition
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.xs

                    Repeater {
                        model: [
                            { icon: "previous", act: "previous", big: false },
                            { icon: Media.playing ? "pause" : "play", act: "playPause", big: true },
                            { icon: "next", act: "next", big: false }
                        ]

                        Rectangle {
                            id: btn

                            required property var modelData

                            readonly property bool primary: modelData.big
                            readonly property bool usable: {
                                if (!Media.available || !Media.player) return false;
                                if (modelData.act === "next") return Media.player.canGoNext;
                                if (modelData.act === "previous") return Media.player.canGoPrevious;
                                return Media.player.canTogglePlaying;
                            }

                            width: btn.primary ? 30 : 26
                            height: width
                            radius: width / 2

                            color: !btn.usable ? "transparent"
                                : btn.primary ? Theme.wash(Theme.accent, btnMouse.containsMouse ? 0.30 : 0.18)
                                : btnMouse.containsMouse ? Theme.wash(Theme.text, 0.12) : "transparent"

                            Behavior on color {
                                enabled: !Appearance.motionless
                                ColorAnimation { duration: Appearance.durationFast }
                            }

                            scale: btnMouse.pressed ? 0.88 : 1.0

                            Behavior on scale {
                                enabled: !Appearance.motionless
                                NumberAnimation {
                                    duration: Appearance.durationFast
                                    easing.type: Appearance.easeStandard
                                }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: btn.modelData.icon
                                size: btn.primary ? 16 : 14
                                color: !btn.usable ? Theme.wash(Theme.text, 0.25)
                                    : btn.primary ? Theme.accent
                                    : btnMouse.containsMouse ? Theme.text : Theme.muted
                            }

                            MouseArea {
                                id: btnMouse

                                anchors.fill: parent
                                hoverEnabled: !root.editing
                                enabled: !root.editing && btn.usable
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (btn.modelData.act === "previous") Media.previous();
                                    else if (btn.modelData.act === "next") Media.next();
                                    else Media.playPause();
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.formatTime(Media.length)
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.features: ({ "tnum": 1 })
                    visible: Media.hasPosition
                }
            }
        }
    }

    // Scrolling over the widget changes the volume -- the gesture everyone
    // tries on a player, and the one thing you reach for without wanting to
    // look at the screen.
    WheelHandler {
        enabled: !root.editing
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => Audio.setVolume(Audio.volume + (event.angleDelta.y > 0 ? 0.03 : -0.03))
    }
}
