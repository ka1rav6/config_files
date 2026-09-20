import QtQuick
import QtQuick.Controls
import qs

// The inside of the emoji picker: search, recents/favourites, grid, category
// strip. Split out of EmojiPicker.qml purely so that file stays about data and
// this one about layout.
Item {
    id: body

    required property var picker

    implicitHeight: 460

    // --- search ------------------------------------------------------------
    Rectangle {
        id: searchBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Appearance.controlHeight
        radius: height / 2
        color: Theme.wash(Theme.text, field.activeFocus ? 0.12 : 0.07)
        border.width: 1
        border.color: field.activeFocus ? Theme.wash(Theme.accent, 0.55)
                                        : Theme.wash(Theme.border, 0.30)

        Behavior on color {
            enabled: !Appearance.motionless
            ColorAnimation { duration: Appearance.durationFast }
        }

        Icon {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: Appearance.md
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 15
            color: Theme.muted
        }

        TextInput {
            id: field

            anchors.left: searchIcon.right
            anchors.leftMargin: Appearance.sm
            anchors.right: parent.right
            anchors.rightMargin: Appearance.md
            anchors.verticalCenter: parent.verticalCenter

            color: Theme.text
            font.family: Appearance.font
            font.pixelSize: Appearance.fontBody
            focus: true
            clip: true
            selectByMouse: true

            onTextChanged: body.picker.query = text

            // Enter takes the first result, which is what makes this usable
            // without ever touching the mouse.
            onAccepted: {
                const first = body.picker.results[0];
                if (first) body.picker.pick(first.c);
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    // Escape clears a search before it closes the picker, so a
                    // mistyped query is one key to undo rather than a reopen.
                    if (field.text !== "") {
                        field.text = "";
                        event.accepted = true;
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                text: "Search emoji"
                color: Theme.wash(Theme.text, 0.35)
                font.family: Appearance.font
                font.pixelSize: Appearance.fontBody
                visible: field.text.length === 0
            }

            Component.onCompleted: field.forceActiveFocus()
        }
    }

    // --- pinned row --------------------------------------------------------
    // Favourites first, then recents that are not already favourites. Hidden
    // entirely while searching: a search result set and a recents row on screen
    // at the same time is two answers to one question.
    Column {
        id: pinned

        anchors.top: searchBar.bottom
        anchors.topMargin: Appearance.md
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.xs

        readonly property var entries: {
            const favs = Settings.emoji.favourites || [];
            const recents = (Settings.emoji.recent || []).filter(c => favs.indexOf(c) === -1);
            return favs.concat(recents).slice(0, 9);
        }

        visible: body.picker.query === "" && pinned.entries.length > 0
        height: visible ? implicitHeight : 0

        Text {
            text: (Settings.emoji.favourites || []).length > 0 ? "FAVOURITES & RECENT" : "RECENT"
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
            font.weight: Appearance.weightMedium
            font.letterSpacing: Appearance.trackingLabel
        }

        Row {
            spacing: Appearance.xs

            Repeater {
                model: pinned.entries

                EmojiCell {
                    required property var modelData
                    emoji: modelData
                    label: body.picker.lookup(modelData).n
                    favourite: body.picker.isFavourite(modelData)
                    onPicked: body.picker.pick(modelData)
                    onToggleFavourite: body.picker.toggleFavourite(modelData)
                }
            }
        }
    }

    // --- grid ---------------------------------------------------------------
    GridView {
        id: grid

        anchors.top: pinned.visible ? pinned.bottom : searchBar.bottom
        anchors.topMargin: Appearance.md
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: strip.top
        anchors.bottomMargin: Appearance.md

        clip: true
        cellWidth: Math.floor(width / 8)
        cellHeight: grid.cellWidth
        model: body.picker.results

        // Jumping to the top on every keystroke is what makes a search field
        // feel connected to its results.
        onModelChanged: grid.positionViewAtBeginning()

        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
            required property var modelData

            width: grid.cellWidth
            height: grid.cellHeight

            EmojiCell {
                anchors.centerIn: parent
                emoji: modelData.c
                label: modelData.n
                favourite: body.picker.isFavourite(modelData.c)
                onPicked: body.picker.pick(modelData.c)
                onToggleFavourite: body.picker.toggleFavourite(modelData.c)
            }
        }

        // An empty grid with no explanation reads as broken.
        Text {
            anchors.centerIn: parent
            visible: grid.count === 0
            text: "Nothing matches “" + body.picker.query + "”"
            color: Theme.muted
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSmall
        }
    }

    // --- category strip -------------------------------------------------------
    Rectangle {
        id: strip

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        radius: Appearance.radiusInner
        color: Theme.wash(Theme.text, 0.05)

        // Categories mean nothing while a search is running, so they say so
        // rather than sitting there looking clickable.
        opacity: body.picker.query === "" ? 1 : 0.35

        Behavior on opacity {
            enabled: !Appearance.motionless
            NumberAnimation { duration: Appearance.durationFast }
        }

        Row {
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: body.picker.groups

                Rectangle {
                    id: tab

                    required property var modelData
                    required property int index

                    readonly property bool active: body.picker.groupIndex === tab.index
                        && body.picker.query === ""

                    width: 44
                    height: 34
                    radius: Appearance.radiusSmall
                    color: tab.active ? Theme.wash(Theme.accent, 0.20)
                        : tabMouse.containsMouse ? Theme.wash(Theme.text, 0.10)
                        : "transparent"

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: tab.modelData.icon
                        size: 17
                        color: tab.active ? Theme.accent : Theme.muted
                    }

                    MouseArea {
                        id: tabMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            field.text = "";
                            body.picker.groupIndex = tab.index;
                        }
                    }

                    // The group name on hover, since eight icons is more than
                    // anyone should have to memorise.
                    Rectangle {
                        anchors.bottom: parent.top
                        anchors.bottomMargin: Appearance.xs
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tabLabel.implicitWidth + Appearance.md
                        height: 22
                        radius: Appearance.radiusSmall
                        color: Theme.card(0.96)
                        border.width: 1
                        border.color: Theme.wash(Theme.border, 0.35)
                        opacity: tabMouse.containsMouse ? 1 : 0
                        visible: opacity > 0.01

                        Behavior on opacity {
                            enabled: !Appearance.motionless
                            NumberAnimation { duration: Appearance.durationFast }
                        }

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: tab.modelData.name
                            color: Theme.text
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontCaption
                        }
                    }
                }
            }
        }
    }
}
