import QtQuick
import qs

// =============================================================================
// CmdConfirm — the sheet that stands between a click and a consequence.
// =============================================================================
// Shown for every `confirm` and `danger` command. Three things make it a
// confirmation rather than a speed bump:
//
//   1. IT SAYS WHAT WILL HAPPEN, not "are you sure". The registry's `warn`
//      field is a sentence about consequences -- which windows close, what is
//      deleted, what cannot be undone. "Are you sure?" is a dialog that
//      teaches you to click Yes without reading; "Kills Chrome immediately --
//      any unsaved form goes with it" is one you actually stop at.
//   2. IT SHOWS THE COMMAND. The exact argv is printed, so there is never a
//      question of what is about to run.
//   3. THE DEFAULT IS CANCEL. Escape and Return-without-moving both cancel,
//      and the destructive button is not focused. For a `danger` command the
//      confirm button is also the only error-coloured thing on screen, so the
//      one place the eye lands is the one place with a consequence.
//
// WHY A SHEET OVER THE PANEL AND NOT A SECOND WINDOW
//   A second layer-shell surface would need its own focus grab, and two grabs
//   fight: dismissing the dialog would close the panel underneath it. This is
//   an overlay inside the panel's own window, so the panel keeps the grab and
//   the sheet simply takes its keys.
// =============================================================================

Item {
    id: root

    // The registry entry awaiting confirmation, or null. Assigning one shows
    // the sheet; the panel clears it on either outcome.
    property var command: null
    property string optionArg: ""
    // Human label for the option, when confirming a selector choice.
    property string optionLabel: ""

    readonly property bool active: root.command !== null
    readonly property bool destructive: root.active && root.command.safety === "danger"

    signal confirmed(var command, string arg)
    signal cancelled()

    visible: opacity > 0
    opacity: root.active ? 1 : 0

    Behavior on opacity {
        enabled: !Appearance.motionless
        NumberAnimation {
            duration: Appearance.durationNormal
            easing.type: Appearance.easeStandard
        }
    }

    function cancel() {
        root.cancelled();
    }

    function accept() {
        if (!root.active) return;
        root.confirmed(root.command, root.optionArg);
    }

    // --- scrim ----------------------------------------------------------
    // Dims the panel behind, and absorbs every click that is not on the sheet
    // so nothing underneath can be operated while a confirmation is open.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)

        MouseArea {
            anchors.fill: parent
            enabled: root.active
            // Clicking away cancels. Safe by construction: the only outcome
            // reachable by accident is the one that does nothing.
            onClicked: root.cancel()
        }
    }

    // --- sheet ----------------------------------------------------------
    Card {
        id: sheet

        elevation: 2
        anchors.centerIn: parent
        width: Math.min(parent.width - Appearance.xl * 2, 480)
        height: body.implicitHeight + Appearance.padding * 2

        // A short rise, so it reads as arriving over the panel rather than
        // having always been there.
        transform: Translate {
            y: root.active ? 0 : 12

            Behavior on y {
                enabled: !Appearance.motionless
                NumberAnimation {
                    duration: Appearance.durationNormal
                    easing.type: Appearance.easeEnter
                }
            }
        }

        // Swallow clicks that land on the sheet, so they do not reach the
        // cancelling scrim behind it.
        MouseArea { anchors.fill: parent }

        Column {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding
            spacing: Appearance.md

            // --- heading ---------------------------------------------
            Row {
                width: parent.width
                spacing: Appearance.sm

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.active ? root.command.icon : "info"
                    size: Appearance.iconSizeLarge
                    color: root.destructive ? Theme.error : Theme.warning
                }

                Column {
                    width: parent.width - Appearance.iconSizeLarge * 1.25 - Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: root.active
                            ? (root.optionLabel !== ""
                                ? root.command.name + ": " + root.optionLabel
                                : root.command.name)
                            : ""
                        color: Theme.text
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontTitle
                        font.weight: Appearance.weightSemi
                        font.letterSpacing: Appearance.trackingHeading
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.destructive
                            ? "This makes a change that cannot be undone"
                            : "This changes system state"
                        color: root.destructive ? Theme.error : Theme.warning
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSmall
                        font.weight: Appearance.weightMedium
                    }
                }
            }

            // --- what will happen -------------------------------------
            Text {
                width: parent.width
                text: root.active
                    ? (root.command.warn !== undefined && root.command.warn !== ""
                        ? root.command.warn
                        : root.command.desc)
                    : ""
                color: Theme.text
                opacity: 0.85
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
                wrapMode: Text.WordWrap
                lineHeight: 1.25
            }

            // --- the exact command ------------------------------------
            Rectangle {
                width: parent.width
                height: commandText.implicitHeight + Appearance.sm * 2
                radius: Appearance.radiusSmall
                color: Theme.wash(Theme.bg, 0.6)
                border.width: 1
                border.color: Theme.wash(Theme.border, 0.35)

                Text {
                    id: commandText

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Appearance.sm
                    text: {
                        if (!root.active) return "";
                        if (root.command.exec)
                            return root.command.exec.join(" ");
                        return root.command.cli || "(handled inside the shell)";
                    }
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontCaption
                    wrapMode: Text.WrapAnywhere
                }
            }

            // --- actions ----------------------------------------------
            Row {
                anchors.right: parent.right
                spacing: Appearance.sm

                Button {
                    // Focused by default, so Return cancels. The destructive
                    // action always costs a deliberate Tab or a click.
                    id: cancelButton

                    text: "Cancel"
                    variant: "soft"
                    focus: true
                    onClicked: root.cancel()
                }

                Button {
                    text: root.destructive ? "Yes, do it" : "Continue"
                    variant: root.destructive ? "danger" : "accent"
                    onClicked: root.accept()
                }
            }
        }
    }

    // Keys are handled here rather than on the sheet so they work however the
    // sheet was summoned -- from a row, from a chip, or from the keyboard.
    Keys.onEscapePressed: (event) => { root.cancel(); event.accepted = true; }

    focus: root.active
    onActiveChanged: if (root.active) cancelButton.forceActiveFocus()
}
