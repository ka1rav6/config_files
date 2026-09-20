import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// Emoji picker.  SUPER + F2
// =============================================================================
// A WhatsApp-shaped picker: a search box, a grid, a category strip along the
// bottom, and a Recent row that fills itself in as you use it plus favourites
// you pin yourself.
//
// Replaces a wofi --dmenu list, which was a single column of "😀  Grinning
// Face" lines you could not really search and could not browse at all.
//
// THE CATALOGUE
//   modules/emoji/emoji.json, generated from Python's unicodedata (see the
//   generator note in keys.md). 1376 emoji across 8 groups, each carrying its
//   name and a set of search words. Loaded once via FileView, lazily -- the
//   panel is a LazyLoader, so an unopened picker parses nothing.
//
// SEARCH
//   Matches the name and the keyword list, scoring a prefix hit above a
//   substring hit so typing "hear" puts "Heart" before "Broken Heart". Results
//   replace the grid; the category strip greys out because it no longer
//   applies.
//
// FAVOURITES AND RECENTS
//   Both live in Settings (emoji.favourites, emoji.recent) so they persist in
//   settings.json like everything else rather than in a private dotfile.
//   Right-click any emoji to pin or unpin it.
// =============================================================================

Panel {
    id: root

    name: "emoji"
    placement: "center"
    panelWidth: 460
    panelHeight: 520
    scrim: true

    // --- catalogue -------------------------------------------------------
    FileView {
        id: catalogue

        path: Quickshell.env("HOME") + "/.config/quickshell/modules/emoji/emoji.json"
        blockLoading: true
        printErrors: true
    }

    readonly property var groups: {
        const text = catalogue.text();
        if (!text) return [];
        try {
            return JSON.parse(text).groups || [];
        } catch (e) {
            console.warn("[emoji] catalogue is not valid JSON:", e);
            return [];
        }
    }

    property string query: ""
    property int groupIndex: 0

    onOpened: {
        root.query = "";
        root.groupIndex = 0;
    }

    // --- favourites and recents -------------------------------------------

    function isFavourite(ch) {
        return (Settings.emoji.favourites || []).indexOf(ch) !== -1;
    }

    // Rewrites the whole list rather than splicing: JsonAdapter only notices a
    // list changing by identity, so an in-place edit never reaches
    // settings.json.
    function toggleFavourite(ch) {
        const list = (Settings.emoji.favourites || []).slice();
        const i = list.indexOf(ch);
        if (i === -1) list.unshift(ch);
        else list.splice(i, 1);
        Settings.emoji.favourites = list;
    }

    function remember(ch) {
        const list = (Settings.emoji.recent || []).slice();
        const i = list.indexOf(ch);
        if (i !== -1) list.splice(i, 1);
        list.unshift(ch);
        // A "recent" row longer than one screenful is just a second catalogue.
        Settings.emoji.recent = list.slice(0, 24);
    }

    // --- picking -----------------------------------------------------------

    function lookup(ch) {
        for (const g of root.groups)
            for (const item of g.items)
                if (item.c === ch) return item;
        return { c: ch, n: "", k: "" };
    }

    function pick(ch) {
        copyProc.emoji = ch;
        copyProc.running = true;
        root.remember(ch);
        root.hide();
    }

    // -----------------------------------------------------------------
    // Copy to the clipboard. That is all it does.
    //
    // An earlier version tried to PASTE as well -- capture the focused window,
    // then have Hyprland deliver Ctrl+V to it with hl.dsp.send_shortcut once
    // the picker had closed. The mechanism itself works (verified against a
    // real window: the emoji arrived as genuine key input), but it did not
    // work in practice here, so it is gone rather than left in half-working.
    // Pick, then paste yourself.
    //
    // WHY wl-copy AND NOT Qt's CLIPBOARD
    //   A Wayland clipboard offer belongs to a surface, and this panel is
    //   being destroyed the moment you pick. wl-copy forks a tiny process that
    //   owns the selection until something else takes it, which is what a
    //   clipboard manager expects -- and it means the emoji lands in cliphist
    //   too, so SUPER + V finds it again later.
    // -----------------------------------------------------------------
    Process {
        id: copyProc

        property string emoji: ""

        running: false
        command: ["bash", "-c", "printf '%s' \"$1\" | wl-copy", "qs-emoji", copyProc.emoji]
    }

    // --- the results shown in the grid -------------------------------------

    readonly property var results: {
        const q = root.query.trim().toLowerCase();

        if (q === "") {
            const g = root.groups[root.groupIndex];
            return g ? g.items : [];
        }

        const scored = [];
        for (const g of root.groups) {
            for (const item of g.items) {
                const name = item.n.toLowerCase();
                const keys = item.k;

                let score = -1;
                if (name.startsWith(q)) score = 0;
                else if (keys.startsWith(q) || keys.indexOf(" " + q) !== -1) score = 1;
                else if (name.indexOf(q) !== -1) score = 2;
                else if (keys.indexOf(q) !== -1) score = 3;

                if (score >= 0) scored.push({ item: item, score: score });
            }
        }
        scored.sort((a, b) => a.score - b.score);
        return scored.slice(0, 180).map(s => s.item);
    }

    content: EmojiBody {
        picker: root
    }
}
