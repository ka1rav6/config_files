import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs

// =============================================================================
// The lock surface — one per monitor.
// =============================================================================
// The wallpaper, dimmed, with a single card in the middle: the time, who you
// are, and a field to type into. Everything else on screen is deliberately
// quiet — a lock screen is read in a half-second glance, and anything that is
// not the clock or the password field is competing with them.
//
// Only the focused monitor gets the card. The others show the clock alone, so
// a dual-monitor setup does not present two password fields and make you guess
// which one has the keyboard.
// =============================================================================

WlSessionLockSurface {
    id: surface

    color: "transparent"

    // The card goes where the pointer already is. With two monitors there is
    // no right answer, so it follows the one the compositor gave focus to.
    readonly property bool primary: Hypr.isActiveScreen(surface.screen)

    // --- background -------------------------------------------------------
    Image {
        id: shot

        anchors.fill: parent
        source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true

        // A slow drift, so the lock screen is not a still frame. Barely
        // perceptible per second, obvious after a minute.
        scale: 1.06
        SequentialAnimation on scale {
            running: !Appearance.motionless
            loops: Animation.Infinite
            NumberAnimation { to: 1.12; duration: 24000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.06; duration: 24000; easing.type: Easing.InOutSine }
        }
    }

    // Two scrims rather than one: a flat dim for legibility, plus a vertical
    // gradient that weights the bottom, where the status line sits.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }

    // Everything fades and lifts in together on lock, which is what stops it
    // reading as a screenshot that happened to appear.
    Item {
        id: stage

        anchors.fill: parent
        opacity: 0
        Component.onCompleted: stage.opacity = 1

        Behavior on opacity {
            enabled: !Appearance.motionless
            NumberAnimation { duration: 420; easing.type: Easing.OutQuint }
        }

        // --- clock --------------------------------------------------------
        Column {
            id: clock

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: surface.height * (surface.primary ? 0.17 : 0.38)
            spacing: -6

            Behavior on anchors.topMargin {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationSlow; easing.type: Appearance.easeStandard }
            }

            Text {
                text: Time.time
                color: "white"
                font.family: Appearance.font
                font.pixelSize: 128
                font.weight: Font.Thin
                font.letterSpacing: -4
                font.features: ({ "tnum": 1 })
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: Time.longDate
                color: Qt.rgba(1, 1, 1, 0.66)
                font.family: Appearance.font
                font.pixelSize: 19
                font.weight: Font.Light
                font.letterSpacing: 3
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // --- the lock widget ------------------------------------------------
        LockWidget {
            id: widget

            visible: surface.primary
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clock.bottom
            anchors.topMargin: 58

            onUnlocked: if (Shell.lock) Shell.lock.unlock()
        }

        // --- now playing ------------------------------------------------------
        // Read-only. A lock screen that takes media input is a lock screen that
        // takes input, and the media keys already work while locked.
        Row {
            visible: surface.primary && Media.available && Media.title !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 92
            spacing: Appearance.sm

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Media.playing ? "play" : "pause"
                size: 14
                color: Qt.rgba(1, 1, 1, 0.5)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Media.title + (Media.artist !== "" ? "  ·  " + Media.artist : "")
                color: Qt.rgba(1, 1, 1, 0.5)
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                elide: Text.ElideRight
                width: Math.min(implicitWidth, surface.width * 0.4)
            }
        }

        // --- status line ------------------------------------------------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 44
            spacing: Appearance.lg

            Row {
                spacing: Appearance.xs

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Network.wiredConnected ? "ethernet"
                        : Network.wifiEnabled ? "wifi-" + Network.signalBars : "wifi-off"
                    size: 14
                    color: Qt.rgba(1, 1, 1, 0.45)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Network.summary
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                }
            }

            Row {
                spacing: Appearance.xs
                visible: Performance.hasBattery

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Performance.batteryCharging ? "battery-charging" : "battery-full"
                    size: 14
                    color: Qt.rgba(1, 1, 1, 0.45)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Performance.batteryPercent * 100) + "%"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }

    // Any key or click anywhere on a secondary monitor is a request to type,
    // so it pulls the caret back to the one screen that has the field.
    MouseArea {
        anchors.fill: parent
        onClicked: if (surface.primary) widget.focusField()
    }
}
