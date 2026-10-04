import QtQuick
import qs

// =============================================================================
// CmdPrompt — the sheet for a command that needs something typed.
// =============================================================================
// Three commands take a value only a person can supply, and all three are KDE
// Connect:
//
//   just phone-open <url>    open a link on the phone
//   just phone-type <text>   type text into whatever has focus on the phone
//   just phone-ping <msg>    send a notification with a message
//
// (just phone-send takes FILES, which is a picker rather than a field -- see
// CommandRunner.pickFiles.)
//
// -----------------------------------------------------------------------------
// THIS IS NOT A SHELL PROMPT, AND THE DIFFERENCE IS STRUCTURAL
//
// The registry's header argues that a text field in a launcher is a shell with
// extra steps, and that remains true of a field that builds a command line.
// This is not one:
//
//   * the command is FIXED by the registry. What is typed here becomes exactly
//     one argv element, appended by CommandRunner to a command it already
//     holds. There is no interpolation into a string and no shell between the
//     field and the process -- `; rm -rf ~` typed here is sent to the phone as
//     the literal text `; rm -rf ~`, because it is argv[n] and nothing parses
//     it.
//   * only a command whose registry entry declares `input` can open this at
//     all, so the field cannot be pointed at a different command.
//   * what will be sent is shown back verbatim before you send it.
//
// So it is a parameter for one specific, curated operation -- the same thing a
// Wi-Fi passphrase field in the Control Center is -- rather than a way to run
// arbitrary things.
// -----------------------------------------------------------------------------
//
// PASTE IS A FIRST-CLASS BUTTON
//   The overwhelmingly common case for "open a link on my phone" is a URL
//   already on the clipboard, and retyping one by hand is miserable. The paste
//   button reads the Wayland clipboard through wl-paste, which is the same
//   tool SUPER+V's cliphist pipeline already uses.
// =============================================================================

Item {
    id: root

    // The registry entry awaiting input, or null.
    property var command: null

    readonly property bool active: root.command !== null
    readonly property var spec: root.active && root.command.input
        ? root.command.input : null

    readonly property bool multiline: !!(root.spec && root.spec.multiline)

    signal submitted(var command, string value)
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

    function submit() {
        if (!root.active) return;
        const value = field.text;
        // An empty value is never what was meant, and several of these
        // commands misbehave on one: `kdeconnect-cli --ping-msg` with no value
        // consumes the next flag as its argument.
        if (value.trim() === "") return;
        root.submitted(root.command, value);
    }

    // Reset between uses, so yesterday's URL is not sitting in the field.
    onActiveChanged: {
        if (root.active) {
            field.text = "";
            field.forceActiveFocus();
        }
    }

    // --- scrim ----------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)

        MouseArea {
            anchors.fill: parent
            enabled: root.active
            onClicked: root.cancel()
        }
    }

    // --- sheet ----------------------------------------------------------
    Card {
        id: sheet

        elevation: 2
        anchors.centerIn: parent
        width: Math.min(parent.width - Appearance.xl * 2, 520)
        height: body.implicitHeight + Appearance.padding * 2

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
                    color: Theme.accent
                }

                Column {
                    width: parent.width - Appearance.iconSizeLarge * 1.25 - Appearance.sm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: root.active ? root.command.name : ""
                        color: Theme.text
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontTitle
                        font.weight: Appearance.weightSemi
                        font.letterSpacing: Appearance.trackingHeading
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.spec && root.spec.label ? root.spec.label
                            : (root.active ? root.command.desc : "")
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSmall
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // --- the field --------------------------------------------
            Rectangle {
                width: parent.width
                height: root.multiline
                    ? Math.max(Appearance.controlHeight * 2, field.implicitHeight + Appearance.md * 2)
                    : Appearance.controlHeight + 8
                radius: Appearance.radiusInner
                color: Theme.wash(Theme.bg, 0.5)
                border.width: 1
                border.color: Theme.wash(Theme.accent, field.activeFocus ? 0.5 : 0.15)

                Behavior on border.color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationFast }
                }

                TextEdit {
                    id: field

                    anchors.fill: parent
                    anchors.margins: Appearance.md
                    anchors.rightMargin: pasteButton.width + Appearance.sm

                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontLabel
                    selectByMouse: true
                    selectionColor: Theme.wash(Theme.accent, 0.35)
                    selectedTextColor: Theme.text
                    wrapMode: root.multiline ? TextEdit.Wrap : TextEdit.NoWrap
                    verticalAlignment: root.multiline ? TextEdit.AlignTop
                                                      : TextEdit.AlignVCenter
                    clip: true
                    focus: true

                    // Return sends on a single-line field; on a multi-line one
                    // it has to insert a newline, so Ctrl+Return sends there.
                    Keys.onReturnPressed: (event) => {
                        if (!root.multiline || (event.modifiers & Qt.ControlModifier)) {
                            root.submit();
                            event.accepted = true;
                        } else {
                            event.accepted = false;
                        }
                    }

                    Keys.onEscapePressed: (event) => {
                        root.cancel();
                        event.accepted = true;
                    }

                    Text {
                        anchors.fill: parent
                        visible: field.text === ""
                        text: root.spec && root.spec.placeholder ? root.spec.placeholder : ""
                        color: Theme.muted
                        opacity: 0.55
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontLabel
                        verticalAlignment: root.multiline ? Text.AlignTop : Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                Button {
                    id: pasteButton

                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.xs
                    anchors.top: parent.top
                    anchors.topMargin: root.multiline ? Appearance.xs : 0
                    anchors.verticalCenter: root.multiline ? undefined : parent.verticalCenter

                    // Paste, not download -- the arrow read as "fetch a
                    // file", which is the one thing this button does not do.
                    icon: "paste"
                    variant: "ghost"
                    onClicked: CommandRunner.readClipboard()
                }
            }

            // Fills the field from the Wayland clipboard. Routed through the
            // runner because it is a subprocess (wl-paste) and nothing in the
            // UI spawns its own.
            Connections {
                target: CommandRunner

                function onClipboardRead(text) {
                    if (!root.active) return;
                    field.text = text;
                    field.cursorPosition = field.text.length;
                    field.forceActiveFocus();
                }
            }

            // --- what will actually be sent ---------------------------
            // The exact argv, so there is never a question of what the phone
            // is about to receive -- and so it is visible that the text is one
            // argument rather than something being pasted into a shell line.
            Rectangle {
                width: parent.width
                visible: field.text !== ""
                height: preview.implicitHeight + Appearance.sm * 2
                radius: Appearance.radiusSmall
                color: Theme.wash(Theme.bg, 0.6)
                border.width: 1
                border.color: Theme.wash(Theme.border, 0.35)

                Text {
                    id: preview

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Appearance.sm
                    text: root.active
                        ? root.command.cli.replace(/<[^>]*>/, JSON.stringify(field.text))
                        : ""
                    color: Theme.muted
                    font.family: Appearance.fontMono
                    font.pixelSize: Appearance.fontCaption
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }

            // --- actions ----------------------------------------------
            Row {
                anchors.right: parent.right
                spacing: Appearance.sm

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.multiline ? "Ctrl+Enter to send" : "Enter to send"
                    color: Theme.muted
                    opacity: 0.6
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    rightPadding: Appearance.sm
                }

                Button {
                    text: "Cancel"
                    variant: "soft"
                    onClicked: root.cancel()
                }

                Button {
                    text: root.spec && root.spec.action ? root.spec.action : "Send"
                    variant: "accent"
                    enabled: field.text.trim() !== ""
                    onClicked: root.submit()
                }
            }
        }
    }

    focus: root.active
}
