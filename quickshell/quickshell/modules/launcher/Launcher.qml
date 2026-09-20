import QtQuick
import Quickshell
import qs

// =============================================================================
// Launcher.  SUPER + SPACE
// =============================================================================
// Replaces nwg-drawer (a full-screen GTK grid, launched on demand from waybar's
// 󰣇 button). wofi stays exactly where it is on SUPER + S -- it is the fallback
// for when Quickshell is not running, and it is what SUPER + V pipes cliphist
// through. Nothing here removes it.
//
// MATCHING
//   Three tiers, in order, so the thing you meant is first:
//     1. name starts with the query          ("fi" -> Firefox before Nautilus)
//     2. name contains the query
//     3. keywords / generic name / exec contain it  ("browser" -> Chrome)
//   Within a tier, entries you have launched recently sort first.
//
//   Deliberately NOT fuzzy subsequence matching. Fuzzy matching is
//   impressive in a demo and infuriating in practice: it surfaces a dozen
//   plausible-looking wrong answers for a three-letter query, and for a
//   launcher you use a hundred times a day, predictable beats clever.
//
// COST
//   DesktopEntries is Quickshell's own cache of the system .desktop files --
//   parsed once, watched for changes. The filtered list below is a binding, so
//   it re-runs on keystroke and on nothing else. Nothing is built until the
//   panel opens, and everything is torn down after it closes.
// =============================================================================

Panel {
    id: root

    name: "launcher"
    placement: "center"
    panelWidth: Settings.launcher.width
    scrim: true

    property string query: ""
    property int selected: 0

    // Recently launched, most recent first. Persisted so the ordering survives
    // a restart -- a launcher that forgets what you use is barely better than
    // an alphabetical list.
    property var recent: Settings.launcher.recent || []

    onOpened: {
        root.query = "";
        root.selected = 0;
    }

    function remember(id) {
        const next = [id];
        for (const entry of root.recent) {
            if (entry !== id) next.push(entry);
            if (next.length >= 20) break;
        }
        root.recent = next;
        Settings.launcher.recent = next;
    }

    function launch(entry) {
        if (!entry) return;
        root.hide();
        root.remember(entry.id);
        // execute() runs the entry the way the desktop file asks -- honouring
        // Terminal=true, the working directory and the field codes. Building a
        // command line by hand from execString gets %U and %F wrong.
        entry.execute();
    }

    readonly property var results: {
        const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const q = root.query.trim().toLowerCase();

        if (q === "") {
            // No query: most recently used first, then everything else
            // alphabetically. That makes an empty launcher immediately useful
            // rather than an alphabetical wall.
            const byId = {};
            for (const e of all) byId[e.id] = e;
            const out = [];
            for (const id of root.recent) {
                if (byId[id]) { out.push(byId[id]); delete byId[id]; }
            }
            const rest = Object.keys(byId).map(k => byId[k]);
            rest.sort((a, b) => a.name.localeCompare(b.name));
            return out.concat(rest).slice(0, Settings.launcher.maxResults);
        }

        const starts = [], contains = [], loose = [];
        for (const e of all) {
            const name = (e.name || "").toLowerCase();
            if (name.startsWith(q)) { starts.push(e); continue; }
            if (name.indexOf(q) !== -1) { contains.push(e); continue; }
            const extra = ((e.genericName || "") + " " + (e.comment || "") + " "
                        + (e.keywords || []).join(" ") + " " + (e.execString || "")).toLowerCase();
            if (extra.indexOf(q) !== -1) loose.push(e);
        }

        const rank = (e) => {
            const i = root.recent.indexOf(e.id);
            return i === -1 ? 999 : i;
        };
        const sort = (list) => list.sort((a, b) => {
            const d = rank(a) - rank(b);
            return d !== 0 ? d : a.name.localeCompare(b.name);
        });

        return sort(starts).concat(sort(contains), sort(loose))
            .slice(0, Settings.launcher.maxResults);
    }

    // Keep the selection inside the list as it shrinks under the cursor.
    onResultsChanged: if (root.selected >= root.results.length) root.selected = 0

    content: Column {
        spacing: Appearance.md

        // --- search ------------------------------------------------------
        Rectangle {
            width: parent.width
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
                anchors.right: parent.right
                anchors.rightMargin: Appearance.md
                anchors.verticalCenter: parent.verticalCenter

                text: root.query
                onTextChanged: { root.query = text; root.selected = 0; }

                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontTitle
                selectByMouse: true
                selectionColor: Theme.wash(Theme.accent, 0.35)
                focus: true

                // All navigation lives here, so the keyboard works from the
                // moment the panel opens without a click.
                Keys.onDownPressed: root.selected = Math.min(root.results.length - 1, root.selected + 1)
                Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
                Keys.onReturnPressed: root.launch(root.results[root.selected])
                Keys.onEnterPressed: root.launch(root.results[root.selected])
                Keys.onEscapePressed: root.hide()
                Keys.onTabPressed: root.selected = (root.selected + 1) % Math.max(1, root.results.length)

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === ""
                    text: "Search applications…"
                    color: Theme.muted
                    font: input.font
                }
            }
        }

        // --- results -------------------------------------------------------
        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: root.results

                Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 52
                    radius: Appearance.radiusInner

                    readonly property bool active: index === root.selected

                    color: active ? Theme.wash(Theme.accent, 0.18)
                         : rowMouse.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }

                    // Accent bar on the selection, matching the Settings
                    // sidebar -- the same idea used the same way everywhere.
                    Rectangle {
                        width: 3
                        height: parent.height * 0.5
                        radius: 2
                        color: Theme.accent
                        opacity: parent.active ? 1 : 0
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on opacity {
                            enabled: !Appearance.motionless
                            NumberAnimation { duration: Appearance.durationFast }
                        }
                    }

                    Image {
                        id: appIcon

                        width: 30
                        height: 30
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.md
                        anchors.verticalCenter: parent.verticalCenter
                        // iconPath resolves the desktop file's icon name
                        // through the current icon theme. The second argument
                        // is a fallback for entries whose icon is missing.
                        source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                        sourceSize.width: 60
                        sourceSize.height: 60
                        asynchronous: true
                        smooth: true
                    }

                    Column {
                        anchors.left: appIcon.right
                        anchors.leftMargin: Appearance.md
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.md
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: modelData.name
                            color: Theme.text
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontBody
                            font.weight: parent.parent.active ? Appearance.weightMedium : Appearance.weightNormal
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: modelData.genericName || modelData.comment || ""
                            color: Theme.muted
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontCaption
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = index
                        onClicked: root.launch(modelData)
                    }
                }
            }

            // Empty state rather than a silently collapsed panel.
            Item {
                width: parent.width
                height: root.results.length === 0 ? 52 : 0
                visible: root.results.length === 0

                Text {
                    anchors.centerIn: parent
                    text: "Nothing matches “" + root.query + "”"
                    color: Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontBody
                }
            }
        }

        // --- hint -----------------------------------------------------------
        Text {
            width: parent.width
            text: "↑↓ navigate   ⏎ launch   esc close"
            color: Theme.muted
            opacity: 0.6
            font.family: Appearance.font
            font.pixelSize: Appearance.fontCaption
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
