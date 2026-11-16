import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

// =============================================================================
// Notification centre — the history.  SUPER + N
// =============================================================================
// Replaces ~/.local/bin/mako-fzf-history, which SUPER + N used to open by
// launching a Ghostty window to run fzf in. That worked, and it looked like
// exactly what it was: a terminal pretending to be part of the desktop.
//
// It shows what services/Notifications.qml is holding -- the same objects the
// toasts were drawn from, newest first. Clicking a row invokes the
// notification's default action if it has one, which is what makes a missed
// "Build finished" or an SMS still useful ten minutes later.
//
// Opening it clears whatever toasts are on screen: they are the same
// notifications, and leaving them stacked over a panel that lists them is
// saying the same thing twice.
// =============================================================================

Panel {
    id: root

    name: "notifications"
    placement: "top-right"
    panelWidth: 420

    onOpened: Notifications.clearPopups()

    content: Column {
        spacing: Appearance.gap

        // --- header ---------------------------------------------------------
        Item {
            width: parent.width
            implicitHeight: Appearance.controlHeight

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Notifications.count === 0
                    ? "Notifications"
                    : "Notifications  ·  " + Notifications.count
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontHeading
                font.weight: Appearance.weightSemi
                font.letterSpacing: Appearance.trackingHeading
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.sm

                Icon {
                    name: Notifications.dnd ? "bell-off" : "bell"
                    size: Appearance.iconSize
                    color: Notifications.dnd ? Theme.warning : Theme.muted
                    anchors.verticalCenter: parent.verticalCenter
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Notifications.dnd
                    onToggled: (value) => Notifications.setDnd(value)
                }
            }
        }

        Text {
            width: parent.width
            visible: Notifications.dnd
            text: "Do not disturb — notifications are being kept, not shown"
            color: Theme.warning
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
            wrapMode: Text.WordWrap
        }

        // --- the list -------------------------------------------------------
        // Capped and scrolled rather than growing the panel to the height of
        // the history: fifty notifications is taller than the screen.
        Flickable {
            width: parent.width
            visible: Notifications.count > 0
            implicitHeight: Math.min(list.implicitHeight, 460)
            contentHeight: list.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: list

                width: parent.width
                spacing: Appearance.xs

                Repeater {
                    model: Notifications.history

                    Rectangle {
                        id: row

                        required property var modelData

                        width: parent.width
                        implicitHeight: rowBody.implicitHeight + Appearance.sm * 2
                        height: implicitHeight
                        radius: Appearance.radiusInner
                        color: mouse.containsMouse ? Theme.hover : Theme.wash(Theme.text, 0.04)

                        Behavior on color {
                            enabled: !Appearance.motionless
                            ColorAnimation { duration: Appearance.durationFast }
                        }

                        Column {
                            id: rowBody

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Appearance.sm
                            anchors.rightMargin: drop.width + Appearance.sm
                            spacing: 1

                            Text {
                                width: parent.width
                                text: row.modelData.appName === ""
                                    ? row.modelData.summary
                                    : row.modelData.appName + "  ·  " + row.modelData.summary
                                color: row.modelData.urgency === NotificationUrgency.Critical
                                    ? Theme.error : Theme.text
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fontSmall
                                font.weight: Appearance.weightMedium
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: row.modelData.body
                                color: Theme.muted
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fontCaption
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                // Markup is advertised by the server, so it is
                                // rendered here too -- otherwise the history
                                // shows angle brackets the popup did not.
                                textFormat: Text.StyledText
                            }
                        }

                        Button {
                            id: drop

                            width: Appearance.controlHeightSmall
                            height: Appearance.controlHeightSmall
                            anchors.right: parent.right
                            anchors.rightMargin: Appearance.xs
                            anchors.top: parent.top
                            anchors.topMargin: Appearance.xs
                            variant: "ghost"
                            icon: "close"
                            // Forget this one. Untracked rather than dismissed:
                            // clearing a row hours later is bookkeeping here,
                            // not a message to the application.
                            onClicked: row.modelData.tracked = false
                        }

                        MouseArea {
                            id: mouse

                            anchors.fill: parent
                            anchors.rightMargin: drop.width
                            hoverEnabled: true
                            // Only a pointer where there is something to click.
                            cursorShape: row.modelData.actions.length > 0
                                ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onClicked: {
                                const actions = row.modelData.actions;
                                if (actions.length === 0) return;
                                // The spec's convention: an action identified
                                // "default" is what activating the notification
                                // body means. Fall back to the first one.
                                let chosen = actions[0];
                                for (const a of actions) {
                                    if (a.identifier === "default") chosen = a;
                                }
                                chosen.invoke();
                                root.hide();
                            }
                        }
                    }
                }
            }
        }

        // --- empty state ------------------------------------------------------
        Item {
            width: parent.width
            implicitHeight: 96
            visible: Notifications.count === 0

            Column {
                anchors.centerIn: parent
                spacing: Appearance.xs

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "bell"
                    size: 24
                    color: Theme.wash(Theme.text, 0.22)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing to catch up on"
                    color: Theme.wash(Theme.text, 0.35)
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                }
            }
        }

        Button {
            width: parent.width
            visible: Notifications.count > 0
            variant: "ghost"
            icon: "trash"
            text: "Clear all"
            onClicked: Notifications.clear()
        }
    }
}
