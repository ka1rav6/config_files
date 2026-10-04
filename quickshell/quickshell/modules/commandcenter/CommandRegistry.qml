pragma Singleton

import QtQuick
import Quickshell
import qs

// =============================================================================
// CommandRegistry — the one place a command is declared.
// =============================================================================
// Everything the Command Center can do is one entry in `commands` below. No
// other file in modules/commandcenter knows a command name, a recipe name or a
// shell string: the UI renders whatever this says, and CommandRunner executes
// whatever this says. Adding a command means adding one object here and
// nothing else.
//
// WHY THE ENTRIES ARE PLAIN OBJECTS AND NOT QML COMPONENTS
//   A `Command { }` type reads nicely in a design doc and is the wrong shape
//   for this. 50 QObjects with 14 properties each is 700 bindings constructed
//   at startup for a panel that is closed, and the list has to be filtered and
//   sorted on every keystroke -- which is cheap over an array of JS objects and
//   expensive over a Repeater of QObjects. This array is built ONCE (nothing in
//   it is a reactive expression; see the note on `run` below) and search is a
//   plain Array.filter over it.
//
// THE CLI STAYS THE SOURCE OF TRUTH
//   Where a `just` recipe exists, the entry runs `just <recipe>` -- never a
//   copy of the recipe's body. `just theme catppuccin` rethemes nine
//   applications, verifies every marker block first and regenerates the
//   catalogue; reimplementing any slice of that here would create a second
//   source of truth and a way for the GUI and the terminal to disagree about
//   what the desktop looks like. The `cli` field on every entry is printed in
//   the UI, so the panel also functions as documentation for the command it is
//   replacing.
//
//   `just` is invoked with --justfile/--working-directory rather than inherited
//   cwd: the shell is started from ~/.config/hypr/autostart.lua and its working
//   directory is not a thing anyone should have to reason about.
//
// WHERE A NATIVE CALL BEATS A SUBPROCESS
//   Three kinds of entry deliberately do NOT shell out:
//
//     * toggles whose state the shell already owns and watches
//       (NightLight, Notifications, Performance.profile). Spawning `just` to
//       flip a boolean the process is already authoritative about would be
//       slower, would lose the live state, and would make the toggle lie for
//       the half-second the subprocess takes.
//     * the theme and matugen selectors, which route through
//       services/ThemeCatalogue.qml and services/Matugen.qml. Those ALREADY
//       run `theme-switch`, with progress reporting and failure capture --
//       i.e. they are the same command, through the existing service, rather
//       than a second way to run it.
//     * `link` entries, which open another surface of this desktop or an
//       external tool that does the job properly.
//
//   Everything else is a subprocess, because everything else is a script.
//
// FIELDS
//   id          stable key; used by favourites, recents and the layout order,
//               so renaming one silently drops it out of the user's favourites
//   name        what the user reads
//   category    key into `categories` below
//   desc        one line, says what it DOES, not what it is called
//   icon        a name from ui/Icon.qml's map
//   tags        extra search terms -- the words you would actually type
//   ui          action | toggle | select | status | link
//   safety      safe | confirm | danger        (see CmdConfirm.qml)
//   cli         the equivalent terminal command, shown in the UI
//   exec        argv array, for ui: action
//   detach      run outside the shell's process tree (survives a restart)
//   output      capture stdout/stderr and offer "Show output"
//   run         a JS function, for native toggles and selectors
//   state       key into CommandState.states, for ui: toggle
//   status      key into CommandState.status, for the live readout on a row
//   options     static [{ id, label, desc }] for ui: select
//   optionsFrom themes | schemes | prefer | profiles — a live list
//   value       key into CommandState.values, for the current ui: select choice
//   warn        shown in the confirmation sheet: what is about to happen
//   input       this command takes a value. { kind: "text" | "files", label,
//               placeholder, multiline, action, title }. "text" opens
//               CmdPrompt; "files" opens the desktop's file picker. Either
//               way the result is appended to `exec` as separate argv
//               elements, never spliced into a string.
//
// WHAT IS DELIBERATELY NOT HERE
//   Recipes that take an argument only a human can supply are left on the CLI
//   rather than given a text field, because a text field in a launcher is a
//   shell prompt with extra steps and this is a curated launcher, not a shell:
//
//     just add +PATHS          which paths to track in the backup
//     just restore <sel>       which numbered entries to copy back
//     just qs-restore <file>   which snapshot archive
//     just drive SRC DEST      an fpsync run that belongs in a terminal
//     just qs-debug            runs in the foreground; the whole point is to
//                              watch stderr in a terminal
//
//   THE THREE KDE CONNECT ONES ARE HERE, AND THEY TOOK A SHEET TO DO SAFELY.
//   phone-send, phone-open, phone-type and phone-ping all take a value only a
//   person can supply, and the first draft of this file left all four on the
//   CLI on the grounds that a text field in a launcher is a shell with extra
//   steps. That was the wrong call for these: pushing a file to your phone or
//   opening a link on it is exactly the kind of thing you want one click away,
//   and it is miserable to do by typing a path into a terminal.
//
//   What makes them safe is not the field, it is the shape of the execution:
//   an entry declares `input`, the panel collects ONE value, and
//   CommandRunner.appendArgs appends it to the entry's fixed argv as a
//   separate element. There is no shell on that path and nothing is
//   interpolated into a string, so the text is data all the way to execve.
//   See the argv note on appendArgs, and CmdPrompt.qml's header.
//
//   `just restore-check` IS here: it is the read-only half, it takes no
//   argument in its useful form, and it is the thing you actually want to
//   glance at. If it says something needs restoring, that is the moment to open
//   a terminal -- so the row says so.
// =============================================================================

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // `just` against the user's ~/Justfile, independent of this process's cwd.
    function just(...recipe) {
        return ["just", "--justfile", root.home + "/Justfile",
                "--working-directory", root.home].concat(recipe);
    }

    // -----------------------------------------------------------------
    // Categories
    //
    // Derived from what the commands actually are, not from a list of
    // plausible desktop nouns. There is no "Productivity" or "Development"
    // card because nothing in the Justfile is one: inventing the heading
    // would mean inventing something to put under it.
    // -----------------------------------------------------------------
    readonly property var categories: [
        {
            id: "appearance",
            label: "Appearance",
            desc: "Themes, palette derivation, wallpaper, night light",
            icon: "palette"
        },
        {
            id: "shell",
            label: "Desktop Shell",
            desc: "Quickshell itself — restart, status, snapshots",
            icon: "widgets"
        },
        {
            id: "kdeconnect",
            label: "KDE Connect",
            desc: "The Galaxy S25+ — ring, ping, browse its storage",
            icon: "monitor-multiple"
        },
        {
            id: "session",
            label: "Session",
            desc: "Compositor, bar, notifications, displays, lock",
            icon: "desktop"
        },
        {
            id: "system",
            label: "System",
            desc: "Portals, power profile, audio ceiling",
            icon: "settings"
        },
        {
            id: "maintenance",
            label: "Maintenance",
            desc: "Config backup, restore checks, browser caches",
            icon: "shield"
        },
        {
            id: "tools",
            label: "Elsewhere",
            desc: "The panels and applications that own these jobs properly",
            icon: "apps"
        }
    ]

    function category(id) {
        for (const c of root.categories)
            if (c.id === id) return c;
        return null;
    }

    // -----------------------------------------------------------------
    // Commands
    //
    // NOTE ON `run`
    //   The arrow functions below reference singletons, but a function BODY is
    //   not evaluated while the binding that builds this array is evaluated --
    //   so no dependency is captured and this array is constructed exactly
    //   once, at first read. Putting a bare `NightLight.active` in here instead
    //   would make the whole registry re-evaluate every time the lamp changed.
    // -----------------------------------------------------------------
    readonly property var commands: [

        // =============================================================
        // Appearance
        // =============================================================
        {
            id: "theme",
            name: "Theme",
            category: "appearance",
            desc: "Retheme the whole desktop — terminal, bar, menus, GTK, portal and this shell",
            icon: "palette",
            tags: ["colour", "color", "palette", "catppuccin", "gruvbox", "nord",
                   "dracula", "tokyonight", "everforest", "rose pine", "kanagawa",
                   "mint", "dark", "appearance", "retheme"],
            ui: "select",
            safety: "safe",
            cli: "just theme <name>",
            optionsFrom: "themes",
            value: "theme",
            status: "theme",
            // ThemeCatalogue already runs `theme-switch <name>` with progress
            // and failure capture. Going through it rather than spawning our
            // own copy is what keeps one theme switch one event.
            run: (arg) => ThemeCatalogue.apply(arg)
        },
        {
            id: "theme-auto",
            name: "Re-derive palette from wallpaper",
            category: "appearance",
            desc: "Hand the current wallpaper back to matugen and rebuild the `auto` theme",
            icon: "refresh",
            tags: ["auto", "matugen", "wallpaper", "material you", "derive", "palette"],
            ui: "action",
            safety: "safe",
            cli: "just theme auto",
            run: () => ThemeCatalogue.refreshAuto()
        },
        {
            id: "theme-palette",
            name: "Preview derived palette",
            category: "appearance",
            desc: "Show the colours `auto` would produce, without applying them",
            icon: "eye",
            tags: ["palette", "preview", "swatch", "matugen", "dry run"],
            ui: "action",
            safety: "safe",
            cli: "just theme-palette",
            exec: root.just("theme-palette"),
            output: true
        },
        {
            id: "matugen-scheme",
            name: "Palette algorithm",
            category: "appearance",
            desc: "Which Material You scheme `auto` derives with",
            icon: "palette",
            tags: ["matugen", "scheme", "vibrant", "muted", "tonal", "expressive",
                   "material", "auto"],
            ui: "select",
            safety: "safe",
            cli: "just theme-matugen <scheme>",
            optionsFrom: "schemes",
            value: "scheme",
            status: "matugen",
            run: (arg) => Matugen.setScheme(arg)
        },
        {
            id: "matugen-mode",
            name: "Light / dark derivation",
            category: "appearance",
            desc: "Whether `auto` builds a dark or a light palette",
            icon: "sun",
            tags: ["matugen", "light", "dark", "mode", "auto"],
            ui: "select",
            safety: "safe",
            cli: "just theme-matugen <light|dark>",
            options: [
                { id: "dark", label: "Dark" },
                { id: "light", label: "Light" }
            ],
            value: "mode",
            run: (arg) => Matugen.setMode(arg)
        },
        {
            id: "wallpaper-random",
            name: "Random wallpaper",
            category: "appearance",
            desc: "Pick another image from the wallpaper directory",
            icon: "wallpaper",
            tags: ["wallpaper", "background", "random", "shuffle"],
            ui: "action",
            safety: "safe",
            cli: "quickshell ipc call wallpaper random",
            status: "wallpaper",
            run: () => Wallpaper.random()
        },
        {
            id: "night-light",
            name: "Night Light",
            category: "appearance",
            desc: "Warm the screen down with wlsunset",
            icon: "night-light",
            tags: ["night", "warm", "blue light", "wlsunset", "gamma",
                   "temperature", "eyes"],
            ui: "toggle",
            safety: "safe",
            cli: "pkill wlsunset / wlsunset -t 4000",
            state: "nightlight",
            status: "nightlight",
            run: () => NightLight.toggle()
        },
        {
            id: "picker-restyle",
            name: "Restyle the share picker",
            category: "appearance",
            desc: "Regenerate just the screen-share dialog's stylesheet, without retheming everything",
            icon: "monitor",
            tags: ["share", "picker", "screen share", "qss", "stylesheet", "xdph"],
            ui: "action",
            safety: "safe",
            cli: "just picker-restyle",
            exec: root.just("picker-restyle"),
            output: true
        },

        // =============================================================
        // Desktop shell
        // =============================================================
        {
            id: "qs-status",
            name: "Shell status",
            category: "shell",
            desc: "Theme, settings, performance profile, compositor and monitor count",
            icon: "info",
            tags: ["quickshell", "status", "health", "alive", "diagnose"],
            ui: "action",
            safety: "safe",
            cli: "just qs-status",
            exec: root.just("qs-status"),
            output: true,
            status: "shell"
        },
        {
            id: "qs-services",
            name: "Service readouts",
            category: "shell",
            desc: "Every service's view of the world in one list — the first thing to check when a panel shows the wrong thing",
            icon: "cpu",
            tags: ["services", "audio", "network", "bluetooth", "battery",
                   "diagnose", "debug", "quickshell"],
            ui: "action",
            safety: "safe",
            cli: "quickshell ipc call shell services",
            exec: ["quickshell", "ipc", "call", "shell", "services"],
            output: true
        },
        {
            id: "qs-ipc",
            name: "IPC targets",
            category: "shell",
            desc: "Every target and function the shell exposes to keybindings",
            icon: "terminal",
            tags: ["ipc", "keybind", "targets", "quickshell", "api"],
            ui: "action",
            safety: "safe",
            cli: "just qs-ipc",
            exec: root.just("qs-ipc"),
            output: true
        },
        {
            id: "qs-backup",
            name: "Snapshot the desktop",
            category: "shell",
            desc: "Archive every config this shell can touch into ~/.local/share/quickshell-backups",
            icon: "download",
            tags: ["backup", "snapshot", "archive", "quickshell", "rollback"],
            ui: "action",
            safety: "safe",
            cli: "just qs-backup",
            exec: root.just("qs-backup"),
            output: true
        },
        {
            id: "qs-viz",
            name: "Demo the visualiser",
            category: "shell",
            desc: "Show the audio bars for 30 s, setting up both gates so they actually draw",
            icon: "visualizer",
            tags: ["visualizer", "cava", "audio", "bars", "demo"],
            ui: "action",
            safety: "safe",
            cli: "just qs-viz",
            exec: root.just("qs-viz"),
            detach: true
        },
        {
            id: "qs-reload",
            name: "Restart the shell",
            category: "shell",
            desc: "Reload this shell's QML. Needed after any edit — it does not hot-reload.",
            icon: "restart",
            tags: ["restart", "reload", "quickshell", "qml", "refresh"],
            ui: "action",
            safety: "confirm",
            cli: "just qs-reload",
            // MUST be detached. qs-reload SIGTERMs this very process, so a
            // queued Process would be killed along with its parent before it
            // got as far as relaunching anything -- leaving no shell at all.
            // It is also why this cannot capture output: there is nothing left
            // to read it.
            exec: root.just("qs-reload"),
            detach: true,
            warn: "Every panel disappears for about a second and reopens. Windows, workspaces and keybinds are unaffected — nothing in the compositor depends on this process."
        },
        {
            id: "qs-reset-settings",
            name: "Reset shell settings",
            category: "shell",
            desc: "Delete settings.json and restart, restoring every GUI option to its default",
            icon: "trash",
            tags: ["reset", "defaults", "settings", "wipe", "clean"],
            ui: "action",
            safety: "danger",
            cli: "just qs-reset-settings",
            exec: root.just("qs-reset-settings"),
            detach: true,
            warn: "Deletes ~/.config/quickshell/settings.json. Loses every option in Settings, your dock pins, widget positions, these favourites and this panel's layout. Themes and compositor config are NOT affected. Cannot be undone — `just qs-backup` first if you want a way back."
        },

        // =============================================================
        // KDE Connect
        // =============================================================
        {
            id: "phone-status",
            name: "Phone status",
            category: "kdeconnect",
            desc: "Pairing state, reachability, and whether the filesystem is mounted",
            icon: "monitor-multiple",
            tags: ["kde connect", "kdeconnect", "phone", "galaxy", "android",
                   "paired", "status", "mounted"],
            ui: "action",
            safety: "safe",
            cli: "just phone-status",
            exec: root.just("phone-status"),
            output: true
        },
        {
            id: "phone-ring",
            name: "Ring the phone",
            category: "kdeconnect",
            desc: "Make it make a noise, for when it is under a cushion",
            icon: "bell",
            tags: ["kde connect", "kdeconnect", "ring", "find", "phone", "lost",
                   "noise", "alarm"],
            ui: "action",
            safety: "safe",
            cli: "just phone-ring",
            exec: root.just("phone-ring")
        },
        {
            id: "phone-ping",
            name: "Ping the phone",
            category: "kdeconnect",
            desc: "Send a notification to it — the quickest proof the link is live",
            icon: "bell",
            tags: ["kde connect", "kdeconnect", "ping", "notify", "phone", "test"],
            ui: "action",
            safety: "safe",
            // The recipe's MSG default is empty, which would leave
            // `--ping-msg` with no value consuming the next flag -- so a
            // message is always supplied, and now it is yours rather than a
            // canned one.
            cli: "just phone-ping <message>",
            exec: root.just("phone-ping"),
            input: {
                kind: "text",
                label: "Appears as a notification on the phone.",
                placeholder: "Ping from the Command Center",
                action: "Send ping"
            }
        },
        {
            id: "phone-send",
            name: "Send files to the phone",
            category: "kdeconnect",
            desc: "Pick files and push them across — they land in the phone's Downloads",
            icon: "file-send",
            tags: ["kde connect", "kdeconnect", "send", "share", "file",
                   "files", "transfer", "push", "copy", "phone", "upload"],
            ui: "action",
            safety: "safe",
            cli: "just phone-send <files…>",
            exec: root.just("phone-send"),
            output: true,
            // `files` opens the desktop's own picker rather than a text field;
            // the chosen paths are appended to the argv above as separate
            // elements. See CommandRunner.pickFiles.
            input: { kind: "files", title: "Send to the phone" }
        },
        {
            id: "phone-open",
            name: "Open a link on the phone",
            category: "kdeconnect",
            desc: "Hand a URL to the phone and let it open in whatever handles it",
            icon: "link",
            tags: ["kde connect", "kdeconnect", "url", "link", "open", "share",
                   "browser", "send", "phone", "web"],
            ui: "action",
            safety: "safe",
            cli: "just phone-open <url>",
            exec: root.just("phone-open"),
            input: {
                kind: "text",
                label: "The phone opens this with whatever handles the scheme — a browser for https, the dialer for tel.",
                placeholder: "https://…",
                action: "Open on phone"
            }
        },
        {
            id: "phone-type",
            name: "Type on the phone",
            category: "kdeconnect",
            desc: "Send keystrokes to whatever has focus on the phone — a long URL, an address, a code",
            icon: "keyboard",
            tags: ["kde connect", "kdeconnect", "type", "keys", "keyboard",
                   "text", "input", "send", "phone", "remote"],
            ui: "action",
            safety: "safe",
            cli: "just phone-type <text>",
            exec: root.just("phone-type"),
            input: {
                kind: "text",
                multiline: true,
                label: "Typed into whatever has focus on the phone right now. Check what that is before sending.",
                placeholder: "Text to type…",
                action: "Type it"
            }
        },
        {
            id: "phone-browse",
            name: "Browse phone storage",
            category: "kdeconnect",
            desc: "Mount it over sftp and open the listable root in a file manager",
            icon: "folder",
            tags: ["kde connect", "kdeconnect", "browse", "files", "sftp",
                   "mount", "storage", "phone", "nautilus"],
            ui: "action",
            safety: "safe",
            cli: "just phone-browse",
            exec: root.just("phone-browse"),
            // Ends in `setsid nautilus &`, so the recipe returns while the file
            // manager keeps running; detaching keeps it clear of this process.
            detach: true
        },
        {
            id: "phone-unmount",
            name: "Unmount phone storage",
            category: "kdeconnect",
            desc: "Drop the sftp mount",
            icon: "close",
            tags: ["kde connect", "kdeconnect", "unmount", "eject", "sftp", "phone"],
            ui: "action",
            safety: "safe",
            cli: "just phone-unmount",
            exec: root.just("phone-unmount"),
            output: true
        },
        {
            id: "kdeconnect-settings",
            name: "KDE Connect settings",
            category: "kdeconnect",
            desc: "Pairing, per-plugin configuration, SMS — the things a quick panel should not try to be",
            icon: "settings",
            tags: ["kde connect", "kdeconnect", "pair", "plugins", "settings",
                   "sms", "app"],
            ui: "link",
            safety: "safe",
            cli: "kdeconnect-settings",
            exec: ["kdeconnect-settings"],
            detach: true
        },

        // =============================================================
        // Session
        // =============================================================
        {
            id: "hypr-reload",
            name: "Reload the compositor",
            category: "session",
            desc: "Re-read ~/.config/hypr/*.lua — keybinds, rules, monitors, look and feel",
            icon: "refresh",
            tags: ["hyprland", "reload", "compositor", "keybinds", "rules",
                   "hyprctl", "config"],
            ui: "action",
            safety: "safe",
            cli: "hyprctl reload",
            exec: ["hyprctl", "reload"],
            output: true
        },
        {
            id: "waybar-reload",
            name: "Reload the bar",
            category: "session",
            desc: "Re-read waybar's config and stylesheet in place",
            icon: "dock",
            tags: ["waybar", "bar", "reload", "status bar", "sigusr2", "css"],
            ui: "action",
            safety: "safe",
            cli: "killall -SIGUSR2 waybar",
            exec: ["killall", "-SIGUSR2", "waybar"]
        },
        {
            id: "dnd",
            name: "Do Not Disturb",
            category: "session",
            desc: "Hold notifications in mako's queue instead of showing them",
            icon: "bell-off",
            tags: ["dnd", "do not disturb", "notifications", "mako", "quiet",
                   "silence", "mute"],
            ui: "toggle",
            safety: "safe",
            cli: "makoctl mode -t do-not-disturb",
            state: "dnd",
            status: "dnd",
            run: () => Notifications.toggle()
        },
        {
            id: "mako-restore",
            name: "Restore last notification",
            category: "session",
            desc: "Bring back the notification that was just dismissed",
            icon: "bell",
            tags: ["notification", "mako", "restore", "undo", "dismissed",
                   "history"],
            ui: "action",
            safety: "safe",
            cli: "makoctl restore",
            exec: ["makoctl", "restore"]
        },
        {
            id: "display-mirror",
            name: "Toggle display mirroring",
            category: "session",
            desc: "Mirror the internal panel to the external monitor, or stop",
            icon: "monitor-multiple",
            tags: ["display", "monitor", "mirror", "external", "projector",
                   "hdmi", "screen"],
            ui: "action",
            safety: "confirm",
            cli: "~/.config/hypr/scripts/display-layout.sh toggle-mirror",
            exec: [root.home + "/.config/hypr/scripts/display-layout.sh", "toggle-mirror"],
            status: "displays",
            output: true,
            warn: "Both outputs are reconfigured. Windows may be moved and resized to fit the new layout."
        },
        {
            id: "lock",
            name: "Lock the session",
            category: "session",
            desc: "Start the locker in its own process, so a shell fault cannot strand you at a locked screen",
            icon: "lock",
            tags: ["lock", "screen", "hyprlock", "away", "secure", "session"],
            ui: "action",
            safety: "confirm",
            cli: "~/.local/bin/lock-session",
            exec: [root.home + "/.local/bin/lock-session"],
            detach: true,
            warn: "The screen locks immediately. You will need your password to get back in."
        },

        // =============================================================
        // System
        // =============================================================
        {
            id: "profile",
            name: "Performance profile",
            category: "system",
            desc: "What the shell is allowed to spend — blur, shadows, animation, visualiser",
            icon: "performance",
            tags: ["performance", "profile", "battery", "saver", "balanced",
                   "visual", "power", "gpu", "blur"],
            ui: "select",
            safety: "safe",
            cli: "quickshell ipc call shell profile <name>",
            optionsFrom: "profiles",
            value: "profile",
            status: "profile",
            run: (arg) => { Settings.performance.profile = arg; }
        },
        {
            id: "portal-check",
            name: "Check the portals",
            category: "system",
            desc: "Which backend answers what, and the colour scheme being broadcast to Chromium, VS Code and Flatpaks",
            icon: "shield",
            tags: ["portal", "xdg", "flatpak", "screen share", "file picker",
                   "colour scheme", "check", "diagnose"],
            ui: "action",
            safety: "safe",
            cli: "just portal-check",
            exec: root.just("portal-check"),
            output: true
        },
        {
            id: "portal-restart",
            name: "Restart the portals",
            category: "system",
            desc: "Restart every xdg-desktop-portal backend, after editing the routing config",
            icon: "restart",
            tags: ["portal", "xdg", "restart", "flatpak", "screen share",
                   "systemd"],
            ui: "action",
            safety: "confirm",
            cli: "just portal-restart",
            exec: root.just("portal-restart"),
            output: true,
            warn: "Any screen share or file dialog currently open will be dropped. Do not do this mid-call."
        },
        {
            id: "picker-preview",
            name: "Preview the share picker",
            category: "system",
            desc: "Open the screen-share dialog on its own, to see it without starting a share",
            icon: "monitor",
            tags: ["share", "picker", "screen share", "preview", "xdph",
                   "dialog", "capture"],
            ui: "action",
            safety: "safe",
            cli: "just picker-preview",
            exec: root.just("picker-preview"),
            detach: true
        },
        {
            id: "loud",
            name: "Boost volume to 150%",
            category: "system",
            desc: "Raise the sink above unity — for a quiet recording, not for music",
            icon: "volume-high",
            tags: ["volume", "loud", "boost", "150", "audio", "max", "amplify"],
            ui: "action",
            safety: "confirm",
            cli: "just loud",
            exec: root.just("loud"),
            status: "volume",
            warn: "Software gain above 100% clips and distorts, and it is loud enough to hurt on headphones. The Control Center's slider is capped at unity for exactly this reason."
        },
        {
            id: "matugen-install",
            name: "Install / update matugen",
            category: "system",
            desc: "Fetch the latest matugen release into ~/.local/bin — without it, `auto` falls back to a worse derivation",
            icon: "download",
            tags: ["matugen", "install", "update", "download", "material",
                   "github", "binary"],
            ui: "action",
            safety: "confirm",
            cli: "just theme-install-matugen",
            exec: root.just("theme-install-matugen"),
            output: true,
            status: "matugenInstalled",
            warn: "Downloads a binary from GitHub over the network and installs it to ~/.local/bin/matugen, replacing any existing copy."
        },

        // =============================================================
        // Maintenance
        // =============================================================
        {
            id: "backup",
            name: "Back up configs",
            category: "maintenance",
            desc: "Copy every tracked path into ~/dotfiles",
            icon: "shield",
            tags: ["backup", "dotfiles", "config", "save", "git", "sync"],
            ui: "action",
            safety: "safe",
            cli: "just backup",
            exec: root.just("backup"),
            output: true
        },
        {
            id: "restore-check",
            name: "What is out of sync",
            category: "maintenance",
            desc: "Show what `just restore` would copy back, and change nothing",
            icon: "eye",
            tags: ["restore", "check", "dry run", "diff", "dotfiles", "sync",
                   "out of date"],
            ui: "action",
            safety: "safe",
            // The restore itself stays on the CLI: it is selected by numbers
            // read off this listing, and those numbers only mean anything in
            // the terminal that printed them.
            cli: "just restore-check",
            exec: root.just("restore-check"),
            output: true
        },
        {
            id: "clean-brave",
            name: "Clear Brave's cache",
            category: "maintenance",
            desc: "Quit Brave and empty ~/.cache/BraveSoftware",
            icon: "trash",
            tags: ["brave", "cache", "clean", "clear", "browser", "disk",
                   "space"],
            ui: "action",
            safety: "danger",
            cli: "just clean-brave",
            exec: root.just("clean-brave"),
            output: true,
            warn: "Kills Brave immediately — any unsaved form, unsent message or open tab state goes with it — then deletes its cache directory."
        },
        {
            id: "clean-chrome",
            name: "Clear Chrome's cache",
            category: "maintenance",
            desc: "Quit Chrome and empty ~/.cache/google-chrome",
            icon: "trash",
            tags: ["chrome", "cache", "clean", "clear", "browser", "disk",
                   "space"],
            ui: "action",
            safety: "danger",
            cli: "just clean-chrome",
            exec: root.just("clean-chrome"),
            output: true,
            warn: "Kills Chrome immediately — any unsaved form, unsent message or open tab state goes with it — then deletes its cache directory."
        },

        // =============================================================
        // Elsewhere
        //
        // Not filler. These are the five surfaces that already own the jobs
        // this panel is most likely to be opened looking for, and a command
        // launcher whose answer to "wifi" is nothing at all is a launcher you
        // stop trusting. Searching "wifi" here lands on the Control Center,
        // which is the right answer.
        // =============================================================
        {
            id: "open-controlcenter",
            name: "Control Center",
            category: "tools",
            desc: "Wi-Fi, Bluetooth, volume, microphone, brightness, media",
            icon: "wifi-4",
            tags: ["wifi", "wi-fi", "network", "bluetooth", "volume", "audio",
                   "microphone", "mic", "brightness", "media", "control center",
                   "quick settings", "vpn"],
            ui: "link",
            safety: "safe",
            cli: "quickshell ipc call controlcenter toggle",
            status: "connectivity",
            run: () => { Shell.close("command-center"); Shell.open("control-center"); }
        },
        {
            id: "open-settings",
            name: "Settings",
            category: "tools",
            desc: "Every option this desktop shell has — appearance, components, performance, windows",
            icon: "settings",
            tags: ["settings", "preferences", "options", "configure",
                   "appearance", "font", "radius", "density", "dock"],
            ui: "link",
            safety: "safe",
            cli: "quickshell ipc call settings toggle",
            run: () => { Shell.close("command-center"); Shell.open("settings"); }
        },
        {
            id: "open-wallpaper",
            name: "Wallpaper picker",
            category: "tools",
            desc: "Browse and apply a wallpaper, with thumbnails",
            icon: "wallpaper",
            tags: ["wallpaper", "background", "picker", "image", "browse"],
            ui: "link",
            safety: "safe",
            cli: "quickshell ipc call wallpaper toggle",
            status: "wallpaper",
            run: () => { Shell.close("command-center"); Shell.open("wallpaper"); }
        },
        {
            id: "open-network-editor",
            name: "Network connections",
            category: "tools",
            desc: "Static IPs, VPNs, editing saved profiles",
            icon: "ethernet",
            tags: ["vpn", "network", "static ip", "dns", "profile", "wireguard",
                   "openvpn", "connection", "nm-connection-editor"],
            ui: "link",
            safety: "safe",
            cli: "nm-connection-editor",
            exec: ["nm-connection-editor"],
            detach: true
        },
        {
            id: "open-pavucontrol",
            name: "Audio routing",
            category: "tools",
            desc: "Per-application volume, input and output routing, card profiles",
            icon: "headphones",
            tags: ["audio", "pavucontrol", "routing", "sink", "source",
                   "profile", "a2dp", "per-app", "volume"],
            ui: "link",
            safety: "safe",
            cli: "pavucontrol",
            exec: ["pavucontrol"],
            detach: true
        },
        {
            id: "open-power",
            name: "Power menu",
            category: "tools",
            desc: "Lock, log out, suspend, restart, shut down",
            icon: "power",
            tags: ["power", "shutdown", "shut down", "reboot", "restart",
                   "logout", "log out", "suspend", "sleep", "off"],
            ui: "link",
            safety: "safe",
            cli: "quickshell ipc call power toggle",
            run: () => { Shell.close("command-center"); Shell.open("power"); }
        }
    ]

    // -----------------------------------------------------------------
    // Pairing a list with its positions
    // -----------------------------------------------------------------

    // Wrap a list as [{ i, item }], so a delegate can read its own position
    // out of `modelData` instead of relying on the `index` a Repeater injects.
    //
    // THIS IS NOT A STYLE CHOICE. `required property int index` on a delegate
    // is NOT satisfied here: with a plain JS array model this Repeater injects
    // `modelData` and leaves `index` at its type default. Measured against the
    // running shell, over the eight Quick Action tiles:
    //
    //     index=0  payload=theme            x=0  y=146
    //     index=0  payload=theme-auto       x=0  y=146
    //     index=0  payload=dnd              x=0  y=146          ... all eight
    //
    // Every tile therefore computed slot 0 and they rendered stacked on top of
    // one another -- eight labels in the same 202x60 box, which is exactly what
    // "the text is merged" looked like. The grid's own arithmetic was right the
    // whole time (844x132, four columns of 202); it was being handed 0 for
    // every index.
    //
    // It fails quietly in both directions, which is why it is worth a helper
    // rather than a fix in one place: declare `index` required and the delegate
    // does not construct at all ("Required property index was not
    // initialized"); declare it non-required and it silently reads 0 forever.
    // Carrying the position inside `modelData`, which IS injected reliably,
    // sidesteps the whole question.
    function enumerate(list) {
        const out = [];
        for (let i = 0; i < list.length; i++) out.push({ i: i, item: list[i] });
        return out;
    }

    // -----------------------------------------------------------------
    // Lookup and search
    // -----------------------------------------------------------------

    readonly property var byId: {
        const map = {};
        for (const c of root.commands) map[c.id] = c;
        return map;
    }

    function get(id) {
        return root.byId[id] !== undefined ? root.byId[id] : null;
    }

    function inCategory(id) {
        return root.commands.filter(c => c.category === id);
    }

    function countIn(id) {
        return root.inCategory(id).length;
    }

    // Three tiers, highest first, matching the launcher's rule rather than
    // inventing a second search behaviour for the same desktop:
    //
    //   1  the name starts with the query
    //   2  the name contains it
    //   3  the description, tags, category label or CLI command contain it
    //
    // Deliberately not fuzzy subsequence matching. See the header of
    // modules/launcher/Launcher.qml -- for something used a hundred times a
    // day, predictable beats clever. The third tier is what makes
    // "vpn" -> Network connections and "shutdown" -> Power menu work without
    // the user knowing either command's name.
    function search(query) {
        const q = String(query).trim().toLowerCase();
        if (q === "") return [];

        const starts = [], contains = [], loose = [];
        for (const c of root.commands) {
            const name = c.name.toLowerCase();
            if (name.startsWith(q)) { starts.push(c); continue; }
            if (name.indexOf(q) !== -1) { contains.push(c); continue; }
            const cat = root.category(c.category);
            const extra = (c.desc + " "
                + (c.tags || []).join(" ") + " "
                + (cat ? cat.label : "") + " "
                + (c.cli || "")).toLowerCase();
            if (extra.indexOf(q) !== -1) loose.push(c);
        }

        // Within a tier, things you actually use come first.
        const sort = (list) => list.sort((a, b) => {
            const d = CommandRunner.rank(a.id) - CommandRunner.rank(b.id);
            return d !== 0 ? d : a.name.localeCompare(b.name);
        });

        return sort(starts).concat(sort(contains), sort(loose));
    }
}
