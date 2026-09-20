import QtQuick
import qs

// Settings — Performance. The profile, what each one actually does, and the
// automatic behaviours. Written so the trade-offs are visible rather than
// hidden behind three words.
Column {
    id: root

    spacing: Appearance.lg
    bottomPadding: Appearance.xl

    SettingsGroup {
        width: parent.width
        title: "PROFILE"
        subtitle: Performance.downshifted
            ? "Running in " + Performance.profile + " — automatically lowered on battery"
            : "Currently running in " + Performance.profile

        Repeater {
            model: [
                { id: "saver", label: "Battery Saver", icon: "saver",
                  desc: "No visualizer, no blur, shorter animations, widgets update every 10s." },
                { id: "balanced", label: "Balanced", icon: "balanced",
                  desc: "The designed experience. Visualizer runs while audio plays, blur on, full-speed animations." },
                { id: "visual", label: "Visual", icon: "performance",
                  desc: "More visualizer bands, faster widget updates. Intended for AC power." }
            ]

            Rectangle {
                required property var modelData

                width: parent.width
                height: profileRow.implicitHeight + Appearance.md * 2
                radius: Appearance.radiusInner

                readonly property bool selected: Settings.performance.profile === modelData.id

                color: selected ? Theme.wash(Theme.accent, 0.16)
                     : profileMouse.containsMouse ? Theme.hover : "transparent"

                Behavior on color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationFast }
                }

                Row {
                    id: profileRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Appearance.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.md

                    Icon {
                        name: modelData.icon
                        size: Appearance.iconSizeLarge
                        color: parent.parent.selected ? Theme.accent : Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Appearance.iconSizeLarge * 1.25 - Appearance.md * 2 - 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: modelData.label
                            color: Theme.text
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontBody
                            font.weight: Appearance.weightMedium
                        }

                        Text {
                            width: parent.width
                            text: modelData.desc
                            color: Theme.muted
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontSmall
                            wrapMode: Text.WordWrap
                        }
                    }

                    Icon {
                        name: "check"
                        size: Appearance.iconSize
                        color: Theme.accent
                        opacity: parent.parent.selected ? 1 : 0
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on opacity {
                            enabled: !Appearance.motionless
                            NumberAnimation { duration: Appearance.durationNormal }
                        }
                    }
                }

                MouseArea {
                    id: profileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.performance.profile = modelData.id
                }
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "AUTOMATIC"

        SettingRow {
            width: parent.width
            label: "Drop to Battery Saver on battery"
            description: "Lowers the effective profile without changing the one you picked, so plugging back in restores it."
            Toggle {
                checked: Settings.performance.autoSaverOnBattery
                onToggled: (v) => Settings.performance.autoSaverOnBattery = v
            }
        }

        SettingRow {
            width: parent.width
            label: "Game mode"
            description: "Suspends the visualizer, blur and widget updates while a window is fullscreen. Stops shell work rather than merely hiding pixels."
            Toggle {
                checked: Settings.performance.gameMode
                onToggled: (v) => Settings.performance.gameMode = v
            }
        }
    }

    SettingsGroup {
        width: parent.width
        title: "RIGHT NOW"

        SettingRow {
            width: parent.width
            label: "Effective settings"
            description: "Visualizer " + (Performance.allowVisualizer ? "allowed" : "suppressed")
                + " · blur " + (Performance.allowBlur ? "on" : "off")
                + " · motion " + Performance.motionScale.toFixed(1) + "x"
                + " · widget refresh " + (Performance.pollInterval / 1000) + "s"
                + (Performance.gameMode ? " · fullscreen detected" : "")
        }

        SettingRow {
            width: parent.width
            visible: Performance.hasBattery
            label: "Battery"
            description: Math.round(Performance.batteryPercent * 100) + "%"
                + (Performance.batteryCharging ? ", charging" : ", discharging")
                + (Performance.batteryHealth > 0
                    ? " · health " + Math.round(Performance.batteryHealth) + "%"
                    : " · health not reported by this battery")
        }
    }
}
