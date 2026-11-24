import QtQuick
import Quickshell
import qs

// =============================================================================
// Drawer — the left-edge panel with pages.  SUPER + D, or hover the left edge.
// =============================================================================
// Anserin's left panel, rebuilt on this shell's parts: a tall card that slides
// out of the left edge with a column of page icons down its right side. Click
// an icon (or scroll over the column) to change page.
//
//   Home       wallpaper hero, greeting, clock, quick toggles, now playing,
//              calendar, quick actions          (was the SUPER + D dashboard)
//   System     rings, live CPU / memory / network graphs, busiest processes
//   Media      player, live spectrum, output volume, the EQUALIZER
//   Network    the Wi-Fi radar, same body as its own panel
//   Wallpaper  your wallpaper folder; click to set
//   Tools      screenshot / colour / record / emoji / clipboard / lock,
//              countdown timer, calculator
//
// LOOK AND MOTION
//   A floating card (inset from the edge, like every panel) with a soft accent
//   glow in its top corner, a header strip, and a rail of page icons with a
//   pill that slides to the current page. Switching pages is a real
//   transition: the old page slides out and the new one slides in from the
//   direction of travel (down the rail = up from below), crossfading. That
//   takes TWO page slots, so for the ~0.3 s of a switch the old page is still
//   alive -- it is destroyed the moment its exit finishes.
//
// SUPER + D used to open the dashboard; it opens this now, and Home IS the
// dashboard's content (the same DashClock / DashActions files, not a copy).
// The dashboard panel itself is untouched and still drops down from the
// waybar clock. If this drawer is switched off in Settings, SUPER + D falls
// back to the dashboard -- see the `drawer` IpcHandler in shell.qml.
//
// RUN ONLY WHAT IS VISIBLE
//   Only the current page exists, apart from the brief overlap of a switch
//   (see LOOK AND MOTION). Each page asks for what it needs (seconds,
//   /proc polling, the MPRIS position, a Wi-Fi scan) in its own
//   onCompleted/onDestruction, so a page's cost starts and stops with the
//   page. And Panel destroys the whole window shortly after close, which
//   takes the current page with it.
//
//   The one thing that deliberately outlives the window is a running
//   countdown: its state lives here on the panel object, not in the page, so
//   closing the drawer does not cancel your timer. Its Timer runs only while a
//   countdown is actually counting.
//
// The page you were on is remembered for as long as the shell runs, so the
// drawer reopens where you left it.
// =============================================================================

