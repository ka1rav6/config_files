import QtQuick
import qs

// =============================================================================
// Settings — Commands.  (Formerly the Command Center, SUPER + SHIFT + K.)
// =============================================================================
// A front-end for ~/Justfile and the system CLI: a way to run the commands this
// desktop is actually built out of without opening a terminal and remembering
// which one. `just portal-check`, `just phone-ring`, `hyprctl reload`,
// `makoctl restore` -- all of them documented in a 380-line Justfile that you
// otherwise have to read to use.
//
// WHY IT IS A SETTINGS PAGE AND NOT ITS OWN PANEL
//   It used to be one (modules/commandcenter/CommandCenter.qml, now .bak).
//   Two windows of the same size, opening the same way, with the same scrim and
//   the same dimensions, each with a button linking to the other, is one window
//   that has been split in half. The dividing line was never crisp either --
//   "night light" is a toggle you RUN, which put it here, while "blur" is a
//   toggle you SET, which put it there, and nothing about the two feels
//   different when you are looking for one of them.
//
//   The distinction that remains is real and is what the sidebar now expresses:
//
//     Control Center (SUPER + A)   things with a live value you adjust —
//                                  volume, brightness, a Wi-Fi network
//     Settings · Commands          things you RUN. One-shot operations,
//                                  maintenance, diagnostics, restarts.
//     Settings · everything else   things you set once and forget.
//
// WHERE THE STATE LIVES
//   Not here. Every navigational property -- the query, the sub-page, the
//   keyboard cursor, and the three overlay slots -- belongs to the Settings
//   panel (modules/settings/SettingsWindow.qml) and is reached through
//   `panel` below. Three reasons, all of them load-bearing:
//
//     * The confirmation sheet, the input sheet and the output view have to
//       cover the WHOLE settings card, sidebar included -- a modal that leaves
//       the navigation clickable is not modal. They are therefore siblings of
//       this view, not children of it, and siblings cannot read each other's
//       internals.
//     * `quickshell ipc call commandcenter find vpn` reaches
//       `Shell.panels["settings"].query`. A Loader's item is not addressable
//       that way, and this view only exists while its page is selected.
//     * This view is destroyed when you click another sidebar entry. State
//       that lived here would be lost on a trip to Appearance and back.
//
// STRUCTURE
//
//   search box (always focused)
//        │
//        ├── empty query ──► home       Quick Actions, categories, recents
//        └── any query ────► results    one flat ranked list
//
//   home ──► category     a category's commands
//   any ───► options      a selector's choices
//
// COST WHILE NOT SELECTED: NOTHING
//   CommandState reads only service singletons the shell already keeps current
//   for waybar and the Control Center, so this page adds no timers, no
//   subprocesses and no D-Bus subscriptions -- not while another page is
//   showing, and not while this one is either.
// =============================================================================

