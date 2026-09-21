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
// AUTO-HIDE, AND WHY THE INPUT MASK IS THE WHOLE POINT
//   A layer surface takes pointer input over its ENTIRE rectangle unless a
//   `mask: Region {...}` narrows it, and that is true whether or not the
//   surface is painting anything. Opacity is not input. A dock faded to
//   opacity 0 with a full-surface mask is an invisible hole in your desktop
//   that swallows clicks, which is the worst of every option: you cannot see
//   it, and you cannot click through it.
//
//   So the mask here is the load-bearing part, not the animation:
//
//     hidden    a 3 px strip along the very bottom edge (Appearance.edgeTrigger)
//               and NOTHING else. Everything above it belongs to your windows.
//     revealed  the dock, plus a small halo around it so the pointer does not
//               fall into a dead gap on the way there.
//     menu open the whole surface, so a click anywhere dismisses the menu
//               instead of falling through into the window behind it.
//
//   The dock slides fully BELOW the surface's bottom edge when hidden rather
//   than merely fading. That is not decoration either: Region tracks its item
//   via mapToScene (see src/core/region.cpp upstream), so moving the dock off
//   the surface is what actually removes it from the input region. The
//   compositor clips the input region to the surface, so an off-surface dock
//   contributes nothing.
//
//   TWO BUGS LIVED HERE. Both presented as "the dock eats clicks on my windows".
//
//   1. The slide never happened. The dock was positioned with
//        anchors.bottom: parent.bottom
//      and then animated with
//        y: panel.revealed ? 0 : height + Appearance.screenMargin
//      An anchor OWNS the coordinate it anchors. QML silently discards a
//      competing binding on `y` -- no warning, no binding-loop message, the
//      Behavior never fires. Measured: `y` sat at the anchored value in all
//      three states. The dock therefore never moved, `Region { item: dockBar }`
//      never moved either, and the only thing `revealed` actually changed was
//      opacity. Result: an auto-hiding dock that was invisible and still took
//      every click over its full rectangle, forever.
//
//      The fix is to animate the anchor's own margin instead, via the `slide`
//      property below. That drives real x/y changes, which is what Region
//      connects to (xChanged/yChanged/widthChanged/heightChanged -- and NOTHING
//      else, which is why a `transform: Translate` would be a trap here: it
//      would move the pixels and leave the input mask behind).
//
//   2. The reveal latched on. The strip's HoverHandler read
//        onHoveredChanged: if (hovered) panel.hovered = true
//      which sets true on entry and never sets false on exit. Brushing the
//      bottom edge on the way somewhere else pinned the dock up permanently,
//      at which point (1) made it a permanent click sink. Hover is now tracked
//      as two plain booleans OR'd together, with timers deciding the rest.
//
//   DELAYS. Appearance.hoverRevealDelay before appearing, so a pointer merely
//   crossing the edge does not summon the dock; the much longer
//   Appearance.hoverHideDelay before leaving, so the dock does not vanish
//   mid-reach while the pointer crosses the gap between the edge and the dock.
//   The menu pins it up regardless -- see `revealed`.
//
// WHY IT FLOATS RATHER THAN RESERVING SPACE (AND HOW TO CHANGE YOUR MIND)
//   Default is ExclusionMode.Ignore: a dock that reserves an exclusive zone
//   re-tiles every window on the workspace, and on a tiling compositor having
//   the layout shift under you is an unpleasant surprise.
//
//   The honest trade-off is that "float over windows" and "never block a
//   click" cannot both be absolute -- something has to give, and auto-hide is
//   the version where what gives is a 3 px strip at the screen edge instead of
//   either a permanent band of screen or a permanently blocked rectangle.
//
//   If you would rather just spend the pixels: set dock.visibility to
//   "reserve" in settings.json (or Settings > Shell > Dock > Reserve). Windows
//   then tile above the dock and nothing is ever underneath it. That is the
//   boring, zero-jank answer and there is nothing wrong with it.
//
//   NOT IMPLEMENTED, deliberately: toggling the exclusive zone on hover, so
//   windows "squish" only while you reach for the dock. It re-tiles every
//   window on the workspace on a pointer movement, fights Hyprland's own
//   window animations, and -- fatally -- the windows snap back the instant the
//   dock hides, so the bottom of a window is still unreachable by the time your
//   click lands. It trades a static problem for a moving one.
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

    // "always" | "auto" | "never" | "reserve" -- see Settings.qml for what each
    // one costs you. Derived flags rather than string comparisons scattered
    // through the surface below, so a typo'd mode fails one way instead of
    // three inconsistent ways.
    readonly property string visibility: Settings.dock.visibility

    // Slides away on its own and reveals on edge hover.
    readonly property bool autoHide: root.visibility === "auto"

    // Reserves a permanent exclusive zone so nothing ever tiles underneath it.
    readonly property bool reserveSpace: root.visibility === "reserve"

    // Never drawn and never takes input.
    readonly property bool suppressed: root.visibility === "never"

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
            // ~/.config/hypr/rules.lua matches this exact string ("^qs-dock$")
            // to enable blur behind the dock. Renaming it silently drops the
            // blur -- that file turns blur OFF for everything by default and
            // re-enables it per namespace by name.
            WlrLayershell.namespace: "qs-dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // --- exclusive zone -------------------------------------------
            //
            // These two are set through `Binding { when: }` rather than as two
            // ordinary ternary bindings, and that is not style. Upstream,
            // setExclusiveZone() unconditionally does
            //     bExclusionMode = ExclusionMode::Normal;
            // (src/wayland/wlr_layershell/wlr_layershell.hpp) -- writing a zone
            // AT ALL, even a zero one, flips the mode. Two plain bindings on
            // the same dependency would therefore race: whichever re-evaluated
            // last would win, and the losing frame would have the floating dock
            // quietly reserving space and re-tiling the workspace.
            //
            // With `when`, exactly one of them is ever live, so there is no
            // ordering to get wrong.

            // Floating (always / auto / never): reserve nothing, and ignore
            // other layers' zones so waybar's does not shove the dock around.
            Binding {
                target: panel
                property: "exclusionMode"
                value: ExclusionMode.Ignore
                when: !root.reserveSpace
                restoreMode: Binding.RestoreNone
            }

            // "reserve": hold back exactly the dock and its margins, so
            // Hyprland tiles windows above it and nothing is ever underneath.
            //
            // Deliberately NOT panel.implicitHeight: that grows by 360 px while
            // the context menu is open, and reserving THAT would re-tile every
            // window on the workspace every time you right-clicked a tile. The
            // zone must be a constant the menu cannot move. The leftover ~20 px
            // of surface above the zone is shadow, which is allowed to feather
            // over the window above it.
            Binding {
                target: panel
                property: "exclusiveZone"
                value: dockBar.height + Appearance.screenMargin * 2
                when: root.reserveSpace
                restoreMode: Binding.RestoreNone
            }

            // --- reveal state ---------------------------------------------
            //
            // Pointer presence is tracked as two independent booleans rather
            // than one shared flag that every handler writes. The old code had
            // the strip handler writing `true` on entry and nothing on exit,
            // which latched the dock up forever after an accidental brush of
            // the screen edge -- see bug (2) in the header. Two booleans OR'd
            // together cannot latch: each handler only ever reports its own
            // item, and neither can leave the other's state stale.
            //
            // Both are needed. The zone catches the approach from the screen
            // edge; dockHover catches the pointer once it is on the dock
            // itself, which matters because a DockItem's MouseArea sits on top
            // and the two overlap. Belt and braces, cheaply.
            property bool pointerOnZone: false
            property bool pointerOnDock: false
            readonly property bool pointerNear: panel.pointerOnZone || panel.pointerOnDock

            // What the timers actually drive. Only meaningful in "auto".
            property bool autoRevealed: false

            // Reveal state is PER MONITOR -- see the note at the top of the
            // file. This is that per-surface state.
            readonly property bool revealed: {
                if (!root.enabled) return false;
                if (root.suppressed) return false;

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

                // "auto" is the only mode the pointer has any say in.
                // "always" and "reserve" are both permanently up.
                if (root.autoHide) return panel.autoRevealed;
                return true;
            }

            // Single place that decides which timer should be running, called
            // from every edge that can change the answer. Having one function
            // rather than logic spread across three handlers is what stops the
            // two timers from ever being armed at the same time.
            function retime() {
                if (!root.autoHide) {
                    revealTimer.stop();
                    hideTimer.stop();
                    return;
                }

                if (panel.pointerNear) {
                    // Committing to the dock: cancel any pending hide outright,
                    // so crossing back onto it mid-fade keeps it up.
                    hideTimer.stop();
                    if (!panel.autoRevealed) revealTimer.restart();
                } else {
                    // Left before the reveal delay elapsed: it was a pass-by,
                    // not a reach. Drop it rather than summoning the dock behind
                    // the pointer.
                    revealTimer.stop();
                    if (panel.autoRevealed && !menu.open) hideTimer.restart();
                }
            }

            onPointerNearChanged: panel.retime()

            Timer {
                id: revealTimer

                interval: Appearance.hoverRevealDelay
                onTriggered: panel.autoRevealed = true
            }

            Timer {
                id: hideTimer

                interval: Appearance.hoverHideDelay
                // Re-check the menu: it can open during the delay, and a dock
                // that hid out from under its own open context menu is the
                // exact failure `revealed` guards against above.
                onTriggered: if (!menu.open) panel.autoRevealed = false
            }

            // Switching modes from the settings GUI must not leave a stale
            // reveal behind -- flipping "auto" -> "never" -> "auto" would
            // otherwise come back already revealed, with no pointer anywhere
            // near it and no hide armed to take it down again.
            Connections {
                target: root

                function onVisibilityChanged() {
                    panel.autoRevealed = false;
                    panel.retime();
                }
            }

            // THE INPUT MASK. This, not opacity, is what decides whether your
            // windows are clickable. See the header.
            //
            // `null` means "no mask", i.e. the whole surface takes input -- so
            // while the menu is open a click anywhere dismisses it rather than
            // falling through into the window behind it, which is what every
            // context menu on every desktop does.
            //
            // Otherwise the mask is the union of two items, and it is correct
            // only because both of them physically move/resize to nothing when
            // they should not be taking input:
            //
            //   dockBar    slides entirely below the surface's bottom edge when
            //              hidden. The compositor clips the input region to the
            //              surface, so off-surface contributes nothing.
            //   hoverZone  collapses to height 0 outside "auto".
            //
            // Both have to be geometric. Region reads ONLY the item's x/y/
            // width/height (region.cpp: build() calls mapToScene, and setItem()
            // connects to exactly those four signals). It does not look at
            // `visible`, and it does not look at `opacity`. The previous strip
            // used `visible: root.visibility === "auto"` and so kept eating a
            // 2 px line across the bottom of the screen even in "never" mode,
            // with the dock not drawn at all.
            mask: menu.open ? null : dockRegion

            Region {
                id: dockRegion

                item: dockBar
                Region { item: hoverZone }
            }

            MouseArea {
                anchors.fill: parent
                enabled: menu.open
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: menu.close()
                z: 10
            }

            // --- hover zone ---------------------------------------------
            //
            // The only part of this surface that takes input while the dock is
            // away, so its size is a direct tax on your windows. It changes
            // shape with the state rather than being one fixed strip:
            //
            //   hidden    full width, Appearance.edgeTrigger (3 px) tall, along
            //             the very bottom edge. Full width because summoning
            //             the dock has to work by slamming the pointer down
            //             anywhere, not just dead centre; 3 px tall because
            //             this is exactly the band of your windows that stops
            //             being clickable, and the pointer's last row is always
            //             inside it.
            //
            //   revealed  a halo around the dock: its width plus a grip each
            //             side, and tall enough to take in the gap between the
            //             dock's lower rim and the screen edge. That gap is
            //             Appearance.screenMargin of dead space that belongs to
            //             neither the strip nor the dock, and without this the
            //             pointer coming up off the edge towards a tile passes
            //             through a hole where nothing is hovered. The generous
            //             hide delay would usually cover the crossing, but a
            //             pointer that simply STOPS in the gap would watch the
            //             dock slide away from under it. Covering the approach
            //             corridor is cheaper than lengthening the delay.
            //
            //             Deliberately not full width: while revealed this area
            //             is unclickable, so it stays a halo around the dock and
            //             leaves the bottom corners of the screen alone.
            //
            //   otherwise height 0, which makes its Region empty. "always" and
            //             "reserve" have no hover behaviour to detect, and
            //             "never" must take no input at all.
            Item {
                id: hoverZone

                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter

                width: panel.revealed ? dockBar.width + Appearance.xl * 2
                                      : parent.width

                height: {
                    if (!root.autoHide) return 0;
                    return panel.revealed
                        ? dockBar.height + Appearance.screenMargin * 2
                        : Appearance.edgeTrigger;
                }

                HoverHandler {
                    id: zoneHover

                    // Reports both directions, unlike the strip handler this
                    // replaces. That one-sided `if (hovered)` is what latched
                    // the dock up permanently -- see bug (2) in the header.
                    onHoveredChanged: panel.pointerOnZone = hovered
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

                // Hand the reveal back to the pointer on both edges.
                //
                // Closing: if the cursor has wandered off the dock while the
                // menu was up, resync from the live handler and let the hide
                // delay run, rather than staying up because the menu once was.
                //
                // Opening matters too: the mask goes full-surface, which moves
                // the pointer out of dockBar as far as the HoverHandler is
                // concerned, so the booleans must be resynced or the dock would
                // be left believing the pointer is somewhere it is not.
                onOpenChanged: {
                    panel.pointerOnDock = dockHover.hovered;
                    panel.pointerOnZone = zoneHover.hovered;
                    panel.retime();
                }
            }

            // --- the dock -----------------------------------------------
            Card {
                id: dockBar

                elevation: 2
                radius: Appearance.radius + 6

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: dockBar.slide

                width: row.implicitWidth + Appearance.md * 2
                height: Settings.dock.iconSize + Appearance.md * 2

                // THE SLIDE. Slide out of view rather than disappearing: a dock
                // that vanishes has no affordance for getting it back.
                //
                // This animates the ANCHOR'S MARGIN, not `y`. It used to be
                //     anchors.bottom: parent.bottom
                //     y: panel.revealed ? 0 : height + Appearance.screenMargin
                // which does nothing whatsoever -- an anchor owns the
                // coordinate it anchors, and QML drops the competing `y`
                // binding without a word. No warning, no binding loop, the
                // Behavior never runs, `y` just sits at the anchored value in
                // every state. The dock never moved; only its opacity did; and
                // because Region follows the ITEM, the input mask never moved
                // either. That is bug (1) in the header, and it is why a dock
                // set to "auto" was an invisible click sink.
                //
                // Margins are fair game because the anchor computes
                //     y = parent.height - height - bottomMargin
                // so driving the margin drives real x/y changes -- which is
                // also precisely what Region listens to.
                //
                // The hidden value must push the dock ENTIRELY below the
                // surface, not merely down a bit: at bottomMargin
                // -(height + screenMargin) the dock's top edge lands at
                // parent.height + screenMargin, so every pixel of it -- and
                // therefore every pixel of its input region -- is outside the
                // surface for the compositor to clip away. A smaller offset
                // would leave a sliver of the dock still taking clicks.
                property real slide: panel.revealed
                    ? Appearance.screenMargin
                    : -(dockBar.height + Appearance.screenMargin)

                opacity: panel.revealed ? 1 : 0

                Behavior on slide {
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
                    // not slide away mid-click. Reports both directions; the
                    // menu case is handled by `revealed` and by retime()'s
                    // menu guard rather than by dropping the update here, so
                    // this boolean is never left stale.
                    onHoveredChanged: panel.pointerOnDock = hovered
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