Panel {
    id: root

    name: "drawer"
    placement: "left"
    fullHeight: true
    panelWidth: 548

    property string page: "home"

    readonly property var pages: [
        { id: "home",    icon: "home",       label: "Home" },
        { id: "system",  icon: "cpu",        label: "System" },
        { id: "media",   icon: "music",      label: "Media" },
        { id: "network", icon: "radar",      label: "Network" },
        { id: "wallpaper", icon: "image-multiple", label: "Walls" },
        { id: "tools",   icon: "calculator", label: "Tools" }
    ]

    function pageIndex(id) {
        for (let i = 0; i < root.pages.length; i++)
            if (root.pages[i].id === id) return i;
        return 0;
    }

    function step(delta) {
        const n = root.pages.length;
        root.page = root.pages[(root.pageIndex(root.page) + delta + n) % n].id;
    }

    // --- countdown state (outlives the window; see header) -------------------
    property int timerTotal: 0          // seconds the countdown was set to
    property int timerLeft: 0           // seconds remaining
    property bool timerRunning: false

    function startTimer(seconds) {
        root.timerTotal = seconds;
        root.timerLeft = seconds;
        root.timerRunning = seconds > 0;
    }

    function stopTimer() {
        root.timerRunning = false;
        root.timerLeft = 0;
        root.timerTotal = 0;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.timerRunning
        onTriggered: {
            root.timerLeft = Math.max(0, root.timerLeft - 1);
            if (root.timerLeft > 0) return;
            root.timerRunning = false;
            // Through notify-send rather than this process's own server, so it
            // lands with whichever daemon is up and is not lost if the shell
            // is restarted in the meantime.
            Quickshell.execDetached(["notify-send", "-a", "Timer", "-u", "critical",
                "Time's up", "Your " + root.formatDuration(root.timerTotal) + " timer finished."]);
        }
    }

    function formatDuration(s) {
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
        const pad = (v) => (v < 10 ? "0" : "") + v;
        return h > 0 ? h + ":" + pad(m) + ":" + pad(r) : m + ":" + pad(r);
    }

    // Calculator history, newest first, kept with the timer for the same reason.
    property var calcHistory: []

    // One of the drawer's two page slots (see the stage in `content`). Each
    // carries its own scroll position and is moved, faded and scaled as a
    // whole. Declared here at the top level because an inline component cannot
    // see the ids of the object it is written inside.
    component PageSlot: Item {
        property alias loader: pageLoader
        property alias flick: scroller

        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        transformOrigin: Item.Top

        Flickable {
            id: scroller

            anchors.fill: parent
            contentWidth: width
            contentHeight: pageLoader.item ? pageLoader.item.implicitHeight + Appearance.lg : 0
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Loader {
                id: pageLoader

                width: scroller.width
            }
        }
    }


    // --- the window's content ------------------------------------------------
    content: Item {
        id: shell

        // --- ambient glow ------------------------------------------------------
        // A wash of the accent in the top-left corner, painted ONCE (it only
        // repaints if the size or the theme changes). Bleeds past the padding
        // into the card's corner, which is what makes the card read as lit
        // rather than flat.
        Canvas {
            x: -Appearance.padding
            y: -Appearance.padding
            width: parent.width * 0.9
            height: parent.height * 0.55
            renderStrategy: Canvas.Cooperative

            readonly property color tint: Theme.accent
            onTintChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const g = ctx.createRadialGradient(0, 0, 0, 0, 0, Math.max(width, height));
                g.addColorStop(0, Theme.wash(tint, 0.16));
                g.addColorStop(0.55, Theme.wash(tint, 0.04));
                g.addColorStop(1, Theme.wash(tint, 0));
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, width, height);
            }
        }

        // --- header ------------------------------------------------------------
        Item {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 48

            // Avatar: there is no ~/.face on this machine, so the initial on
            // an accent disc -- deliberate, not a missing image.
            Rectangle {
                id: avatar

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 20
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.accent }
                    GradientStop { position: 1.0; color: Theme.wash(Theme.accent, 0.55) }
                }

                Text {
                    anchors.centerIn: parent
                    text: Quickshell.env("USER").charAt(0).toUpperCase()
                    color: Theme.onAccent(Theme.accent)
                    font.family: Appearance.font
                    font.pixelSize: Appearance.size(18)
                    font.weight: Appearance.weightBold
                }
            }

            Column {
                anchors.left: avatar.right
                anchors.leftMargin: Appearance.md
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: Quickshell.env("USER")
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontLabel
                    font.weight: Appearance.weightSemi
                }

                // The page name, rolling over when the page changes.
                Item {
                    width: 160
                    height: pageName.implicitHeight
                    clip: true

                    Text {
                        id: pageName

                        text: root.pages[root.pageIndex(root.page)].label + " · " + Time.shortDate
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption

                        Behavior on text {
                            enabled: !Appearance.motionless
                            SequentialAnimation {
                                NumberAnimation { target: pageName; property: "opacity"; to: 0; duration: 90 }
                                PropertyAction { target: pageName; property: "text" }
                                NumberAnimation { target: pageName; property: "opacity"; to: 1; duration: 140 }
                            }
                        }
                    }
                }
            }

            // Status at a glance, then settings.
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.sm

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: statusRow.implicitWidth + Appearance.md * 2
                    height: Appearance.controlHeightSmall
                    radius: height / 2
                    color: Theme.wash(Theme.text, 0.06)

                    Row {
                        id: statusRow

                        anchors.centerIn: parent
                        spacing: Appearance.sm

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Network.wiredConnected ? "ethernet"
                                : Network.wifiEnabled ? "wifi-" + Network.signalBars : "wifi-off"
                            size: Appearance.fontLabel
                            color: Network.connected ? Theme.accent : Theme.muted
                        }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Bluetooth.enabled
                            name: Bluetooth.anyConnected ? "bluetooth-connected" : "bluetooth"
                            size: Appearance.fontLabel
                            color: Bluetooth.anyConnected ? Theme.accent : Theme.muted
                        }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Equalizer.enabled
                            name: "equalizer"
                            size: Appearance.fontLabel
                            color: Theme.accent
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Performance.hasBattery
                            spacing: 2

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: Performance.batteryCharging ? "battery-charging" : "battery-full"
                                size: Appearance.fontLabel
                                color: Performance.batteryPercent <= 0.15 && !Performance.batteryCharging
                                    ? Theme.error : Theme.muted
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(Performance.batteryPercent * 100) + "%"
                                color: Theme.text
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fontCaption
                                font.features: ({ "tnum": 1 })
                            }
                        }
                    }
                }

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Appearance.controlHeight
                    height: Appearance.controlHeight
                    icon: "settings"
                    variant: "ghost"
                    onClicked: Shell.open("settings")
                }
            }
        }

        Rectangle {
            id: divider

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: Appearance.md
            height: 1
            color: Theme.separator
        }

        // --- page stage --------------------------------------------------------
        // Two slots that take turns: the incoming page loads into whichever is
        // not showing, slides in over the outgoing one, and the outgoing slot is
        // emptied once its exit has played.
        Item {
            id: stage

            anchors.left: parent.left
            anchors.top: divider.bottom
            anchors.topMargin: Appearance.lg
            anchors.bottom: parent.bottom
            anchors.right: rail.left
            anchors.rightMargin: Appearance.md
            clip: true

            property int front: 0
            property string shown: ""

            readonly property var slots: [slotA, slotB]

            function componentFor(id) {
                switch (id) {
                case "system":    return systemPage;
                case "media":     return mediaPage;
                case "network":   return networkPage;
                case "wallpaper": return wallpaperPage;
                case "tools":     return toolsPage;
                default:          return homePage;
                }
            }

            function show(id, animate) {
                if (id === stage.shown) return;

                // A switch arriving mid-transition: land the current one at
                // once and drop whatever was leaving, then start fresh.
                enterAnim.stop();
                exitAnim.stop();
                const current = stage.slots[stage.front];
                const other = stage.slots[1 - stage.front];
                current.opacity = 1; current.y = 0; current.scale = 1;
                other.loader.sourceComponent = undefined;

                const dir = stage.shown === "" ? 1
                    : (root.pageIndex(id) >= root.pageIndex(stage.shown) ? 1 : -1);
                stage.shown = id;

                other.flick.contentY = 0;
                other.loader.sourceComponent = stage.componentFor(id);
                other.z = 1;
                current.z = 0;
                stage.front = 1 - stage.front;

                if (!animate || Appearance.motionless) {
                    other.opacity = 1; other.y = 0; other.scale = 1;
                    current.loader.sourceComponent = undefined;
                    return;
                }

                other.opacity = 0;
                other.y = dir * 48;
                other.scale = 0.985;
                enterAnim.targetItem = other;
                exitAnim.targetItem = current;
                exitAnim.toY = -dir * 32;
                enterAnim.start();
                exitAnim.start();
            }

            ParallelAnimation {
                id: enterAnim

                property Item targetItem: null

                NumberAnimation {
                    target: enterAnim.targetItem; property: "y"; to: 0
                    duration: Appearance.durationSlow; easing.type: Appearance.easeEnter
                }
                NumberAnimation {
                    target: enterAnim.targetItem; property: "opacity"; to: 1
                    duration: Appearance.durationSlow; easing.type: Appearance.easeStandard
                }
                NumberAnimation {
                    target: enterAnim.targetItem; property: "scale"; to: 1
                    duration: Appearance.durationSlow; easing.type: Appearance.easeEnter
                }
            }

            ParallelAnimation {
                id: exitAnim

                property Item targetItem: null
                property real toY: -32

                NumberAnimation {
                    target: exitAnim.targetItem; property: "y"; to: exitAnim.toY
                    duration: Appearance.durationNormal; easing.type: Appearance.easeExit
                }
                NumberAnimation {
                    target: exitAnim.targetItem; property: "opacity"; to: 0
                    duration: Appearance.durationNormal; easing.type: Appearance.easeExit
                }

                // The old page is gone once it has left.
                onFinished: if (exitAnim.targetItem) exitAnim.targetItem.loader.sourceComponent = undefined
            }

            Component.onCompleted: stage.show(root.page, false)

            Connections {
                target: root
                function onPageChanged() { stage.show(root.page, true); }
            }

            PageSlot { id: slotA }
            PageSlot { id: slotB }
        }

        // --- rail ---------------------------------------------------------------
        Rectangle {
            id: rail

            anchors.right: parent.right
            anchors.top: divider.bottom
            anchors.topMargin: Appearance.lg
            anchors.bottom: parent.bottom
            width: 64
            radius: Appearance.radius
            color: Theme.wash(Theme.text, 0.04)
            border.width: 1
            border.color: Theme.wash(Theme.border, 0.25)

            readonly property real itemHeight: 60

            // Scroll anywhere over the rail to flip pages, as in Anserin.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => root.step(wheel.angleDelta.y > 0 ? -1 : 1)
            }

            // The pill that marks the current page. It moves; the icons do not.
            // OutBack gives it a little overshoot, so it lands rather than stops.
            Rectangle {
                id: pill

                x: (rail.width - width) / 2
                y: Appearance.sm + root.pageIndex(root.page) * rail.itemHeight
                width: rail.width - Appearance.sm * 2
                height: rail.itemHeight
                radius: Appearance.radiusInner
                color: Theme.wash(Theme.accent, 0.18)
                border.width: 1
                border.color: Theme.wash(Theme.accent, 0.35)

                Behavior on y {
                    enabled: !Appearance.motionless
                    NumberAnimation {
                        duration: Appearance.durationSlow
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }
            }

            Column {
                anchors.top: parent.top
                anchors.topMargin: Appearance.sm
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: root.pages

                    Item {
                        id: tab

                        required property var modelData
                        readonly property bool current: root.page === tab.modelData.id

                        width: rail.width - Appearance.sm * 2
                        height: rail.itemHeight

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: tab.modelData.icon
                                size: Appearance.iconSize
                                color: tab.current ? Theme.accent
                                     : tabMouse.containsMouse ? Theme.text : Theme.muted
                                scale: tabMouse.pressed ? 0.88 : tab.current ? 1.08 : 1

                                Behavior on scale {
                                    enabled: !Appearance.motionless
                                    NumberAnimation { duration: Appearance.durationNormal; easing.type: Easing.OutBack }
                                }
                                Behavior on color {
                                    enabled: !Appearance.motionless
                                    ColorAnimation { duration: Appearance.durationFast }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tab.modelData.label
                                color: tab.current ? Theme.text : Theme.muted
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fontCaption - 2
                                font.weight: tab.current ? Appearance.weightSemi : Appearance.weightNormal
                            }
                        }

                        // A running countdown shows on its tab, so it is not
                        // forgotten behind another page.
                        Rectangle {
                            visible: tab.modelData.id === "tools" && root.timerRunning
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.accent
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                        }

                        MouseArea {
                            id: tabMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = tab.modelData.id
                        }
                    }
                }
            }

            // Power, pinned to the foot of the rail.
            Button {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.sm
                anchors.horizontalCenter: parent.horizontalCenter
                width: Appearance.controlHeight
                height: Appearance.controlHeight
                icon: "power"
                variant: "ghost"
                onClicked: Shell.open("power")
            }
        }

        // --- pages ----------------------------------------------------------------
        Component { id: homePage;      HomePage { drawer: root } }
        Component { id: systemPage;    SystemPage { drawer: root } }
        Component { id: mediaPage;     MediaPage { drawer: root } }
        Component { id: wallpaperPage; WallpaperPage { drawer: root } }
        Component { id: toolsPage;     DrawerTools { drawer: root } }

        Component {
            id: networkPage

            // Its own consumer id, so it never cancels the radar panel's scan
            // demand or the other way round.
            NetworkRadarBody {
                consumerId: "drawer-network"
                radarHeight: 330
                showClose: false
            }
        }
    }
}
