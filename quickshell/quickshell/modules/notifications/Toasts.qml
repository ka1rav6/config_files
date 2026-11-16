import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs

// =============================================================================
// Toasts — the notification popups.  Top right, under the bar.
// =============================================================================
// Replaces mako's popups. The content is whatever the sending application
// provided, drawn with this shell's Card, Button and Icon so a notification
// looks like it belongs to the same desktop as everything else -- which is the
// whole reason for taking the daemon over (see services/Notifications.qml).
//
// -----------------------------------------------------------------------------
// WHY EVERY CHILD OF THE COLUMN SETS AN EXPLICIT WIDTH
//
// A wrapped Text only reports the height it actually needs once its width is a
// real number. The first version of this file anchored the text between the
// icon and the close button, which gives a width -- but the Card sized itself
// from the Column's implicitHeight, and a Column cannot report a height for
// children that are positioned by anchors rather than by the Column. Cards came
// out short and the last line of a long body was cut off.
//
// So: nothing in the Column is anchored. Each child sets
// `width: parent.width` (or parent.width minus the close button) and the
// Column's implicitHeight is then the true sum. The close button is the one
// thing anchored, and it deliberately sits OUTSIDE the Column so it cannot
// affect the height at all -- which is also why the Card's height has a
// Math.max floor for it.
// -----------------------------------------------------------------------------
//
// THERE IS NO ICON
//   There was: the app's own icon when it sent one, with a bell glyph as the
//   fallback. It cost ~40px of the width, the fallback fired for most
//   notifications on this machine -- `notify-send -a Foo` carries no icon --
//   and a column of bells is not information. The text gets the space instead.
//
//   An application's own image (album art, a contact photo) goes with it. If
//   that is wanted back, the notification still carries it as `image`; it needs
//   an Image here and the width reducing again.
//
// COLOUR
//   The card is tinted by urgency, so what kind of notification it is reads
//   before the text does:
//     critical  the error accent, plus a matching border. Never times out.
//     normal    a hint of the theme accent.
//     low       untinted.
//
// WHAT TIMES A TOAST OUT
//   Each toast owns its own Timer. That is deliberately not a schedule kept in
//   the service: a timer that lives with the thing it times cannot drift out of
//   step with it, and it disappears when the delegate does.
//
//   Critical notifications never expire on their own, the same convention mako
//   had (its config has a [urgency=critical] block that set timeout=0). Hover
//   pauses the countdown, so reading a long body does not lose it.
//
// FOCUS, AND WHY IT IS NORMALLY REFUSED
//   A notification that steals the keyboard is a notification that eats the
//   next thing you type. This surface therefore asks for NO keyboard focus at
//   all, and only switches to OnDemand while a reply field is actually open --
//   which only happens because the user pressed Reply on a toast. The moment
//   the reply is sent or cancelled it goes back to refusing focus.
//
// COST WHEN IDLE
//   Nothing at all. The window lives in a LazyLoader keyed on there being a
//   popup, so with none on screen there is no surface, no timer and no
//   bindings.
// =============================================================================

