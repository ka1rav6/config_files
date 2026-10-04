import QtQuick
import qs

// =============================================================================
// CmdOptions — picking one of several, for a `ui: "select"` command.
// =============================================================================
// Themes, matugen schemes, light/dark, the performance profile. A page rather
// than a popup menu, for the same reason the Control Center pushes a page to
// pick a Wi-Fi network: there are ten themes, each with a description and a
// colour worth seeing, and a dropdown can show neither.
//
// The current choice is marked with a filled accent dot and a tinted row, not
// with a check in a column of empty boxes -- radio buttons at this size are
// four pixels of signal, and the filled row reads from across the panel.
//
// SWATCHES
//   A theme option carries its a1 accent from themes.json (which theme-switch
//   regenerates on every apply), so the list shows what you are about to get.
//   That file is the catalogue's source, so a theme added to theme-switch's
//   THEMES dict appears here, with its colour, with no edit in this module.
//
// APPLYING IS SLOW AND THE PAGE SAYS SO
//   A theme switch rethemes nine applications, reloads waybar, mako, Hyprland
//   and tmux, and takes two to four seconds. The row that is being applied
//   pulses and the page stays open, rather than closing optimistically and
//   leaving the user wondering whether the click landed.
// =============================================================================

Column {
    id: root

    required property var command

    readonly property var options: CommandState.optionsFor(root.command)
    readonly property string current: CommandState.valueFor(root.command)
    readonly property bool busy: CommandState.isBusy(root.command)

    property int selectedIndex: -1

    // Which option was just clicked, so the "applying…" pulse lands on the one
    // the user chose. Read from the command's own service instead and this
    // would only work for themes -- ThemeCatalogue has a `pending`, Matugen
    // and the performance profile do not -- so the page tracks it locally and
    // every selector behaves the same. Cleared when the command stops being
    // busy, below.
    property string pendingId: ""

    onBusyChanged: if (!root.busy) root.pendingId = ""

    signal back()
    signal choose(var command, var option)

    spacing: Appearance.md

    // --- heading --------------------------------------------------------
    Item {
        width: parent.width
        implicitHeight: Math.max(headingText.implicitHeight, Appearance.touchTarget)

        Button {
            id: backButton

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron-left"
            variant: "ghost"
            onClicked: root.back()
        }

        Column {
            id: headingText

            anchors.left: backButton.right
            anchors.leftMargin: Appearance.sm
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.command.name
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontTitle
                font.weight: Appearance.weightSemi
                font.letterSpacing: Appearance.trackingHeading
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.command.desc
                color: Theme.muted
                font.family: Appearance.font
                font.pixelSize: Appearance.fontSmall
                elide: Text.ElideRight
            }
        }
    }

    // --- options --------------------------------------------------------
    Card {
        width: parent.width
        elevation: 0
        implicitHeight: list.implicitHeight + Appearance.md * 2

        Column {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.md
            spacing: 0

            Repeater {
                // Enumerated: the injected `index` is 0 for every delegate --
                // see CommandRegistry.enumerate().
                model: CommandRegistry.enumerate(root.options)

                Item {
                    id: option

                    required property var modelData

                    // The option itself, unwrapped, so everything below reads
                    // the same as it did before the wrapper existed.
                    readonly property var opt: option.modelData.item

                    readonly property bool isCurrent: option.opt.id === root.current
                    readonly property bool isSelected: root.selectedIndex === option.modelData.i
                    // Pulses while this specific option is being applied.
                    readonly property bool applying: root.busy
                        && root.pendingId === option.opt.id

                    width: list.width
                    implicitHeight: Math.max(Appearance.touchTarget + Appearance.xs * 2,
                                             optionText.implicitHeight + Appearance.sm * 2)

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: -Appearance.sm
                        anchors.rightMargin: -Appearance.sm
                        radius: Appearance.radiusInner

                        color: option.isSelected ? Theme.wash(Theme.accent, 0.14)
                             : option.isCurrent ? Theme.wash(Theme.accent, 0.08)
                             : optionMouse.containsMouse ? Theme.hover
                             : "transparent"

                        Behavior on color {
                            enabled: !Appearance.motionless
                            ColorAnimation { duration: Appearance.durationFast }
                        }
                    }

                    // --- the marker ---------------------------------
                    Item {
                        id: marker

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.iconSize
                        height: Appearance.iconSize

                        // A theme's own accent, when there is one, so the list
                        // previews the palette. Otherwise the shell's accent.
                        readonly property color dotColour: {
                            const s = option.opt.swatch;
                            return s !== undefined && s !== "" ? s : Theme.accent;
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: Appearance.iconSize - 4
                            height: width
                            radius: width / 2
                            color: option.isCurrent ? marker.dotColour : "transparent"
                            border.width: option.isCurrent ? 0 : 1
                            border.color: Theme.wash(Theme.border, 0.7)

                            Behavior on color {
                                enabled: !Appearance.motionless
                                ColorAnimation { duration: Appearance.durationNormal }
                            }

                            SequentialAnimation on opacity {
                                running: option.applying && !Appearance.motionless
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    Column {
                        id: optionText

                        anchors.left: marker.right
                        anchors.leftMargin: Appearance.sm
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.sm
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: option.opt.label
                            color: Theme.text
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontBody
                            font.weight: option.isCurrent
                                ? Appearance.weightSemi : Appearance.weightNormal
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: option.applying
                                ? "applying…"
                                : (option.opt.desc !== undefined
                                    ? option.opt.desc : "")
                            color: option.applying ? Theme.accent : Theme.muted
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontSmall
                            elide: Text.ElideRight
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                        }
                    }

                    MouseArea {
                        id: optionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.pendingId = option.opt.id;
                            root.choose(root.command, option.opt);
                        }
                    }
                }
            }
        }
    }

    // The command this page is a front-end for, so the terminal equivalent is
    // learnable from here too.
    Text {
        width: parent.width
        visible: Settings.commands.showCli && (root.command.cli || "") !== ""
        text: root.command.cli
        color: Theme.muted
        opacity: 0.55
        font.family: Appearance.fontMono
        font.pixelSize: Appearance.fontCaption
        elide: Text.ElideRight
    }

    Item {
        width: parent.width
        height: Appearance.md
    }
}
