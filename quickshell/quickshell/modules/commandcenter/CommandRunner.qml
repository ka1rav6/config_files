pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// =============================================================================
// CommandRunner — the execution layer, and the only one.
// =============================================================================
// Every command in the Command Center goes through run(). Nothing in the UI
// builds an argv, spawns a Process or calls execDetached. That buys the three
// things a pile of per-row Process objects cannot:
//
//   1. ONE OUTPUT TRAIL. Every run lands in `history` with its exit code,
//      stdout and stderr, so "Show output" and "the theme switch failed, why"
//      are the same mechanism rather than two.
//   2. SERIALISATION. One subprocess at a time. Two `theme-switch` runs
//      overlapping would fight over nine config files and leave the desktop
//      half-themed; two `just backup` runs would race on ~/dotfiles. These are
//      user-initiated commands at human speed, so a queue costs nothing and
//      removes a whole class of corruption.
//   3. ONE PLACE THAT KNOWS ABOUT DETACHING. See below -- getting this wrong
//      is how a "restart the shell" button leaves you with no shell.
//
// QUEUED VS DETACHED
//   A queued command runs as a child of this process, with its output
//   captured. That is right for almost everything.
//
//   `detach: true` commands run via execDetached, outside this process's
//   tree, and their output is NOT captured. Three reasons an entry needs it,
//   all real:
//
//     * it kills this process.  `just qs-reload` SIGTERMs the shell. As a
//       queued child it would be killed along with its parent before it got
//       as far as relaunching anything, and the desktop would come back with
//       no panels at all. There is also nothing left alive to read its output,
//       which is why detached and output-capturing are mutually exclusive.
//     * it outlives the command.  `just phone-browse` ends in
//       `setsid nautilus &`; `just qs-viz` runs for thirty seconds. Holding
//       the queue for either would block every other command behind a file
//       manager the user has already got.
//     * it is a GUI application.  pavucontrol, nm-connection-editor,
//       kdeconnect-settings. A shell restart must not take the user's open
//       audio mixer with it.
//
// FAILURE IS NEVER SILENT
//   onExited always records, and always emits `finished`. A non-zero exit
//   raises a toast that stays until dismissed and keeps the output; a zero
//   exit raises one that fades. The one thing that cannot happen is a command
//   that appears to have worked because nothing was shown.
//
//   Detached commands are the honest exception and the UI says so rather than
//   claiming success it cannot verify: execDetached returns no exit code, so
//   a detached run is reported as "started", not as "done".
//
// PERSISTENCE
//   Favourites, recents and the home layout live in Settings.commands, which
//   is ~/.config/quickshell/settings.json -- so they survive a shell restart
//   and a reboot, and they are editable by hand like everything else here.
//   History is deliberately NOT persisted: command output can contain the
//   contents of a config file or a device id, and none of it is worth keeping
//   past the session that produced it.
// =============================================================================

