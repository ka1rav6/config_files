import QtQuick
import Quickshell
import qs

// =============================================================================
// Control Center — the quick-settings panel.  SUPER + A
// =============================================================================
// Replaces, in one surface, everything that used to be a separate click target
// in waybar: the Wi-Fi menu (a 167-line shell script driving wofi), the volume
// and microphone sliders and the brightness slider (three GTK popups spawned
// from a 433-line Python program), the Bluetooth applet, and the power-profile
// module. One panel, one visual language, no subprocesses.
//
// STRUCTURE
//   It is a stack of pages, not a scrolling wall of settings:
//
//     main  ─┬─► wifi       pick a network, type a passphrase
//            ├─► bluetooth  pair and connect devices
//            └─► audio      choose output and input devices
//
//   The chevron on a tile pushes its page; the back arrow pops it. Pages are
//   Loaders, so an unvisited page has never been constructed -- which is also
//   what keeps the scanning gates honest (see the `scanning` bindings below).
//
// WHAT IS DELIBERATELY NOT HERE
//   Anything you set once and forget. Monitor layout, fonts, animation speed,
//   widget placement -- those live in Settings (SUPER + ,). The test for
//   belonging here is "would I want this while a video call is ringing": if
//   not, it goes in Settings.
// =============================================================================

Panel {
    id: root

    name: "control-center"
    placement: "top-right"
    panelWidth: 400

    // Which page is showing. Reset to main on close so reopening always starts
    // somewhere predictable rather than wherever it was left days ago.
    property string page: "main"

    onClosed: pageReset.restart()

    Timer {
        id: pageReset

        // After the close animation, so the panel does not visibly snap back
        // to the main page while it is fading out.
        interval: Appearance.durationSlow + 40
        onTriggered: if (!root.open) root.page = "main"
    }

    // --- scanning gates -------------------------------------------------
    // The battery-relevant part of this whole panel. A Wi-Fi scan wakes the
    // radio and Bluetooth discovery keeps it transmitting; both are switched on
    // ONLY while their page is actually being looked at, and off the instant it
    // is left or the panel is closed. See the headers of services/Network.qml
    // and services/Bluetooth.qml.
    Binding {
        target: Network
        property: "scanning"
        value: root.open && root.page === "wifi"
    }

    Binding {
        target: Bluetooth
        property: "scanning"
        value: root.open && root.page === "bluetooth"
    }

    // Likewise the MPRIS position poll: only ticking while the media card is
    // on screen and something is playing. Demand is reference counted, so
    // closing this panel no longer stops the tick for the desktop media widget
    // or the dashboard.
    readonly property bool wantsPosition: root.open && root.page === "main"

    onWantsPositionChanged: {
        if (root.wantsPosition) Media.wantPosition("control-center");
        else Media.dropPosition("control-center");
    }

    Component.onDestruction: Media.dropPosition("control-center")

    content: Item {
        // The Card sizes to this, so the content must report a height --
        // an Item with only anchored children reports zero.
        implicitHeight: pages.implicitHeight

        // Cross-fade plus a small horizontal slide between pages, so pushing a
        // page reads as going deeper rather than as the panel's contents being
        // swapped out.
        Item {
            id: pages

            width: parent.width
            implicitHeight: activePage.item ? activePage.item.implicitHeight : 0

            Behavior on implicitHeight {
                enabled: !Appearance.motionless
                NumberAnimation {
                    duration: Appearance.durationNormal
                    easing.type: Appearance.easeStandard
                }
            }

            Loader {
                id: activePage

                width: parent.width
                sourceComponent: {
                    switch (root.page) {
                    case "wifi": return wifiPage;
                    case "bluetooth": return bluetoothPage;
                    case "audio": return audioPage;
                    default: return mainPage;
                    }
                }

                // Re-run the entrance every time the page changes.
                onSourceComponentChanged: {
                    if (Appearance.motionless) return;
                    activePage.opacity = 0;
                    activePage.x = root.page === "main" ? -12 : 12;
                    enter.restart();
                }

                ParallelAnimation {
                    id: enter

                    NumberAnimation {
                        target: activePage; property: "opacity"; to: 1
                        duration: Appearance.durationNormal
                        easing.type: Appearance.easeStandard
                    }
                    NumberAnimation {
                        target: activePage; property: "x"; to: 0
                        duration: Appearance.durationNormal
                        easing.type: Appearance.easeEnter
                    }
                }
            }
        }

        Component { id: mainPage;      CcMain { onNavigate: (p) => root.page = p } }
        Component { id: wifiPage;      CcWifi { onBack: root.page = "main" } }
        Component { id: bluetoothPage; CcBluetooth { onBack: root.page = "main" } }
        Component { id: audioPage;     CcAudio { onBack: root.page = "main" } }
    }
}
