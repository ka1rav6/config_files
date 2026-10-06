import QtQuick
import Quickshell
import qs

// =============================================================================
// Settings.  SUPER + ,  (and SUPER + SHIFT + K, which lands on Commands)
// =============================================================================
// The thing this desktop did not have: one place to configure it, instead of
// `just theme`, a Python slider popup, a shell script driving wofi, and editing
// QML by hand.
//
// WHAT IT IS NOT
//   It is not a control panel for the operating system. Monitors, Wi-Fi
//   profiles and per-app audio routing have real tools already
//   (nm-connection-editor, pavucontrol) and this links to them rather than
//   reimplementing them badly. What lives here is everything about the
//   DESKTOP SHELL, which previously had no interface at all.
//
// THE COMMAND CENTER IS THE FIRST PAGE, NOT A SECOND WINDOW
//   It used to be its own panel: same size, same placement, same scrim, same
//   entrance, with a button in each one linking to the other. That is one
//   window that had been split in half, and the split did not fall anywhere
//   meaningful -- "night light" is a toggle you RUN so it lived there, "blur"
//   is a toggle you SET so it lived here, and neither feels different when you
//   are looking for one of them. See modules/settings/SettingsCommands.qml for
//   the distinction that survived, and why that page keeps its state up HERE
//   rather than in the view.
//
// HOW IT SAVES
//   Every control writes straight to the matching property in
//   config/Settings.qml, which persists to ~/.config/quickshell/settings.json
//   on a 400 ms debounce. There is no Apply button and no separate "pending"
//   state to keep in sync -- a slider moves and the desktop changes under it.
//   The one exception is the theme, which goes through theme-switch (see
//   SettingsAppearance.qml) because it has to retheme nine other applications
//   too, and that is a several-second operation with its own progress.
//
// THE CONFIG FILE REMAINS EDITABLE
//   settings.json is watched, so editing it in Neovim updates a running
//   Settings window live. The GUI is a front-end to that file, never a
//   replacement for it.
// =============================================================================

