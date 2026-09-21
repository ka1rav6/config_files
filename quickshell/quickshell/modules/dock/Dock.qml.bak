import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// =============================================================================
// Dock — pinned and running applications.
// =============================================================================
// Replaces nwg-dock-hyprland, which was configured in
// ~/.config/hypr/scripts/start-dock.sh and NEVER ACTUALLY STARTED -- nothing
// called that script, so the dock has been dead code for some time.
//
// WHAT IT SHOWS
//   Pinned entries first (Settings.dock.pinned, desktop-file ids), then any
//   running application that is not already pinned. A pinned app that is
//   running gets a dot under it rather than a second icon, so the dock does not
//   grow while you work.
//
// AUTO-HIDE
//   "auto" leaves a one-pixel reveal strip at the screen edge and slides the
//   dock up on hover. The strip is a separate, permanently-visible surface so
//   the hover can be detected at all -- a hidden dock cannot notice a pointer.
//   The strip takes no exclusive zone and is click-through except for hover.
//
// WHY IT NEVER RESERVES SPACE
//   ExclusionMode.Ignore, always. A dock that reserves an exclusive zone
//   re-tiles every window on the workspace the moment it appears, which on a
//   tiling compositor is an unpleasant surprise. It floats over instead.
//
// COST
//   The window list comes from the Hyprland toplevel model, which Hypr.qml
//   re-fetches on window open/close/move/retitle -- event-driven, not a poll,
//   but NOT free the way monitors and workspaces are. See the `toplevels` note
//   in services/Hypr.qml: lastIpcObject is empty until something asks for it,
//   and an earlier version of this comment claimed otherwise, which is exactly
//   why the dock read "No applications" with four windows open.
//   Icons resolve through the .desktop cache. Hover magnification is a scale
//   transform, so it is a GPU property animation and costs nothing measurable.
// =============================================================================

