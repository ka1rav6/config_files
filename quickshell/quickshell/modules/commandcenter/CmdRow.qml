import QtQuick
import qs

// =============================================================================
// CmdRow — one command, drawn as whatever it actually is.
// =============================================================================
// The registry says `ui: "toggle"` and this draws a Toggle; `ui: "select"` and
// this draws a value with a chevron; `ui: "action"` and this draws a button.
// One component for all of them, so a theme selector and a cache wipe sit on
// the same rhythm and the panel reads as a list rather than as a collage.
//
// -----------------------------------------------------------------------------
// DENSITY: TWO LINES, SOMETIMES THREE. NEVER FOUR.
//
// The first version of this row stacked name, status, description AND the
// equivalent terminal command, four lines at 2 px leading, with zero spacing
// between rows and no rule between them. Every line was individually correct
// and the list was a wall of text -- adjacent rows were no further apart than
// the lines within one row, so they read as one paragraph rather than as a
// list. That is the whole reason it looked wrong.
//
// So:
//   * the CLI line is OFF by default (Settings.commands.showCli) and lives in
//     the confirmation sheet and the output view, where it is actually needed.
//     The eye button in the panel header turns it back on.
//   * line leading went 2 -> 3, and the vertical padding of a row went from
//     Appearance.sm to Appearance.md -- so the gap BETWEEN rows is now four
//     times the gap between lines within one, which is what makes a stack of
//     rows parse as separate things.
//   * a hairline Theme.separator sits between rows. One line of 1 px does more
//     for scannability here than any amount of spacing, and it is the same
//     device the Control Center's device lists use.
//
// The result is the same two-line shape as modules/settings/SettingRow.qml --
// label, description, control on the right -- which is what makes this panel
// and the Settings window read as one product.
// -----------------------------------------------------------------------------
//
// SAFETY IS VISIBLE BEFORE IT IS ENFORCED
//   A `danger` command gets an error-coloured action and a "destructive" chip;
//   a `confirm` command gets a warning-coloured one. The confirmation sheet is
//   the enforcement, but a row that looks dangerous before you reach for it is
//   what stops you reaching for it. See CmdConfirm.qml.
//
// The pin is on hover (and always, once set) rather than permanently drawn on
// every row: forty pins down a list is noise, and the control is still
// reachable from the keyboard with Ctrl+D.
// =============================================================================

