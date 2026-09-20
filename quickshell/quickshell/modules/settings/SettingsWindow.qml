import QtQuick
import Quickshell
import qs

// =============================================================================
// Settings.  SUPER + ,
// =============================================================================
// The thing this desktop did not have: one place to configure it, instead of
// `just theme`, a Python slider popup, a shell script driving wofi, and editing
// QML by hand.
//
// WHAT IT IS NOT
//   It is not a control panel for the operating system. Monitors, Wi-Fi
//   profiles and per-app audio routing have real tools already
//   (nm-connection-editor, pavucontrol) and this links to them rather than
//   reimplementing them badly. What lives here is everything about the
//   DESKTOP SHELL, which previously had no interface at all.
//
// HOW IT SAVES
//   Every control writes straight to the matching property in
//   config/Settings.qml, which persists to ~/.config/quickshell/settings.json
//   on a 400 ms debounce. There is no Apply button and no separate "pending"
//   state to keep in sync -- a slider moves and the desktop changes under it.
//   The one exception is the theme, which goes through theme-switch (see
//   SettingsAppearance.qml) because it has to retheme nine other applications
//   too, and that is a several-second operation with its own progress.
//
// THE CONFIG FILE REMAINS EDITABLE
//   settings.json is watched, so editing it in Neovim updates a running
//   Settings window live. The GUI is a front-end to that file, never a
//   replacement for it.
// =============================================================================

Panel {
    id: root

    name: "settings"
    placement: "center"
    panelWidth: Appearance.modalWidth
    panelHeight: Appearance.modalHeight
    scrim: true

    property string page: "appearance"

    readonly property var pages: [
        { id: "appearance",  label: "Appearance",  icon: "palette" },
        { id: "desktop",     label: "Desktop",     icon: "desktop" },
        { id: "audio",       label: "Audio",       icon: "volume-high" },
        { id: "network",     label: "Network",     icon: "wifi-4" },
        { id: "shell",       label: "Dock & Launcher", icon: "dock" },
        { id: "components",  label: "Components",  icon: "widgets" },
        { id: "visualizer",  label: "Visualizer",  icon: "visualizer" },
        { id: "performance", label: "Performance", icon: "performance" },
        { id: "system",      label: "System",      icon: "settings" },
        { id: "about",       label: "About",       icon: "info" }
    ]

    content: Item {

        // --- sidebar ------------------------------------------------------
        Column {
            id: sidebar

            width: 190
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: Appearance.xs

            Text {
                text: "Settings"
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontHeading
                font.weight: Appearance.weightSemi
                font.letterSpacing: Appearance.trackingHeading
                bottomPadding: Appearance.md
            }

            Repeater {
                model: root.pages

                Rectangle {
                    required property var modelData

                    width: sidebar.width
                    height: Appearance.controlHeight
                    radius: Appearance.radiusInner

                    readonly property bool selected: root.page === modelData.id

                    color: selected ? Theme.wash(Theme.accent, 0.18)
                         : navMouse.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }

                    // A thin accent bar on the selected item, so the current
                    // page is readable even at a glance across the window.
                    Rectangle {
                        width: 3
                        height: parent.height * 0.5
                        radius: 2
                        color: Theme.accent
                        opacity: parent.selected ? 1 : 0
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on opacity {
                            enabled: !Appearance.motionless
                            NumberAnimation { duration: Appearance.durationNormal }
                        }
                    }

                    Icon {
                        id: navIcon
                        name: modelData.icon
                        size: Appearance.iconSize
                        color: parent.selected ? Theme.accent : Theme.muted
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.md
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.left: navIcon.right
                        anchors.leftMargin: Appearance.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: parent.selected ? Theme.text : Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontBody
                        font.weight: parent.selected ? Appearance.weightMedium : Appearance.weightNormal
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.page = modelData.id
                    }
                }
            }
        }

        // --- content ------------------------------------------------------
        Flickable {
            id: scroll

            anchors.left: sidebar.right
            anchors.leftMargin: Appearance.lg
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            contentWidth: width
            contentHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0
            clip: true
            // Kinetic scrolling: this is a convertible and these panels get
            // touched as often as they get scrolled with a wheel.
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 4000

            Loader {
                id: pageLoader

                width: scroll.width
                sourceComponent: {
                    switch (root.page) {
                    case "desktop": return desktopPage;
                    case "audio": return audioPage;
                    case "network": return networkPage;
                    case "shell": return shellPage;
                    case "components": return componentsPage;
                    case "visualizer": return visualizerPage;
                    case "performance": return performancePage;
                    case "system": return systemPage;
                    case "about": return aboutPage;
                    default: return appearancePage;
                    }
                }

                // Fade between pages. No slide: the sidebar already says where
                // you are, and a horizontal slide inside a window that is not
                // moving reads as a glitch.
                onSourceComponentChanged: {
                    if (Appearance.motionless) return;
                    pageLoader.opacity = 0;
                    pageFade.restart();
                    scroll.contentY = 0;
                }

                NumberAnimation {
                    id: pageFade
                    target: pageLoader
                    property: "opacity"
                    to: 1
                    duration: Appearance.durationNormal
                    easing.type: Appearance.easeStandard
                }
            }
        }

        Component { id: appearancePage;  SettingsAppearance {} }
        Component { id: desktopPage;     SettingsDesktop {} }
        Component { id: audioPage;       SettingsAudio {} }
        Component { id: networkPage;     SettingsNetwork {} }
        Component { id: shellPage;       SettingsShell {} }
        Component { id: componentsPage;  SettingsComponents {} }
        Component { id: visualizerPage;  SettingsVisualizer {} }
        Component { id: performancePage; SettingsPerformance {} }
        Component { id: systemPage;      SettingsSystem {} }
        Component { id: aboutPage;       SettingsAbout {} }
    }
}