Scope {
    id: root

    readonly property bool enabled: Settings.features.dock

    // "always" | "auto" | "never"
    readonly property string visibility: Settings.dock.visibility

    // Reveal state is PER MONITOR, not global. A single shared flag made the
    // dock slide up on both screens whenever the pointer touched either one,
    // which is wrong on its face and actively annoying on the screen you are
    // not looking at. Each surface owns its own `revealed` below.

    // --- model ------------------------------------------------------------

    // Running applications, one entry per window class rather than per window:
    // six browser windows should be one dock icon with a dot, not six icons.
    // Window classes that never appear in the dock, as substrings.
    // Settings.dock.exclude is the user-facing list; this is just the guard.
    function excluded(cls) {
        if (!cls) return false;
        for (const fragment of (Settings.dock.exclude || [])) {
            if (fragment && cls.indexOf(fragment) !== -1) return true;
        }
        return false;
    }

    // DesktopEntries populates ASYNCHRONOUSLY, and only starting from the
    // first access -- it reads as empty for roughly a second after startup,
    // then fills with ~90 entries. byId() and heuristicLookup() are plain
    // invokable functions, so a binding that only calls them captures NO
    // dependency on the entry list and is never re-evaluated when it arrives.
    //
    // That is a separate bug from the toplevel one documented in Hypr.qml, and
    // it has the same symptom: `pinned` evaluated once at startup against an
    // empty list, got null for all five ids, and stayed empty forever. It was
    // masked only by `pinned` also depending on `running` -- so it would have
    // looked fixed the moment toplevels worked, and broken again on any
    // startup where no window happened to open.
    //
    // Referencing this property inside those bindings is what gives them the
    // missing dependency. Do not "simplify" it away.
    readonly property int entryCount: DesktopEntries.applications.values.length

    readonly property var running: {
        const seen = {};
        const out = [];

        root.entryCount;   // dependency; see above

        for (const toplevel of Hypr.toplevels.values) {
            const ipc = toplevel.lastIpcObject;
            if (!ipc || !ipc.class || ipc.class === "") continue;
            // Scratchpads live on special workspaces and are toggled with their
            // own keys; putting them in the dock would be a second, worse way
            // to reach something that already has a binding.
            if (ipc.workspace && ipc.workspace.id < 0) continue;

            // ...and stay excluded even when they are NOT parked, because a
            // scratchpad dragged onto a real workspace is still a scratchpad.
            // Matching on class rather than workspace is what makes WhatsApp
            // and YouTube Music behave the same wherever they happen to be.
                if (root.excluded(ipc.class)) continue;

            const cls = ipc.class;
            if (seen[cls]) {
                seen[cls].count++;
                continue;
            }
            const entry = {
                class: cls,
                title: ipc.title || cls,
                address: ipc.address,
                count: 1,
                // heuristicLookup matches a window class to a .desktop file,
                // which is what gives a running window its proper icon and
                // name. It handles the common mismatches (chrome-<id>-Profile,
                // reverse-DNS ids) that a literal lookup misses.
                entry: DesktopEntries.heuristicLookup(cls)
                    // Scratchpad Ghostty variants report their own classes
                    // (com.scratchpad.ghostty, com.yazi.ghostty) which match no
                    // desktop file; fall back to the real Ghostty entry so they
                    // at least get the right icon if they ever appear.
                    || DesktopEntries.heuristicLookup(cls.replace(/^com\.[a-z]+\./, ""))
            };
            seen[cls] = entry;
            out.push(entry);
        }
        return out;
    }

    // DesktopEntries ids do NOT carry the ".desktop" suffix -- byId("google-
    // chrome.desktop") returns null while byId("google-chrome") works. Pinned
    // lists written either way are accepted, because the suffix is what
    // everyone types and the silent null is very hard to debug from the UI.
    function lookup(id) {
        if (!id) return null;
        return DesktopEntries.byId(id)
            || DesktopEntries.byId(id.replace(/\.desktop$/, ""))
            || DesktopEntries.heuristicLookup(id.replace(/\.desktop$/, ""));
    }

    readonly property var pinned: {
        const out = [];

        root.entryCount;   // dependency; see the note on entryCount

        for (const id of (Settings.dock.pinned || [])) {
            const entry = root.lookup(id);
            if (!entry) continue;                    // uninstalled since pinning
            // Is it running? If so the same tile shows the indicator rather
            // than the app appearing twice.
            let live = null;
            for (const r of root.running) {
                if (r.entry && r.entry.id === id) { live = r; break; }
            }
            out.push({ entry: entry, live: live, pinned: true });
        }
        return out;
    }

    readonly property var unpinnedRunning: {
        const pinnedIds = {};
        for (const p of root.pinned) pinnedIds[p.entry.id] = true;
        return root.running
            .filter(r => !(r.entry && pinnedIds[r.entry.id]))
            .map(r => ({ entry: r.entry, live: r, pinned: false }));
    }

    readonly property var items: root.pinned.concat(root.unpinnedRunning)

    // --- actions -----------------------------------------------------------

    function activate(item) {
        if (item.live) {
            // Running: focus it rather than starting a second copy.
            Hypr.focusWindow(item.live.address);
        } else if (item.entry) {
            item.entry.execute();
        }
    }

    // --- pinning ------------------------------------------------------------
    //
    // Settings.dock.pinned is a plain list of desktop-entry ids and is the ONLY
    // state here -- pin order is list order, and a pinned app that is also
    // running is still one tile. Every function below rewrites the whole list
    // rather than mutating it, because JsonAdapter only notices a `var`
    // property changing by identity; an in-place splice would never reach
    // settings.json.

    function isPinned(id) {
        if (!id) return false;
        const list = Settings.dock.pinned || [];
        return list.indexOf(id) !== -1
            || list.indexOf(id + ".desktop") !== -1;
    }

    function pinnedIndex(id) {
        const list = Settings.dock.pinned || [];
        let i = list.indexOf(id);
        if (i === -1) i = list.indexOf(id + ".desktop");
        return i;
    }

    function pin(id) {
        if (!id || root.isPinned(id)) return;
        Settings.dock.pinned = (Settings.dock.pinned || []).concat([id]);
    }

    function unpin(id) {
        const i = root.pinnedIndex(id);
        if (i === -1) return;
        const next = (Settings.dock.pinned || []).slice();
        next.splice(i, 1);
        Settings.dock.pinned = next;
    }

    function togglePin(item) {
        if (!item || !item.entry) return;
        if (root.isPinned(item.entry.id)) root.unpin(item.entry.id);
        else root.pin(item.entry.id);
    }

    // Reorder by one place. Only meaningful for pinned tiles -- the running
    // ones are ordered by the compositor, not by us.
    function movePinned(id, delta) {
        const i = root.pinnedIndex(id);
        if (i === -1) return;
        const next = (Settings.dock.pinned || []).slice();
        const j = i + delta;
        if (j < 0 || j >= next.length) return;
        const tmp = next[i];
        next[i] = next[j];
        next[j] = tmp;
        Settings.dock.pinned = next;
    }

    function closeAll(item) {
        if (!item || !item.live) return;
        // toplevels carries every window of the app, not just the one the dock
        // happens to hold a handle to.
        const id = item.entry ? item.entry.id : "";
        for (const t of (Hypr.toplevels ? Hypr.toplevels.values : [])) {
            const entry = t.lastIpcObject
                ? DesktopEntries.heuristicLookup(t.lastIpcObject.class) : null;
            if (entry && entry.id === id) Hypr.closeWindow(t.address);
        }
    }

    // --- surfaces -----------------------------------------------------------
    // One per monitor, so the dock is on whichever screen you are looking at.

    Variants {
        model: root.enabled ? Quickshell.screens : []

        PanelWindow {
            id: panel

            required property var modelData

            screen: panel.modelData
            visible: true
            color: "transparent"

            anchors {
                bottom: Settings.dock.position === "bottom"
                left: Settings.dock.position !== "right"
                right: Settings.dock.position !== "left"
                top: false
            }

            // Tall enough for the dock plus its slide-out travel.
            //
            // AND MUCH TALLER WHILE THE CONTEXT MENU IS OPEN. The menu is
            // positioned ABOVE the dock bar, and a layer surface clips its
            // contents to its own bounds -- so with the normal ~80px height the
            // menu was laid out correctly and then drawn entirely off-surface.
            // That is why right-clicking a tile appeared to do nothing at all:
            // it was working, and invisible. Same class of mistake as the
            // zero-sized PanelWindow documented in ui/Panel.qml.
            implicitHeight: menu.open
                ? dockBar.height + Appearance.screenMargin * 2 + 20 + 360
                : dockBar.height + Appearance.screenMargin * 2 + 20

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "qs-dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // Never reserve space -- see the header.
            exclusionMode: ExclusionMode.Ignore

            // This surface's own reveal state. "always" and "never" do not
            // depend on the pointer; "auto" follows the hover of THIS monitor's
            // strip and dock only.
            property bool hovered: false
            readonly property bool revealed: {
                if (!root.enabled) return false;
                if (root.visibility === "never") return false;

                // The context menu pins the dock up for as long as it is open.
                //
                // Without this the dock slid away the moment you right-clicked
                // it: opening the menu drops the input mask to the whole
                // surface, so the pointer is no longer over dockBar, the
                // HoverHandler goes false, and an `auto` dock hides -- leaving
                // the menu floating over nothing. A menu that outlives the
                // thing it belongs to is the clearest possible sign the state
                // is wrong.
                if (menu.open) return true;

                if (root.visibility === "always") return true;
                return panel.hovered;
            }

            // Only the dock itself, the reveal strip, and (while it is up) the
            // context menu take the pointer. Everything else stays
            // click-through to the windows underneath.
            //
            // While the menu is open the WHOLE surface takes input instead, so
            // that clicking anywhere else dismisses it -- which is what every
            // context menu on every desktop does, and the only way to close one
            // without a stray click landing in the window behind it.
            mask: menu.open ? null : dockRegion

            Region {
                id: dockRegion

                item: dockBar
                // While hidden, the strip along the very bottom edge is what
                // notices the pointer and brings the dock back.
                Region { item: revealStrip }
            }

            MouseArea {
                anchors.fill: parent
                enabled: menu.open
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: menu.close()
                z: 10
            }

            // --- reveal strip -------------------------------------------
            Item {
                id: revealStrip

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                visible: root.visibility === "auto"

                HoverHandler {
                    onHoveredChanged: if (hovered) panel.hovered = true
                }
            }

            // --- context menu -------------------------------------------
            DockMenu {
                id: menu

                // Above the dismiss layer below, which is itself above the
                // dock -- so a click lands on the menu if it is on the menu,
                // and dismisses otherwise.
                z: 20
                dock: root
                dockBar: dockBar

                // When the menu closes, hand the reveal back to the pointer:
                // if the cursor is no longer on the dock, it should hide as
                // usual rather than staying up because the menu once was.
                onOpenChanged: if (!menu.open) panel.hovered = dockHover.hovered
            }

            // --- the dock -----------------------------------------------
            Card {
                id: dockBar

                elevation: 2
                radius: Appearance.radius + 6

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.screenMargin

                width: row.implicitWidth + Appearance.md * 2
                height: Settings.dock.iconSize + Appearance.md * 2

                // Slide out of view rather than disappearing: a dock that
                // vanishes has no affordance for getting it back.
                y: panel.revealed ? 0 : height + Appearance.screenMargin
                opacity: panel.revealed ? 1 : 0

                Behavior on y {
                    enabled: !Appearance.motionless
                    NumberAnimation {
                        duration: Appearance.durationSlow
                        easing.type: Appearance.easeEnter
                    }
                }

                Behavior on opacity {
                    enabled: !Appearance.motionless
                    NumberAnimation { duration: Appearance.durationNormal }
                }

                HoverHandler {
                    id: dockHover

                    // Keeps the dock up while the pointer is on it, so it does
                    // not slide away mid-click. Ignored while the menu is open
                    // -- see `revealed` above.
                    onHoveredChanged: if (!menu.open) panel.hovered = hovered
                }

                Row {
                    id: row

                    anchors.centerIn: parent
                    spacing: Settings.dock.spacing

                    Repeater {
                        model: root.items

                        DockItem {
                            id: tile

                            required property var modelData
                            required property int index

                            item: modelData
                            onActivated: root.activate(modelData)

                            // Right click opens the menu ABOVE this tile, so it
                            // points at the thing it acts on. Coordinates are
                            // mapped into the panel because the menu is a
                            // sibling of the dock, not of the tile -- a menu
                            // inside the Row would stretch the Row.
                            onContextRequested: {
                                const p = tile.mapToItem(menu.parent, tile.width / 2, 0);
                                menu.openFor(tile.modelData, tile.index, p.x);
                            }
                        }
                    }

                    // Nothing pinned and nothing running: say so rather than
                    // showing an empty pill.
                    Text {
                        visible: root.items.length === 0
                        text: "No applications"
                        color: Theme.muted
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