Singleton {
    id: root

    // --- what is happening right now -------------------------------------

    // The id of the queued command currently running, or "". Rows watch this
    // to show a pulse; CommandState.isBusy() folds it together with the
    // service-driven busy flags.
    property string runningId: ""

    readonly property bool running: root.runningId !== ""

    // [{ id, label, code, ok, stdout, stderr, at, detached }], newest first.
    property var history: []

    readonly property int historyLimit: 25

    // Emitted for every completed run, queued or detached.
    signal finished(string id, bool ok)

    // Raised for the toast. `detail` is "" unless there is output to show.
    signal notify(string id, string title, string message, string tone)

    // -----------------------------------------------------------------
    // Running
    // -----------------------------------------------------------------

    // cmd is a registry entry.
    //
    // `arg` means one of two things, decided by the entry rather than by the
    // caller: the chosen option for a `ui: select`, or the value supplied for
    // a command that declares `input` (a URL, some text, a list of file
    // paths). It is never a string spliced into a command line -- see the
    // argv note on appendArgs below.
    function run(cmd, arg) {
        if (!cmd) return false;

        root.remember(cmd.id);

        // Native: a toggle the shell already owns, a selector that routes
        // through an existing service, or a link to another surface. These are
        // synchronous and either work or throw, so there is no exit code to
        // wait for and no output to capture.
        if (typeof cmd.run === "function") {
            try {
                cmd.run(arg);
            } catch (e) {
                root.record(cmd, 1, "", String(e), false);
                root.notify(cmd.id, cmd.name, String(e), "bad");
                root.finished(cmd.id, false);
                return false;
            }
            // Toggles and links are their own feedback -- the switch moves,
            // the panel opens -- so they get no toast. Selectors and one-shot
            // native actions do, because `theme catppuccin` takes seconds and
            // silence would read as nothing having happened.
            if (cmd.ui === "select")
                root.notify(cmd.id, cmd.name, "Applying " + (arg !== undefined ? arg : "") + "…", "idle");
            else if (cmd.ui === "action")
                root.notify(cmd.id, cmd.name, "Done", "good");
            root.finished(cmd.id, true);
            return true;
        }

        if (!cmd.exec) {
            console.warn("[commands]", cmd.id, "has neither exec nor run");
            return false;
        }

        if (cmd.detach === true) {
            // No exit code and no output: report it as started, which is all
            // that is actually known.
            Quickshell.execDetached({ command: root.appendArgs(cmd, arg) });
            root.record(cmd, 0, "", "", true);
            root.notify(cmd.id, cmd.name, "Started", "idle");
            root.finished(cmd.id, true);
            return true;
        }

        root.enqueue(cmd, arg);
        return true;
    }

    // Build the final argv: the registry's fixed command, plus whatever the
    // user supplied, as SEPARATE ELEMENTS.
    //
    // This is the whole safety story for the input commands and it is worth
    // being explicit about. Quickshell's Process takes an argv array and
    // execs it directly -- there is no shell anywhere on this path. So a URL
    // containing `&&`, a message containing a quote, a filename containing a
    // space or a newline are all just bytes in one argument. Nothing is
    // parsed, nothing is split, nothing is expanded. The way this WOULD be
    // dangerous is `["sh", "-c", "just phone-open " + url]`, which is exactly
    // why no entry in the registry is shaped like that.
    function appendArgs(cmd, arg) {
        if (arg === undefined || arg === null || arg === "") return cmd.exec;
        if (Array.isArray(arg)) return cmd.exec.concat(arg.map(String));
        return cmd.exec.concat([String(arg)]);
    }

    // -----------------------------------------------------------------
    // The queue
    //
    // One in flight, the rest waiting. A command already queued is not queued
    // twice -- double-clicking a row should not run `just backup` twice.
    // -----------------------------------------------------------------

    property var queue: []

    function enqueue(cmd, arg) {
        // A command already queued is not queued twice -- double-clicking a
        // row should not run `just backup` twice. Commands that take input are
        // exempt: sending two different files to the phone is two different
        // operations that happen to share an id.
        if (cmd.input === undefined) {
            for (const q of root.queue)
                if (q.cmd.id === cmd.id) return;
            if (root.runningId === cmd.id) return;
        }

        root.queue = root.queue.concat([{ cmd: cmd, arg: arg }]);
        root.pump();
    }

    function pump() {
        if (proc.running || root.queue.length === 0) return;

        const entry = root.queue[0];
        root.queue = root.queue.slice(1);

        root.runningId = entry.cmd.id;
        proc.current = entry.cmd;
        proc.outText = "";
        proc.errText = "";
        proc.command = root.appendArgs(entry.cmd, entry.arg);
        proc.running = true;
    }

    Process {
        id: proc

        running: false

        // The registry entry in flight. Held here rather than looked up on
        // exit, so a command cannot be mis-attributed if the registry is ever
        // rebuilt mid-run.
        property var current: null

        property string outText: ""
        property string errText: ""

        // SplitParser rather than StdioCollector: several of these -- the
        // portal check, the restore listing, qs-ipc -- are worth watching
        // arrive rather than appearing all at once at the end, and a line
        // parser also caps a runaway command's memory at the lines we keep.
        stdout: SplitParser {
            onRead: (line) => {
                if (proc.outText.length < 64000)
                    proc.outText += line + "\n";
            }
        }

        stderr: SplitParser {
            onRead: (line) => {
                if (proc.errText.length < 64000)
                    proc.errText += line + "\n";
            }
        }

        onExited: (code) => {
            const cmd = proc.current;
            proc.current = null;
            root.runningId = "";

            if (!cmd) { root.pump(); return; }

            const ok = code === 0;
            root.record(cmd, code, proc.outText, proc.errText, false);

            if (ok) {
                // Prefer the command's own last line of output over a generic
                // "Done" -- `theme-current` saying "auto" is more useful than
                // a tick, and `portal-check` saying nothing means something.
                root.notify(cmd.id, cmd.name,
                            root.firstUsefulLine(proc.outText) || "Done", "good");
            } else {
                root.notify(cmd.id, cmd.name,
                            root.firstUsefulLine(proc.errText)
                            || root.firstUsefulLine(proc.outText)
                            || ("Exited " + code), "bad");
            }

            root.finished(cmd.id, ok);
            root.pump();
        }
    }

    // The most informative single line of a block of output: the last
    // non-empty one, because scripts here print progress and then a result.
    function firstUsefulLine(text) {
        if (!text) return "";
        const lines = String(text).split("\n").map(l => l.trim()).filter(l => l !== "");
        if (lines.length === 0) return "";
        const last = lines[lines.length - 1];
        return last.length > 120 ? last.slice(0, 117) + "…" : last;
    }

    // -----------------------------------------------------------------
    // Picking files
    //
    // `just phone-send` takes paths, and a path is the one kind of input a
    // text field is genuinely bad at. zenity is used rather than a file
    // browser built into the panel for the same reason SettingsSystem opens
    // nm-connection-editor instead of reimplementing it: it is already
    // installed, and on this desktop it routes through
    // xdg-desktop-portal-gtk -- the backend ~/.config/xdg-desktop-portal
    // already designates for file choosers -- so it is the SAME picker every
    // other application here opens, with the same bookmarks and recent files.
    //
    // A layer-shell surface cannot host a modal file dialog of its own, so the
    // alternative was a bespoke file browser inside the panel. That is a lot
    // of UI to maintain for something the desktop already does properly.
    //
    // The separator is a newline because a filename may contain anything else
    // -- zenity's default "|" is a legal character in a POSIX path. It cannot
    // contain a newline or a NUL, and zenity cannot emit NUL, so newline is
    // the only safe choice available.
    // -----------------------------------------------------------------

    property var pickingFor: null

    readonly property bool picking: picker.running

    function pickFiles(cmd) {
        if (picker.running || !cmd) return false;
        root.pickingFor = cmd;
        picker.command = ["zenity", "--file-selection", "--multiple",
                          "--separator=\n",
                          "--title=" + (cmd.input && cmd.input.title
                                        ? cmd.input.title : cmd.name)];
        picker.running = true;
        return true;
    }

    Process {
        id: picker

        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const cmd = root.pickingFor;
                root.pickingFor = null;
                if (!cmd) return;

                const paths = picker.stdout.text
                    .split("\n")
                    .map(p => p.trim())
                    .filter(p => p !== "");

                // Cancelling the dialog is not a failure and must not raise a
                // toast -- it is the most common outcome of opening a file
                // picker and changing your mind.
                if (paths.length === 0) return;

                root.run(cmd, paths);
            }
        }
    }

    // -----------------------------------------------------------------
    // Clipboard
    //
    // For the paste button in CmdPrompt. wl-paste is what SUPER+V's cliphist
    // pipeline already uses, so there is no second clipboard mechanism here.
    // -n suppresses the trailing newline wl-paste would otherwise add, which
    // would end up inside a URL.
    // -----------------------------------------------------------------

    signal clipboardRead(string text)

    function readClipboard() {
        if (clip.running) return;
        clip.running = true;
    }

    Process {
        id: clip

        command: ["wl-paste", "-n"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.clipboardRead(clip.stdout.text)
        }

        onExited: (code) => {
            // An empty clipboard exits non-zero. Nothing to paste is not an
            // error worth a toast.
            if (code !== 0) root.clipboardRead("");
        }
    }

    // -----------------------------------------------------------------
    // History
    // -----------------------------------------------------------------

    function record(cmd, code, out, err, detached) {
        const entry = {
            id: cmd.id,
            label: cmd.name,
            cli: cmd.cli || "",
            code: code,
            ok: code === 0,
            stdout: out,
            stderr: err,
            detached: detached === true,
            at: Date.now()
        };
        root.history = [entry].concat(root.history).slice(0, root.historyLimit);
    }

    function lastRun(id) {
        for (const h of root.history)
            if (h.id === id) return h;
        return null;
    }

    function clearHistory() {
        root.history = [];
    }

    // -----------------------------------------------------------------
    // Recents
    //
    // Persisted, because a command centre that forgets what you use is a
    // menu. Order is most-recent-first and it is also the ranking used by
    // search, so the things you reach for keep rising to the top of their
    // tier without you organising anything.
    // -----------------------------------------------------------------

    readonly property var recent: Settings.commands.recent || []

    function remember(id) {
        const next = [id];
        for (const entry of root.recent) {
            if (entry !== id) next.push(entry);
            if (next.length >= 12) break;
        }
        // Rebuilt wholesale, never mutated in place: a `var` property only
        // emits its change signal on assignment, so an in-place push would
        // update nothing and persist nothing.
        Settings.commands.recent = next;
    }

    // Position in the recent list, for search ranking. 999 = never used.
    function rank(id) {
        const i = root.recent.indexOf(id);
        return i === -1 ? 999 : i;
    }

    readonly property var recentCommands: {
        const out = [];
        for (const id of root.recent) {
            const cmd = CommandRegistry.get(id);
            // Skip anything whose registry entry has gone -- a renamed id
            // should not leave a dead row in Recents.
            if (cmd) out.push(cmd);
        }
        return out;
    }

    function clearRecent() {
        Settings.commands.recent = [];
    }

    // -----------------------------------------------------------------
    // Favourites
    //
    // Hand-ordered, which is why they are a list rather than a set: the order
    // IS the user's layout, and it is what drag-and-drop in the Quick Actions
    // grid rewrites.
    // -----------------------------------------------------------------

    readonly property var favourites: Settings.commands.favourites || []

    function isFavourite(id) {
        return root.favourites.indexOf(id) !== -1;
    }

    function toggleFavourite(id) {
        if (root.isFavourite(id)) {
            Settings.commands.favourites = root.favourites.filter(f => f !== id);
        } else {
            Settings.commands.favourites = root.favourites.concat([id]);
        }
    }

    // Move the favourite at `from` so it sits at `to`. The grid calls this on
    // drop; splice-out-then-splice-in rather than a swap, because a swap makes
    // dragging an item three places along scatter the two it passed over.
    function moveFavourite(from, to) {
        const list = root.favourites.slice();
        if (from < 0 || from >= list.length) return;
        const clamped = Math.max(0, Math.min(list.length - 1, to));
        if (clamped === from) return;
        const [item] = list.splice(from, 1);
        list.splice(clamped, 0, item);
        Settings.commands.favourites = list;
    }

    readonly property var favouriteCommands: {
        const out = [];
        for (const id of root.favourites) {
            const cmd = CommandRegistry.get(id);
            if (cmd) out.push(cmd);
        }
        return out;
    }

    // -----------------------------------------------------------------
    // Category order
    //
    // The home page's cards, in the order the user dragged them into. Stored
    // as a list of ids and reconciled against the registry on every read, so
    // a category added to CommandRegistry appears (at the end) without the
    // saved order having to be migrated, and one removed does not leave a hole.
    // -----------------------------------------------------------------

    readonly property var categoryOrder: {
        const saved = Settings.commands.order || [];
        const known = CommandRegistry.categories;
        const byId = {};
        for (const c of known) byId[c.id] = c;

        const out = [];
        for (const id of saved) {
            if (byId[id]) { out.push(byId[id]); delete byId[id]; }
        }
        for (const c of known) if (byId[c.id]) out.push(c);
        return out;
    }

    function moveCategory(from, to) {
        const list = root.categoryOrder.map(c => c.id);
        if (from < 0 || from >= list.length) return;
        const clamped = Math.max(0, Math.min(list.length - 1, to));
        if (clamped === from) return;
        const [item] = list.splice(from, 1);
        list.splice(clamped, 0, item);
        Settings.commands.order = list;
    }

    function resetLayout() {
        Settings.commands.order = [];
    }
}