Item {
    id: root

    required property var command

    // Drawn with a tinted ground and an accent rail when the keyboard cursor
    // is on it. Set by the list, not by hover -- hover is a separate, lighter
    // state, so moving the mouse across the panel does not move the thing that
    // Return would act on.
    property bool selected: false

    // Search results show which category a command came from; a category page
    // does not, because every row on it has the same answer.
    property bool showCategory: false

    // The list suppresses this on its last row.
    property bool showSeparator: true

    signal activated()
    signal expand()

    readonly property var state: CommandState.statusFor(root.command)
    readonly property bool busy: CommandState.isBusy(root.command)
    readonly property bool favourite: CommandRunner.isFavourite(root.command.id)
    readonly property bool showCli: Settings.commands.showCli
        && (root.command.cli || "") !== ""

    readonly property bool toggleEnabled: {
        if (root.command.ui !== "toggle") return true;
        const e = CommandState.enabled[root.command.state];
        return e !== false;
    }

    readonly property color accentFor: {
        switch (root.command.safety) {
        case "danger": return Theme.error;
        case "confirm": return Theme.warning;
        default: return Theme.accent;
        }
    }

    implicitHeight: Math.max(Appearance.touchTarget, textColumn.implicitHeight)
        + Appearance.md * 2

    // --- ground ---------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Appearance.sm
        anchors.rightMargin: -Appearance.sm
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: Appearance.radiusInner

        color: root.selected ? Theme.wash(root.accentFor, 0.20)
             : hover.containsMouse ? Theme.hover
             : "transparent"

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation { duration: Appearance.durationFast }
        }

        // The keyboard cursor's rail. Same device as the Settings sidebar's
        // selected item, so "where am I" reads identically in both.
        Rectangle {
            width: 3
            height: parent.height * 0.62
            radius: 2
            color: root.accentFor
            opacity: root.selected ? 1 : 0
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Behavior on opacity {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationNormal }
            }
        }
    }

    // --- separator ------------------------------------------------------
    // Below the row, inset to the text column so it reads as dividing the
    // content rather than boxing it. Hidden under the selection fill, which
    // would otherwise be cut in half by a line through it.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.separator
        visible: root.showSeparator && !root.selected && !hover.containsMouse
    }

    // --- icon -----------------------------------------------------------
    Icon {
        id: rowIcon

        name: root.command.icon
        size: Appearance.iconSize
        color: root.selected ? root.accentFor : Theme.muted
        anchors.left: parent.left
        anchors.leftMargin: Appearance.xs
        // Pinned to the first line rather than centred: on a three-line row a
        // centred icon drifts down beside the description and stops reading as
        // belonging to the name.
        anchors.top: textColumn.top
        anchors.topMargin: -2

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation { duration: Appearance.durationFast }
        }

        // A slow pulse while the command is in flight. Calmer than a spinner
        // and it costs one opacity animation, which is free on the GPU.
        SequentialAnimation on opacity {
            running: root.busy && !Appearance.motionless
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.3; duration: 620; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
        }
    }

    // --- text -----------------------------------------------------------
    Column {
        id: textColumn

        anchors.left: rowIcon.right
        anchors.leftMargin: Appearance.sm
        anchors.right: controlSlot.left
        anchors.rightMargin: Appearance.md
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        // --- name line, with its chips pinned right -------------------
        // An Item rather than a Row, so the name can be elided against
        // whatever the chips leave. The earlier Row computed the name's width
        // from its own implicitWidth and its siblings' -- which works until a
        // chip appears, and reads as the name running into the chip when it
        // does.
        Item {
            width: parent.width
            height: nameText.implicitHeight

            Row {
                id: chips

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.xs

                // Where this came from, in search results only.
                Rectangle {
                    visible: root.showCategory
                    anchors.verticalCenter: parent.verticalCenter
                    width: categoryLabel.implicitWidth + Appearance.sm * 2
                    height: categoryLabel.implicitHeight + 4
                    radius: Appearance.radiusFull
                    color: Theme.wash(Theme.border, 0.35)

                    Text {
                        id: categoryLabel

                        anchors.centerIn: parent
                        text: {
                            const c = CommandRegistry.category(root.command.category);
                            return c ? c.label : root.command.category;
                        }
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                    }
                }

                // Visible before the confirmation sheet is, which is the point.
                Rectangle {
                    visible: root.command.safety === "danger"
                    anchors.verticalCenter: parent.verticalCenter
                    width: dangerLabel.implicitWidth + Appearance.sm * 2
                    height: dangerLabel.implicitHeight + 4
                    radius: Appearance.radiusFull
                    color: Theme.wash(Theme.error, 0.2)

                    Text {
                        id: dangerLabel

                        anchors.centerIn: parent
                        text: "destructive"
                        color: Theme.error
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontCaption
                        font.weight: Appearance.weightMedium
                    }
                }
            }

            Text {
                id: nameText

                anchors.left: parent.left
                anchors.right: chips.children.length > 0 ? chips.left : parent.right
                anchors.rightMargin: Appearance.sm
                anchors.verticalCenter: parent.verticalCenter

                text: root.command.name
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
                font.weight: Appearance.weightMedium
                elide: Text.ElideRight
            }
        }

        // --- description ----------------------------------------------
        // One line, always. It is a reminder of what the command does, not
        // documentation -- the full text is in the confirmation sheet, which
        // is where it matters, and it is searched in full either way.
        Text {
            width: parent.width
            visible: root.command.desc !== ""
            text: root.command.desc
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // --- live state -----------------------------------------------
        // A dot plus a line, so the tone is readable down the panel without
        // reading any of the words.
        Item {
            width: parent.width
            visible: root.state !== null
            height: visible ? stateText.implicitHeight : 0

            Rectangle {
                id: stateDot

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: root.state ? CommandState.toneColour(root.state.tone) : Theme.muted

                Behavior on color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationNormal }
                }
            }

            Text {
                id: stateText

                anchors.left: stateDot.right
                anchors.leftMargin: Appearance.xs + 2
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                text: root.state ? root.state.text : ""
                color: root.state && root.state.tone !== "idle"
                    ? CommandState.toneColour(root.state.tone) : Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // --- the terminal equivalent ----------------------------------
        // Off by default. See the density note in the header: this is the line
        // that turned the list into a paragraph. It earns its place while you
        // are still learning which command a row fronts, and the eye button in
        // the header is how you turn it off again once you have.
        Text {
            width: parent.width
            visible: root.showCli
            text: root.command.cli
            color: Theme.muted
            opacity: 0.55
            font.family: Appearance.fontMono
            font.pixelSize: Appearance.fontCaption
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    // --- the control ----------------------------------------------------
    Item {
        id: controlSlot

        anchors.right: star.left
        anchors.rightMargin: Appearance.xs
        anchors.verticalCenter: parent.verticalCenter
        width: slot.implicitWidth
        height: slot.implicitHeight

        Loader {
            id: slot

            anchors.centerIn: parent

            sourceComponent: {
                switch (root.command.ui) {
                case "toggle": return toggleControl;
                case "select": return selectControl;
                case "link": return linkControl;
                default: return actionControl;
                }
            }
        }
    }

    Component {
        id: toggleControl

        Toggle {
            // Bound to the service, never to its own history. If wlsunset is
            // killed from a terminal, or makoctl is used directly, this
            // follows -- see the note in CommandState.qml.
            checked: CommandState.states[root.command.state] === true
            enabled: root.toggleEnabled
            onToggled: root.activated()
        }
    }

    Component {
        id: selectControl

        Row {
            spacing: Appearance.xs

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: CommandState.labelForValue(root.command)
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
                font.weight: Appearance.weightMedium
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron-right"
                size: Appearance.iconSize
                color: Theme.muted
            }
        }
    }

    Component {
        id: linkControl

        Icon {
            name: "chevron-right"
            size: Appearance.iconSize
            color: Theme.muted
        }
    }

    Component {
        id: actionControl

        Button {
            // The ellipsis is the convention for "this will ask first", so it
            // belongs on anything that opens a sheet before acting: a confirm
            // or danger command, and equally one that needs a value typed or a
            // file picked.
            text: root.command.safety === "safe" && root.command.input === undefined
                ? "Run" : "Run…"
            variant: root.command.safety === "danger" ? "danger" : "soft"
            busy: root.busy
            onClicked: root.activated()
        }
    }

    // --- favourite ------------------------------------------------------
    // Hidden until hovered, selected, or already pinned. A pin on every row is
    // forty pins of noise; a pin on no row is a feature nobody finds.
    Item {
        id: star

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Appearance.touchTarget
        height: Appearance.touchTarget

        opacity: root.favourite || root.selected || hover.containsMouse
            || starMouse.containsMouse ? 1 : 0

        Behavior on opacity {
            enabled: !Appearance.motionless
            NumberAnimation { duration: Appearance.durationFast }
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 8
            height: parent.height - 8
            radius: Appearance.radiusSmall
            color: Theme.text
            opacity: starMouse.containsMouse ? 0.1 : 0

            Behavior on opacity {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationFast }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: "pin"
            size: Appearance.iconSize
            color: root.favourite ? Theme.accent : Theme.muted
            opacity: root.favourite ? 1 : 0.6

            Behavior on color {
                enabled: !Appearance.motionless
                ColorAnimation { duration: Appearance.durationNormal }
            }

            scale: starMouse.pressed ? 0.85 : 1
            Behavior on scale {
                enabled: !Appearance.motionless
                NumberAnimation { duration: Appearance.durationFast }
            }
        }

        MouseArea {
            id: starMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: CommandRunner.toggleFavourite(root.command.id)
        }
    }

    // --- the row itself -------------------------------------------------
    // Stops short of the control and the pin, so those take their own clicks.
    MouseArea {
        id: hover

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: controlSlot.left
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (root.command.ui === "select") root.expand();
            else root.activated();
        }
    }
}