Panel {
    id: root

    name: "settings"
    placement: "center"
    panelWidth: Appearance.modalWidth
    panelHeight: Appearance.modalHeight
    scrim: true

    property string page: "appearance"

    // The Commands page is gated on the same feature flag the Command Center
    // panel used to be, so turning it off still unloads the whole thing --
    // the sidebar entry disappears and `ipc call commandcenter ...` says so.
    readonly property var pages: {
        const list = [];
        if (Settings.features.commandCenter)
            list.push({ id: "commands", label: "Commands", icon: "terminal" });
        list.push(
            { id: "appearance",  label: "Appearance",  icon: "palette" },
            { id: "desktop",     label: "Desktop",     icon: "desktop" },
            { id: "audio",       label: "Audio",       icon: "volume-high" },
            { id: "network",     label: "Network",     icon: "wifi-4" },
            { id: "shell",       label: "Dock & Launcher", icon: "dock" },
            { id: "windows",     label: "Windows",     icon: "monitor" },
            { id: "components",  label: "Components",  icon: "widgets" },
            { id: "visualizer",  label: "Visualizer",  icon: "visualizer" },
            { id: "performance", label: "Performance", icon: "performance" },
            { id: "system",      label: "System",      icon: "settings" },
            { id: "about",       label: "About",       icon: "info" }
        );
        return list;
    }

    // Turning the Commands page off in Settings > Components while standing on
    // it would otherwise leave the window showing a page with no sidebar entry
    // and no way back.
    onPagesChanged: {
        if (root.page === "commands" && !Settings.features.commandCenter)
            root.page = "appearance";
    }

    // =====================================================================
    // Commands page state
    //
    // All of it lives here rather than in SettingsCommands.qml, for the three
    // reasons set out in that file's header: the overlays below have to cover
    // the sidebar too and so cannot be children of the view; the IPC handlers
    // in shell.qml reach these through `Shell.panels["settings"]`; and the
    // view is destroyed the moment another sidebar entry is clicked.
    // =====================================================================

    // "home" | "results" | "category" | "options"
    property string cmdPage: "home"
    property string categoryId: ""
    property var optionCommand: null

    property string query: ""

    // Keyboard cursor. -1 means "no selection", which is the right state when
    // the list is being read with the mouse: Return then does nothing rather
    // than firing whatever happened to be first.
    property int selected: -1

    // --- overlay state ---------------------------------------------------
    //
    // The confirmation sheet, the input sheet and the output view are driven
    // from HERE rather than by assigning to their ids, and this is not a style
    // preference: a Panel's `content` is a Component, instantiated by the
    // LazyLoader in ui/Panel.qml. Ids declared inside it do not exist in this
    // scope, so a function up here that said `confirm.command = null` would
    // fail at runtime with an unqualified lookup -- and only when that path was
    // taken, which is the worst time to find out.
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
        if (root.cmdPage === "results") return root.results;
        if (root.cmdPage === "category") return root.categoryCommands;
        return [];
    }

    // Always opens the Commands page on home with an empty box. A launcher
    // that reopens where it was left days ago is a launcher you have to read
    // before you can use. The sidebar page itself is NOT reset -- that is a
    // place in a settings window, not a search in progress.
    onOpened: root.resetCommands()

    onClosed: {
        root.confirmCommand = null;
        root.promptCommand = null;
        root.outputRun = null;
        resetTimer.restart();
    }

    Timer {
        id: resetTimer

        // After the close animation, so the page does not visibly snap back to
        // home while it is fading out.
        interval: Appearance.durationSlow + 40
        onTriggered: if (!root.open) root.resetCommands()
    }

    function resetCommands() {
        root.cmdPage = "home";
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
            if (root.cmdPage !== "results") root.cmdPage = "results";
            root.selected = root.results.length > 0 ? 0 : -1;
        } else if (root.cmdPage === "results") {
            root.cmdPage = "home";
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
    // -1, this handler saw -1 < length and left it there, and the page sat on
    // "Enter runs the highlighted one" with nothing highlighted -- Enter did
    // nothing at all unless you first pressed Down.
    //
    // Clamping from BOTH ends here makes the outcome independent of that
    // ordering, which is the only way to be right about it.
    onResultsChanged: {
        if (root.cmdPage !== "results") return;
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
            root.cmdPage = "options";
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
        // leave this window behind whatever just opened. The ones that link to
        // another PAGE of this window are `ui: "action"` for that reason --
        // see the `tools` category in CommandRegistry.qml.
        if (cmd.ui === "link") return;

        // Toggles and selectors stay put: flipping two switches in a row, or
        // trying a second theme, should not cost a reopen. One-shot actions
        // close, because their result is the toast and there is nothing left
        // to look at here.
        //
        // Commands that took a value stay open too. Sending one file to the
        // phone is very often followed by sending another, and the window
        // closing out from under a flow you are in the middle of is the
        // opposite of fast.
        if (cmd.ui === "action" && cmd.output !== true
                && cmd.input === undefined) root.hide();
    }

    // -----------------------------------------------------------------
    // Commands navigation
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
        if (root.cmdPage === "results" && root.results.length === 1)
            root.invoke(root.results[0], undefined, undefined);
    }

    function goHome() {
        root.cmdPage = "home";
        root.categoryId = "";
        root.selected = -1;
    }

    function goBackFromOptions() {
        root.optionCommand = null;
        // Back to wherever the selector was opened from, which is the category
        // page if one is open and otherwise the search results or home.
        root.cmdPage = root.categoryId !== "" ? "category"
                     : root.query !== "" ? "results" : "home";
        root.selected = -1;
    }

    // Escape unwinds one level at a time and only closes when there is nothing
    // left to unwind. A single Escape that closes the whole window from three
    // levels deep is how you lose the search you had just typed.
    //
    // NOT called `escape()`. QML rejects that outright -- "Illegal method
    // name", because it collides with the JavaScript global of the same name --
    // and it does so at load time, taking the whole shell config down with it
    // rather than just this window.
    function goBack() {
        if (root.outputRun !== null) { root.outputRun = null; return; }
        if (root.promptCommand !== null) { root.promptCommand = null; return; }
        if (root.confirmCommand !== null) { root.confirmCommand = null; return; }
        if (root.cmdPage === "options") { root.goBackFromOptions(); return; }
        if (root.query !== "") { root.query = ""; return; }
        if (root.cmdPage === "category") { root.goHome(); return; }
        root.hide();
    }

    content: Item {

        // --- sidebar ------------------------------------------------------
        Column {
            id: sidebar

            width: 190
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: Appearance.xs

            Text {
                text: "Settings"
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontHeading
                font.weight: Appearance.weightSemi
                font.letterSpacing: Appearance.trackingHeading
                bottomPadding: Appearance.md
            }

            Repeater {
                model: root.pages

                Rectangle {
                    required property var modelData

                    width: sidebar.width
                    height: Appearance.controlHeight
                    radius: Appearance.radiusInner

                    readonly property bool selected: root.page === modelData.id

                    color: selected ? Theme.wash(Theme.accent, 0.18)
                         : navMouse.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }

                    // A thin accent bar on the selected item, so the current
                    // page is readable even at a glance across the window.
                    Rectangle {
                        width: 3
                        height: parent.height * 0.5
                        radius: 2
                        color: Theme.accent
                        opacity: parent.selected ? 1 : 0
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on opacity {
                            enabled: !Appearance.motionless
                            NumberAnimation { duration: Appearance.durationNormal }
                        }
                    }

                    Icon {
                        id: navIcon
                        name: modelData.icon
                        size: Appearance.iconSize
                        color: parent.selected ? Theme.accent : Theme.muted
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.md
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.left: navIcon.right
                        anchors.leftMargin: Appearance.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: parent.selected ? Theme.text : Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontBody
                        font.weight: parent.selected ? Appearance.weightMedium : Appearance.weightNormal
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.page = modelData.id
                    }
                }
            }
        }

        // --- Commands -----------------------------------------------------
        //
        // Outside the Flickable below, not inside it: this page scrolls its own
        // list against a search box that has to stay put, and a Flickable
        // inside a Flickable fights over every wheel event.
        Loader {
            id: commandsLoader

            active: root.page === "commands"

            anchors.left: sidebar.right
            anchors.leftMargin: Appearance.lg
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            sourceComponent: SettingsCommands { panel: root }
        }

        // --- content ------------------------------------------------------
        Flickable {
            id: scroll

            visible: root.page !== "commands"

            anchors.left: sidebar.right
            anchors.leftMargin: Appearance.lg
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

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
                    // Built by commandsLoader above, so nothing here.
                    case "commands": return null;
                    case "desktop": return desktopPage;
                    case "audio": return audioPage;
                    case "network": return networkPage;
                    case "shell": return shellPage;
                    case "windows": return windowsPage;
                    case "components": return componentsPage;
                    case "visualizer": return visualizerPage;
                    case "performance": return performancePage;
                    case "system": return systemPage;
                    case "about": return aboutPage;
                    default: return appearancePage;
                    }
                }

                // Fade between pages. No slide: the sidebar already says where
                // you are, and a horizontal slide inside a window that is not
                // moving reads as a glitch.
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

        Component { id: appearancePage;  SettingsAppearance {} }
        Component { id: desktopPage;     SettingsDesktop {} }
        Component { id: audioPage;       SettingsAudio {} }
        Component { id: networkPage;     SettingsNetwork {} }
        Component { id: shellPage;       SettingsShell {} }
        Component { id: windowsPage;     SettingsWindows {} }
        Component { id: componentsPage;  SettingsComponents {} }
        Component { id: visualizerPage;  SettingsVisualizer {} }
        Component { id: performancePage; SettingsPerformance {} }
        Component { id: systemPage;      SettingsSystem {} }
        Component { id: aboutPage;       SettingsAbout {} }

        // =================================================================
        // Commands overlays
        //
        // Siblings of the sidebar rather than children of the Commands view,
        // so their dim covers the WHOLE card -- a confirmation sheet that
        // leaves the navigation clickable is not a confirmation. The negative
        // margin cancels the padding ui/Panel.qml puts around this content, so
        // they reach the card's own edges.
        //
        // They cost nothing on the other pages: their command is null, so each
        // sits at opacity 0 with `visible: false`.
        // =================================================================

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
                // the window is left with no keyboard target and Escape stops
                // working. (Harmless when execute() closed the window.)
                if (commandsLoader.item) commandsLoader.item.focusSearch();
            }

            onCancelled: {
                root.confirmCommand = null;
                if (commandsLoader.item) commandsLoader.item.focusSearch();
            }
        }

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
                if (commandsLoader.item) commandsLoader.item.focusSearch();
            }

            onCancelled: {
                root.promptCommand = null;
                if (commandsLoader.item) commandsLoader.item.focusSearch();
            }
        }

        CmdOutput {
            id: output

            anchors.fill: parent
            anchors.margins: -Appearance.padding

            run: root.outputRun

            onClosed: {
                root.outputRun = null;
                if (commandsLoader.item) commandsLoader.item.focusSearch();
            }
        }
    }
}
