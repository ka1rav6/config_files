import QtQuick
import qs

// =============================================================================
// Command Center.  SUPER + SHIFT + K, or the ⌘ button on waybar.
// =============================================================================
// The thing this desktop did not have: a way to run the commands it is actually
// built out of without opening a terminal and remembering which one. `just
// portal-check`, `just phone-ring`, `just restore-check`, `hyprctl reload`,
// `makoctl restore` -- all of them documented in a 380-line Justfile that you
// have to read to use.
//
// It is NOT a second Control Center and not a second Settings window. The test
// for belonging here is "is this something I currently do by typing a command":
//
//   Control Center (SUPER + A)   things with a live value you adjust —
//                                volume, brightness, a Wi-Fi network
//   Settings (SUPER + ,)         things you set once and forget —
//                                fonts, radius, which components load
//   Command Center               things you RUN. One-shot operations,
//                                maintenance, diagnostics, restarts.
//
// Where those overlap, this panel links out rather than reimplementing: the
// `tools` category's rows open the Control Center, Settings, the wallpaper
// picker, pavucontrol and nm-connection-editor. That is why searching "wifi"
// here finds something useful instead of nothing -- a launcher whose answer to
// a reasonable question is silence is a launcher you stop trusting -- without
// this file growing a second Wi-Fi list to keep in sync with the first.
//
// -----------------------------------------------------------------------------
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
// A page stack of exactly one deep, plus the search overlay. Deeper nesting in
// a launcher means getting lost, and Escape has to mean one unambiguous thing.
//
// WHY IT IS A Panel AND NOT A NEW WINDOW TYPE
//   ui/Panel.qml already solves every hard part: the full-screen transparent
//   layer-shell surface with the card masked inside it (see the long note there
//   about why an edge-anchored PanelWindow comes out zero-sized), the focus
//   grab that makes click-outside and Escape work, the LazyLoader that means
//   nothing here exists while the panel is closed, and registration with
//   services/Shell.qml so opening this closes the Control Center. Building a
//   bespoke window would have reintroduced all of it.
//
// COST WHILE CLOSED: NOTHING
//   Panel's LazyLoader builds the window on first open and destroys it after
//   close. CommandState reads only service singletons the shell already keeps
//   current for waybar and the Control Center, so this panel adds no timers, no
//   subprocesses and no D-Bus subscriptions -- not while closed, and not while
//   open either. The two things that would have cost something, a Wi-Fi scan
//   and Bluetooth discovery, are not here at all: they stay gated to the
//   Control Center pages that need them.
// -----------------------------------------------------------------------------