Scope {
    id: root

    // Set by a toast while its reply field is open. See the header.
    property bool wantsKeyboard: false

    LazyLoader {
        id: loader

        active: Notifications.popups.length > 0

        PanelWindow {
            id: window

            screen: Hypr.activeScreen
            visible: true
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            // NOT "qs-notifications" -- NotificationCenter is a Panel named
            // "notifications", and Panel builds its namespace as
            // "qs-" + name. Two surfaces under one namespace means the layer
            // rules in ~/.config/hypr/rules.lua cannot tell them apart, and
            // neither can `hyprctl layers` when you are trying to work out
            // which one is on screen.
            WlrLayershell.namespace: "qs-toasts"
            WlrLayershell.keyboardFocus: root.wantsKeyboard
                ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Only the toasts take clicks; the rest of the screen stays
            // click-through to whatever is underneath.
            mask: Region { item: column }

            Column {
                id: column

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Appearance.barClearance
                anchors.rightMargin: Appearance.screenMargin
                spacing: Appearance.xs

                Repeater {
                    model: Notifications.popups

                    Card {
                        id: toast

                        required property var modelData

                        readonly property bool critical:
                            toast.modelData.urgency === NotificationUrgency.Critical
                        readonly property bool low:
                            toast.modelData.urgency === NotificationUrgency.Low

                        // Tighter than Appearance.padding (18 in comfortable
                        // density), which is a panel's margin and far too much
                        // for something this small.
                        readonly property int pad: Appearance.sm + 2

                        // Whether this toast's reply field is showing. Declared
                        // here and used by the Timer below: QML resolves
                        // properties at compile time, not in line order.
                        property bool replyOpen: false

                        width: 300
                        // The Math.max is for the close button, which is
                        // anchored rather than in the Column -- see the header.
                        height: Math.max(stack.implicitHeight,
                                         closeButton.height) + toast.pad * 2
                        elevation: 2

                        // Qt.tint composites the second colour over the first,
                        // so an opaque surface stays opaque and Card's own
                        // groundOpacity still decides the translucency.
                        color: toast.critical
                            ? Qt.tint(Theme.surface, Theme.wash(Theme.error, 0.22))
                            : toast.low
                                ? Theme.surface
                                : Qt.tint(Theme.surface, Theme.wash(Theme.accent, 0.07))

                        borderColor: toast.critical
                            ? Theme.error : Theme.wash(Theme.border, 0.35)

                        // --- entrance ---------------------------------------
                        opacity: 0
                        Component.onCompleted: toast.opacity = 1

                        Behavior on opacity {
                            enabled: !Appearance.motionless
                            NumberAnimation {
                                duration: Appearance.durationNormal
                                easing.type: Appearance.easeEnter
                            }
                        }

                        // --- timeout ----------------------------------------
                        Timer {
                            // A critical notification waits for the user. For
                            // everything else the sender's own timeout wins
                            // when it set one; -1 means "your choice".
                            interval: toast.modelData.expireTimeout > 0
                                ? toast.modelData.expireTimeout : 5000
                            running: !toast.critical && !hover.hovered && !toast.replyOpen
                            onTriggered: Notifications.hidePopup(toast.modelData)
                        }

                        HoverHandler { id: hover }

                        onVisibleChanged: if (!visible) root.wantsKeyboard = false

                        // Outside the Column deliberately: an anchored child
                        // cannot contribute to a Column's implicitHeight, and
                        // this must not pad the card out when the text is one
                        // short line.
                        Button {
                            id: closeButton

                            width: 22
                            height: 22
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 4
                            variant: "ghost"
                            icon: "close"
                            // Dismissing tells the application, which is what
                            // pressing × means. Letting it time out does not.
                            onClicked: Notifications.dismiss(toast.modelData)
                        }

                        Column {
                            id: stack

                            x: toast.pad
                            y: toast.pad
                            width: toast.width - toast.pad * 2
                            spacing: 3

                            // --- title ----------------------------------------
                            // App and summary on ONE line rather than two: the
                            // history panel already reads "appName · summary"
                            // and a separate app-name row was a whole line of
                            // card height for a word.
                            Text {
                                // Clear of the close button, which overlaps this
                                // row.
                                width: parent.width - closeButton.width - 4
                                text: {
                                    const n = toast.modelData;
                                    if (n.appName === "" || n.appName === n.summary)
                                        return n.summary;
                                    return n.appName + "  ·  " + n.summary;
                                }
                                color: toast.critical ? Theme.error : Theme.text
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fontSmall
                                font.weight: Appearance.weightSemi
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            // --- body -----------------------------------------
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: toast.modelData.body
                                color: Theme.muted
                                font.family: Appearance.font
                                font.pixelSize: Appearance.fontCaption
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                // The server advertises body markup, so Pango
                                // markup from the sender is rendered rather than
                                // shown as literal angle brackets.
                                textFormat: Text.StyledText
                                onLinkActivated: (link) => Quickshell.execDetached(["xdg-open", link])
                            }

                            // --- actions ------------------------------------
                            Row {
                                width: parent.width
                                spacing: Appearance.xs
                                visible: toast.modelData.actions.length > 0
                                    || toast.modelData.hasInlineReply

                                Repeater {
                                    model: toast.modelData.actions

                                    Button {
                                        required property var modelData

                                        height: 24
                                        variant: "soft"
                                        text: modelData.text
                                        // Invoking an action is the user acting
                                        // on the notification, so it goes away.
                                        onClicked: {
                                            modelData.invoke();
                                            Notifications.hidePopup(toast.modelData);
                                        }
                                    }
                                }

                                Button {
                                    visible: toast.modelData.hasInlineReply && !toast.replyOpen
                                    height: 24
                                    variant: "soft"
                                    icon: "send"
                                    text: "Reply"
                                    onClicked: {
                                        toast.replyOpen = true;
                                        root.wantsKeyboard = true;
                                        replyField.forceActiveFocus();
                                    }
                                }
                            }

                            // --- inline reply -------------------------------
                            // The reason a KDE Connect SMS can be answered from
                            // here at all; mako cannot draw this.
                            Rectangle {
                                width: parent.width
                                visible: toast.replyOpen
                                height: 28
                                radius: Appearance.radiusInner
                                color: Theme.wash(Theme.text, 0.06)

                                TextInput {
                                    id: replyField

                                    anchors.fill: parent
                                    anchors.leftMargin: Appearance.sm
                                    anchors.rightMargin: Appearance.sm
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.text
                                    font.family: Appearance.font
                                    font.pixelSize: Appearance.fontCaption
                                    selectByMouse: true

                                    Keys.onEscapePressed: {
                                        toast.replyOpen = false;
                                        root.wantsKeyboard = false;
                                    }

                                    onAccepted: {
                                        if (text === "") return;
                                        toast.modelData.sendInlineReply(text);
                                        root.wantsKeyboard = false;
                                        Notifications.hidePopup(toast.modelData);
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Appearance.sm
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: replyField.text === ""
                                    text: toast.modelData.inlineReplyPlaceholder || "Reply…"
                                    color: Theme.muted
                                    font.family: Appearance.font
                                    font.pixelSize: Appearance.fontCaption
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