Item {
    id: root

    // The Settings panel. See WHERE THE STATE LIVES above -- this view reads
    // and writes the panel's properties rather than holding any of its own.
    required property var panel

    // The search field never loses focus while this page is up, so every
    // overlay hands it back here on dismissal rather than leaving the panel
    // with no keyboard target (at which point Escape stops working).
    function focusSearch() { input.forceActiveFocus(); }

    // --- search ----------------------------------------------------------
    //
    // The CLI toggle rides in this row rather than in a header band of its
    // own: the sidebar already names the page, so a second "Commands" title
    // would be a heading above a heading, and the row is 52 px that the list
    // can have instead.
    Item {
        id: searchRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        implicitHeight: Math.max(searchBox.height, cliToggle.implicitHeight)

        Rectangle {
            id: searchBox

            anchors.left: parent.left
            anchors.right: cliToggle.left
            anchors.rightMargin: Appearance.xs
            anchors.verticalCenter: parent.verticalCenter

            height: Appearance.controlHeight + 8
            radius: Appearance.radiusInner
            color: Theme.wash(Theme.bg, 0.5)
            border.width: 1
            border.color: Theme.wash(Theme.accent, input.activeFocus ? 0.5 : 0.15)

            Behavior on border.color {
                enabled: !Appearance.motionless
                ColorAnimation { duration: Appearance.durationFast }
            }

            Icon {
                id: searchIcon

                name: "search"
                size: Appearance.iconSize
                color: Theme.muted
                anchors.left: parent.left
                anchors.leftMargin: Appearance.md
                anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
                id: input

                anchors.left: searchIcon.right
                anchors.leftMargin: Appearance.sm
                anchors.right: clearButton.left
                anchors.rightMargin: Appearance.sm
                anchors.verticalCenter: parent.verticalCenter

                text: root.panel.query
                onTextChanged: root.panel.query = input.text

                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontLabel
                selectByMouse: true
                selectionColor: Theme.wash(Theme.accent, 0.35)
                selectedTextColor: Theme.text
                clip: true

                focus: true

                // Panel focuses the FocusScope around the whole card when the
                // window appears, and `focus: true` routes it down to here --
                // but this item is built by a Loader when the Commands page is
                // selected, which is usually long after that. Taking the focus
                // on completion covers both the first open and every return to
                // this page from another one.
                Component.onCompleted: input.forceActiveFocus()

                // --- keyboard navigation ----------------------------------
                // All of it lives on the search field, because the field never
                // loses focus: you can be three rows down a list and still
                // type to refine, which is the behaviour that makes a search
                // launcher fast. The arrow keys move a cursor that is drawn
                // elsewhere rather than moving focus.

                Keys.onDownPressed: root.panel.moveSelection(1)
                Keys.onUpPressed: root.panel.moveSelection(-1)

                Keys.onReturnPressed: root.panel.activateSelected()
                Keys.onEnterPressed: root.panel.activateSelected()

                // Tab cycles rather than leaving the field, for the same
                // reason: nothing else here wants the focus.
                Keys.onTabPressed: root.panel.moveSelection(1)
                Keys.onBacktabPressed: root.panel.moveSelection(-1)

                Keys.onEscapePressed: (event) => {
                    event.accepted = true;
                    root.panel.goBack();
                }

                Keys.onPressed: (event) => {
                    // Ctrl+D pins or unpins whatever the cursor is on, so
                    // favourites can be curated without reaching for the
                    // mouse. D for "done to death" is wrong; it is the one
                    // free letter that is not already a text-editing key here.
                    if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
                        const cmd = root.panel.selectedCommand();
                        if (cmd) CommandRunner.toggleFavourite(cmd.id);
                        event.accepted = true;
                        return;
                    }

                    // Ctrl+O opens the last output of the selected command --
                    // the keyboard route to the same place the toast's "Show
                    // output" button goes.
                    if (event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier)) {
                        const cmd = root.panel.selectedCommand();
                        if (cmd) {
                            const run = CommandRunner.lastRun(cmd.id);
                            if (run) root.panel.outputRun = run;
                        }
                        event.accepted = true;
                        return;
                    }

                    // Home and End, for a long category.
                    if (event.key === Qt.Key_Home && root.panel.activeList.length > 0) {
                        root.panel.selected = 0;
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_End && root.panel.activeList.length > 0) {
                        root.panel.selected = root.panel.activeList.length - 1;
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: CommandRegistry.commands.length
                        + " commands — try theme, phone, portal, reload, cache"
                    color: Theme.muted
                    opacity: 0.6
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontLabel
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            Item {
                id: clearButton

                anchors.right: parent.right
                anchors.rightMargin: Appearance.xs
                anchors.verticalCenter: parent.verticalCenter
                width: root.panel.query !== "" ? Appearance.touchTarget : 0
                height: Appearance.touchTarget
                visible: width > 0

                Icon {
                    anchors.centerIn: parent
                    name: "close"
                    size: Appearance.iconSize
                    color: clearMouse.containsMouse ? Theme.text : Theme.muted
                }

                MouseArea {
                    id: clearMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.panel.query = "";
                        input.forceActiveFocus();
                    }
                }
            }
        }

        // Show or hide the terminal-equivalent line under every row. On by
        // default: the page doubling as documentation for the CLI it fronts is
        // most of the point. Off for when you already know them and want the
        // density back.
        Button {
            id: cliToggle

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            icon: Settings.commands.showCli ? "eye" : "eye-off"
            variant: "ghost"
            onClicked: {
                Settings.commands.showCli = !Settings.commands.showCli;
                input.forceActiveFocus();
            }
        }
    }

    // --- body ------------------------------------------------------------
    Flickable {
        id: scroll

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchRow.bottom
        anchors.topMargin: Appearance.lg
        anchors.bottom: toast.top
        anchors.bottomMargin: toast.showing ? Appearance.md : 0

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
                switch (root.panel.cmdPage) {
                case "results": return resultsPage;
                case "category": return categoryPage;
                case "options": return optionsPage;
                default: return homePage;
                }
            }

            // Fade between pages. No slide: the heading already says where you
            // are, and a horizontal slide inside a window that is not moving
            // reads as a glitch. Same decision as the settings pages next door.
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

    // Keep the keyboard cursor on screen as the arrow keys walk past the
    // bottom of the viewport. Without this, holding Down in a long category
    // moves an invisible selection.
    Connections {
        target: root.panel

        function onSelectedChanged() {
            if (root.panel.selected < 0 || !pageLoader.item) return;
            // Rows are a uniform height inside a Card with one padding, so the
            // position is derivable without reaching into the delegate --
            // which a Repeater does not expose anyway.
            const rowHeight = Appearance.touchTarget + Appearance.sm * 2;
            const y = root.panel.selected * rowHeight;
            if (y < scroll.contentY)
                scroll.contentY = Math.max(0, y - rowHeight);
            else if (y + rowHeight > scroll.contentY + scroll.height)
                scroll.contentY = y + rowHeight * 2 - scroll.height;
        }
    }

    Component {
        id: homePage

        CmdHome {
            width: pageLoader.width
            onActivate: (cmd) => root.panel.invoke(cmd, undefined, undefined)
            onOpenCategory: (id) => {
                root.panel.categoryId = id;
                root.panel.cmdPage = "category";
                root.panel.selected = -1;
            }
        }
    }

    Component {
        id: resultsPage

        CmdList {
            width: pageLoader.width
            commands: root.panel.results
            title: root.panel.results.length === 1
                ? "1 match" : root.panel.results.length + " matches"
            subtitle: root.panel.results.length > 0
                ? "Enter runs the highlighted one · Ctrl+D pins it" : ""
            showCategory: true
            selectedIndex: root.panel.selected

            onActivate: (cmd) => root.panel.invoke(cmd, undefined, undefined)
            onExpand: (cmd) => root.panel.invoke(cmd, undefined, undefined)
        }
    }

    Component {
        id: categoryPage

        CmdList {
            width: pageLoader.width
            commands: root.panel.categoryCommands
            title: {
                const c = CommandRegistry.category(root.panel.categoryId);
                return c ? c.label : root.panel.categoryId;
            }
            subtitle: {
                const c = CommandRegistry.category(root.panel.categoryId);
                return c ? c.desc : "";
            }
            showBack: true
            selectedIndex: root.panel.selected

            onBack: root.panel.goHome()
            onActivate: (cmd) => root.panel.invoke(cmd, undefined, undefined)
            onExpand: (cmd) => root.panel.invoke(cmd, undefined, undefined)
        }
    }

    Component {
        id: optionsPage

        CmdOptions {
            width: pageLoader.width
            command: root.panel.optionCommand
            selectedIndex: root.panel.selected

            onBack: root.panel.goBackFromOptions()
            onChoose: (cmd, option) => root.panel.invoke(cmd, option.id, option.label)
        }
    }

    // --- toast -----------------------------------------------------------
    CmdToast {
        id: toast

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: toast.showing ? toast.implicitHeight : 0

        onShowOutput: (id) => {
            const run = CommandRunner.lastRun(id);
            if (run) root.panel.outputRun = run;
        }
    }

    // Every result from the executor becomes a toast. Wired here rather than
    // inside CommandRunner so the singleton stays free of UI -- it emits, the
    // page presents.
    Connections {
        target: CommandRunner

        function onNotify(id, title, message, tone) {
            toast.show(id, title, message, tone);
        }
    }
}