Panel {
    id: root

    name: "command-center"
    placement: "center"
    panelWidth: Appearance.modalWidth
    panelHeight: Appearance.modalHeight
    scrim: true

    // "home" | "results" | "category" | "options"
    property string page: "home"
    property string categoryId: ""
    property var optionCommand: null

    property string query: ""

    // Keyboard cursor. -1 means "no selection", which is the right state when
    // the list is being read with the mouse: Return then does nothing rather
    // than firing whatever happened to be first.
    property int selected: -1

    // --- overlay state ---------------------------------------------------
    //
    // The confirmation sheet and the output view are driven from HERE rather
    // than by assigning to their ids, and this is not a style preference: a
    // Panel's `content` is a Component, instantiated by the LazyLoader in
    // ui/Panel.qml. Ids declared inside it do not exist in this scope, so a
    // function up here that said `confirm.command = null` would fail at
    // runtime with an unqualified lookup -- and only when that path was taken,
    // which is the worst time to find out.
    //
    // Keeping the state on the Panel also means the navigation logic below is
    // one place and the two overlays are purely presentational: they render
    // what these properties say and emit when the user answers.
    property var confirmCommand: null
    property string confirmArg: ""
    property string confirmLabel: ""
    property var outputRun: null
    // The command waiting on a typed value (a URL, a message, some text).
    property var promptCommand: null

    readonly property var results: CommandRegistry.search(root.query)

    readonly property var categoryCommands: root.categoryId !== ""
        ? CommandRegistry.inCategory(root.categoryId) : []

    // The list the keyboard is currently driving.
    readonly property var activeList: {
        if (root.page === "results") return root.results;
        if (root.page === "category") return root.categoryCommands;
        return [];
    }

    // -----------------------------------------------------------------
    // Opening and closing
    // -----------------------------------------------------------------

    // Always opens on home with an empty box. A launcher that reopens where it
    // was left days ago is a launcher you have to read before you can use.
    // The content does not exist yet when this fires -- Panel's LazyLoader
    // builds it asynchronously -- so focus is NOT taken here. The search field
    // declares `focus: true` inside the FocusScope that ui/Panel.qml focuses
    // when the window appears, and takes it again on completion, which covers
    // both the first open and every reopen.
    onOpened: root.reset()

    onClosed: {
        root.confirmCommand = null;
        root.promptCommand = null;
        root.outputRun = null;
        resetTimer.restart();
    }

    Timer {
        id: resetTimer

        // After the close animation, so the panel does not visibly snap back
        // to home while it is fading out.
        interval: Appearance.durationSlow + 40
        onTriggered: if (!root.open) root.reset()
    }

    function reset() {
        root.page = "home";
        root.categoryId = "";
        root.optionCommand = null;
        root.query = "";
        root.selected = -1;
        root.confirmCommand = null;
        root.promptCommand = null;
        root.outputRun = null;
    }

    // Typing switches to results; clearing the box goes back where you were,
    // which for a search is home.
    onQueryChanged: {
        if (root.query !== "") {
            if (root.page !== "results") root.page = "results";
            root.selected = root.results.length > 0 ? 0 : -1;
        } else if (root.page === "results") {
            root.page = "home";
            root.selected = -1;
        }
    }

    // Keep the cursor on a real row as the list changes under it.
    //
    // This used to only pull the cursor back when it ran off the END, which
    // left the far more common case broken: QML does not order a property's
    // change HANDLER against the re-evaluation of bindings that depend on the
    // same property, so when `query` changed, onQueryChanged could run while
    // `results` still held the previous (empty) list. It then set selected to
    // -1, this handler saw -1 < length and left it there, and the panel sat on
    // "Enter runs the highlighted one" with nothing highlighted -- Enter did
    // nothing at all unless you first pressed Down.
    //
    // Clamping from BOTH ends here makes the outcome independent of that
    // ordering, which is the only way to be right about it.
    onResultsChanged: {
        if (root.page !== "results") return;
        if (root.results.length === 0) { root.selected = -1; return; }
        if (root.selected < 0 || root.selected >= root.results.length)
            root.selected = 0;
    }

    // -----------------------------------------------------------------
    // Running a command
    //
    // ONE route in, so the confirmation gate cannot be bypassed. A row, a
    // Quick Action tile, a recents entry and the Return key all land here --
    // which is the only way to be sure a `danger` command gets its sheet no
    // matter where it was clicked from.
    // -----------------------------------------------------------------
    function invoke(cmd, arg, optionLabel) {
        if (!cmd) return;

        // A selector with no argument yet is a request to see the choices, not
        // to run anything.
        if (cmd.ui === "select" && arg === undefined) {
            root.optionCommand = cmd;
            root.page = "options";
            root.selected = -1;
            return;
        }

        // A command that needs a value, and has not been given one yet.
        // Files go to the desktop's picker; everything else to the sheet.
        if (cmd.input !== undefined && arg === undefined) {
            if (cmd.input.kind === "files") CommandRunner.pickFiles(cmd);
            else root.promptCommand = cmd;
            return;
        }

        if (cmd.safety === "safe") {
            root.execute(cmd, arg);
            return;
        }

        root.confirmArg = arg !== undefined ? String(arg) : "";
        root.confirmLabel = optionLabel !== undefined ? optionLabel : "";
        root.confirmCommand = cmd;
    }

    function execute(cmd, arg) {
        CommandRunner.run(cmd, arg);

        // Links have already moved the user somewhere else; staying open would
        // leave this panel behind whatever just opened.
        if (cmd.ui === "link") return;

        // Toggles and selectors stay put: flipping two switches in a row, or
        // trying a second theme, should not cost a reopen. One-shot actions
        // close, because their result is the toast and there is nothing left
        // to look at here.
        //
        // Commands that took a value stay open too. Sending one file to the
        // phone is very often followed by sending another, and the panel
        // closing out from under a flow you are in the middle of is the
        // opposite of fast.
        if (cmd.ui === "action" && cmd.output !== true
                && cmd.input === undefined) root.hide();
    }

    // -----------------------------------------------------------------
    // Content
    // -----------------------------------------------------------------
    content: Item {
        id: body

        // --- header ------------------------------------------------------
        Item {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            // Derived, not guessed. This was `fontHeading + sm` -- 28 px --
            // while the two buttons on the right are Appearance.controlHeight
            // (44) and centred in it, so they overhung the header by 8 px at
            // both ends and ate into the gap above the search field.
            implicitHeight: Math.max(titleRow.implicitHeight,
                                     headerActions.implicitHeight)

            Row {
                id: titleRow

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.sm

                Text {
                    id: titleText

                    anchors.verticalCenter: parent.verticalCenter
                    text: "Command Center"
                    color: Theme.text
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontHeading
                    font.weight: Appearance.weightSemi
                    font.letterSpacing: Appearance.trackingHeading
                }

                // Sits on the title's baseline rather than its centre: two
                // sizes of type centred against each other never look aligned,
                // and `bottomPadding: 2` to fake it was a magic number that
                // only held at fontScale 1.
                Text {
                    anchors.baseline: titleText.baseline
                    text: CommandRegistry.commands.length + " commands"
                    color: Theme.muted
                    opacity: 0.6
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                }
            }

            Row {
                id: headerActions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.xs

                // Show or hide the terminal-equivalent line under every row.
                // On by default: the panel doubling as documentation for the
                // CLI it fronts is most of the point. Off for when you already
                // know them and want the density back.
                Button {
                    icon: Settings.commands.showCli ? "eye" : "eye-off"
                    variant: "ghost"
                    onClicked: Settings.commands.showCli = !Settings.commands.showCli
                }

                Button {
                    icon: "settings"
                    variant: "ghost"
                    onClicked: {
                        Shell.close("command-center");
                        Shell.open("settings");
                    }
                }
            }
        }

        // --- search ------------------------------------------------------
        Rectangle {
            id: searchBox

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: Appearance.md

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

                text: root.query
                onTextChanged: root.query = input.text

                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontLabel
                selectByMouse: true
                selectionColor: Theme.wash(Theme.accent, 0.35)
                selectedTextColor: Theme.text
                clip: true

                focus: true

                // Panel focuses the FocusScope around this when the window
                // appears, and `focus: true` routes it here -- but on the very
                // first open the window exists before this item does, so the
                // scope's forceActiveFocus() finds nothing to give it to.
                Component.onCompleted: input.forceActiveFocus()

                // --- keyboard navigation ----------------------------------
                // All of it lives on the search field, because the field never
                // loses focus: you can be three rows down a list and still
                // type to refine, which is the behaviour that makes a search
                // launcher fast. The arrow keys move a cursor that is drawn
                // elsewhere rather than moving focus.

                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)

                Keys.onReturnPressed: root.activateSelected()
                Keys.onEnterPressed: root.activateSelected()

                // Tab cycles rather than leaving the field, for the same
                // reason: nothing else here wants the focus.
                Keys.onTabPressed: root.moveSelection(1)
                Keys.onBacktabPressed: root.moveSelection(-1)

                Keys.onEscapePressed: (event) => {
                    event.accepted = true;
                    root.goBack();
                }

                Keys.onPressed: (event) => {
                    // Ctrl+D pins or unpins whatever the cursor is on, so
                    // favourites can be curated without reaching for the
                    // mouse. D for "done to death" is wrong; it is the one
                    // free letter that is not already a text-editing key here.
                    if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) {
                        const cmd = root.selectedCommand();
                        if (cmd) CommandRunner.toggleFavourite(cmd.id);
                        event.accepted = true;
                        return;
                    }

                    // Ctrl+O opens the last output of the selected command --
                    // the keyboard route to the same place the toast's "Show
                    // output" button goes.
                    if (event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier)) {
                        const cmd = root.selectedCommand();
                        if (cmd) {
                            const run = CommandRunner.lastRun(cmd.id);
                            if (run) root.outputRun = run;
                        }
                        event.accepted = true;
                        return;
                    }

                    // Home and End, for a long category.
                    if (event.key === Qt.Key_Home && root.activeList.length > 0) {
                        root.selected = 0;
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_End && root.activeList.length > 0) {
                        root.selected = root.activeList.length - 1;
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.fill: parent
                    visible: input.text === ""
                    text: "Search commands — try theme, phone, portal, reload, cache"
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
                width: root.query !== "" ? Appearance.touchTarget : 0
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
                        root.query = "";
                        input.forceActiveFocus();
                    }
                }
            }
        }

        // --- body --------------------------------------------------------
        Flickable {
            id: scroll

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchBox.bottom
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
                    switch (root.page) {
                    case "results": return resultsPage;
                    case "category": return categoryPage;
                    case "options": return optionsPage;
                    default: return homePage;
                    }
                }

                // Fade between pages. No slide: the heading already says where
                // you are, and a horizontal slide inside a window that is not
                // moving reads as a glitch. Same decision as
                // modules/settings/SettingsWindow.qml.
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
        // bottom of the viewport. Without this, holding Down in a long
        // category moves an invisible selection.
        Connections {
            target: root

            function onSelectedChanged() {
                if (root.selected < 0 || !pageLoader.item) return;
                // Rows are a uniform height inside a Card with one padding,
                // so the position is derivable without reaching into the
                // delegate -- which a Repeater does not expose anyway.
                const rowHeight = Appearance.touchTarget + Appearance.sm * 2;
                const y = root.selected * rowHeight;
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
                onActivate: (cmd) => root.invoke(cmd, undefined, undefined)
                onOpenCategory: (id) => {
                    root.categoryId = id;
                    root.page = "category";
                    root.selected = -1;
                }
            }
        }

        Component {
            id: resultsPage

            CmdList {
                width: pageLoader.width
                commands: root.results
                title: root.results.length === 1
                    ? "1 match" : root.results.length + " matches"
                subtitle: root.results.length > 0
                    ? "Enter runs the highlighted one · Ctrl+D pins it" : ""
                showCategory: true
                selectedIndex: root.selected

                onActivate: (cmd) => root.invoke(cmd, undefined, undefined)
                onExpand: (cmd) => root.invoke(cmd, undefined, undefined)
            }
        }

        Component {
            id: categoryPage

            CmdList {
                width: pageLoader.width
                commands: root.categoryCommands
                title: {
                    const c = CommandRegistry.category(root.categoryId);
                    return c ? c.label : root.categoryId;
                }
                subtitle: {
                    const c = CommandRegistry.category(root.categoryId);
                    return c ? c.desc : "";
                }
                showBack: true
                selectedIndex: root.selected

                onBack: root.goHome()
                onActivate: (cmd) => root.invoke(cmd, undefined, undefined)
                onExpand: (cmd) => root.invoke(cmd, undefined, undefined)
            }
        }

        Component {
            id: optionsPage

            CmdOptions {
                width: pageLoader.width
                command: root.optionCommand
                selectedIndex: root.selected

                onBack: root.goBackFromOptions()
                onChoose: (cmd, option) => root.invoke(cmd, option.id, option.label)
            }
        }

        // --- toast -------------------------------------------------------
        CmdToast {
            id: toast

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: toast.showing ? toast.implicitHeight : 0

            onShowOutput: (id) => {
                const run = CommandRunner.lastRun(id);
                if (run) root.outputRun = run;
            }
        }

        // --- confirmation ------------------------------------------------
        // Anchored to the card's content area rather than to the screen, so
        // the dim stays inside the panel and the panel still reads as the
        // thing being operated.
        CmdConfirm {
            id: confirm

            anchors.fill: parent
            anchors.margins: -Appearance.padding

            command: root.confirmCommand
            optionArg: root.confirmArg
            optionLabel: root.confirmLabel

            onConfirmed: (cmd, arg) => {
                root.confirmCommand = null;
                root.execute(cmd, arg !== "" ? arg : undefined);
                // The sheet held the focus while it was up; hand it back, or
                // the panel is left with no keyboard target and Escape stops
                // working. (Harmless when execute() closed the panel.)
                input.forceActiveFocus();
            }

            onCancelled: {
                root.confirmCommand = null;
                input.forceActiveFocus();
            }
        }

        // --- input -------------------------------------------------------
        CmdPrompt {
            id: prompt

            anchors.fill: parent
            anchors.margins: -Appearance.padding

            command: root.promptCommand

            onSubmitted: (cmd, value) => {
                root.promptCommand = null;
                // Straight to invoke rather than execute, so a command that is
                // BOTH input-taking and confirm/danger still gets its sheet.
                // None is today; the gate should not depend on that staying
                // true.
                root.invoke(cmd, value, undefined);
                input.forceActiveFocus();
            }

            onCancelled: {
                root.promptCommand = null;
                input.forceActiveFocus();
            }
        }

        // --- output ------------------------------------------------------
        CmdOutput {
            id: output

            anchors.fill: parent
            anchors.margins: -Appearance.padding

            run: root.outputRun

            onClosed: {
                root.outputRun = null;
                input.forceActiveFocus();
            }
        }

        // Every result from the executor becomes a toast. Wired here rather
        // than inside CommandRunner so the singleton stays free of UI -- it
        // emits, the panel presents.
        Connections {
            target: CommandRunner

            function onNotify(id, title, message, tone) {
                toast.show(id, title, message, tone);
            }
        }
    }

    // -----------------------------------------------------------------
    // Navigation
    // -----------------------------------------------------------------

    function selectedCommand() {
        if (root.selected < 0 || root.selected >= root.activeList.length) return null;
        return root.activeList[root.selected];
    }

    function moveSelection(delta) {
        const n = root.activeList.length;
        if (n === 0) return;
        if (root.selected < 0) {
            root.selected = delta > 0 ? 0 : n - 1;
            return;
        }
        // Wraps. In a list this short, stopping at the end is a dead key
        // press; wrapping means Up from the top is the fast way to the bottom.
        root.selected = (root.selected + delta + n) % n;
    }

    function activateSelected() {
        const cmd = root.selectedCommand();
        if (cmd) { root.invoke(cmd, undefined, undefined); return; }

        // Nothing highlighted but exactly one match: Enter should obviously
        // run it rather than doing nothing because the cursor was never moved.
        if (root.page === "results" && root.results.length === 1)
            root.invoke(root.results[0], undefined, undefined);
    }

    function goHome() {
        root.page = "home";
        root.categoryId = "";
        root.selected = -1;
    }

    function goBackFromOptions() {
        root.optionCommand = null;
        // Back to wherever the selector was opened from, which is the category
        // page if one is open and otherwise the search results or home.
        root.page = root.categoryId !== "" ? "category"
                  : root.query !== "" ? "results" : "home";
        root.selected = -1;
    }

    // Escape unwinds one level at a time and only closes when there is nothing
    // left to unwind. A single Escape that closes the whole panel from three
    // levels deep is how you lose the search you had just typed.
    //
    // NOT called `escape()`. QML rejects that outright -- "Illegal method
    // name", because it collides with the JavaScript global of the same name --
    // and it does so at load time, taking the whole shell config down with it
    // rather than just this panel.
    function goBack() {
        if (root.outputRun !== null) { root.outputRun = null; return; }
        if (root.promptCommand !== null) { root.promptCommand = null; return; }
        if (root.confirmCommand !== null) { root.confirmCommand = null; return; }
        if (root.page === "options") { root.goBackFromOptions(); return; }
        if (root.query !== "") { root.query = ""; return; }
        if (root.page === "category") { root.goHome(); return; }
        root.hide();
    }
}
