# Keyboard Shortcuts

Everything bound across the Hyprland session and the Wayland tools around it.
Generated from `~/.config/hypr/bindings.lua`, `~/.config/hypr/scratchpads.lua`,
`~/.config/hypr/windows.lua`, `~/.config/hypr/lid.lua`,
`~/.config/hypr/defaults.lua`, `~/.config/waybar/config.jsonc`,
`~/.config/quickshell/shell.qml`, `~/.config/quickshell/settings.json` and
`~/.config/mako/config`.

Hyprland is still the whole behaviour layer — every key below is declared in
`bindings.lua` (plus the two lid switches in `lid.lua`) and nowhere else. The
Quickshell keys are ordinary `exec_cmd` binds that call
`quickshell ipc call <target> <function>`, so the shell never registers a global
shortcut of its own and `hyprctl binds` remains the single source of truth.

## Conventions

- `Super` is the Windows/Meta key (`mainMod = SUPER`).
- **Caps Lock and Escape are swapped** (`kb_options = caps:swapescape`), so the
  Caps Lock key sends Escape.
- Key repeat is fast and eager: 40 Hz after a 250 ms delay.
- Terminal is Ghostty, file manager is Nautilus. **Wofi is the launcher**, on
  `Super + S`, and is what `Super + V` pipes clipboard history through. The
  Quickshell launcher still exists and still answers
  `quickshell ipc call launcher toggle`, but it is deliberately unbound —
  `Super + Space` went to the workspace overview instead. The `󰣇` button on
  waybar is the only thing that opens it.
- The desktop shell is Quickshell (`~/.config/quickshell`). Every surface it
  draws can be reached from a key, and every one of them is independently
  switchable off in its Settings app — nothing below is load-bearing.
- **Window swallowing is on.** Launch a GUI app from an ordinary Ghostty and the
  terminal hides itself until that app exits. The scratchpads are deliberately
  exempt (they run under their own window classes), so they never vanish.
- On battery the internal panel drops to 60 Hz and returns to 120 Hz on AC,
  handled by `~/.config/hypr/scripts/power-refresh.sh`.

> `Super + L` focuses the window to the right. Locking is `Super + Escape` —
> deliberately nowhere near it, so a slipped finger cannot lock you out
> mid-thought.

## Session and Windows

| Shortcut | Action |
|---|---|
| `Super + Enter` | Open Ghostty |
| `Super + Q` | Close the focused window |
| `Alt + F4` | Close the focused window |
| `Super + M` | Power menu (Quickshell; falls back to wlogout if the shell is down) |
| `Super + Escape` | Lock the screen (Caps Lock sends Escape, so `Super + CapsLock` works too) |
| `Super + F` | Toggle fullscreen |
| `Super + Shift + F` | Toggle maximized — fills the monitor but keeps gaps, borders and the bar |
| `Super + Shift + Space` | Toggle floating |
| `Super + T` | **Tile the focused window** — put it back in the layout |
| `Super + Alt + T` | **Promote the showing scratchpad into the layout** — it becomes an ordinary tile here and a fresh scratchpad spawns hidden in its place. Falls back to `Super + T` when no scratchpad is showing |
| `Super + Shift + C` | Center the focused window |
| `Super + Shift + M` | Send the focused window to the next monitor (wraps) |
| `Alt + Tab` | Cycle to the next window |

`Super + T` is deliberately *not* a toggle. It unsets fullscreen and then
unsets floating, so it means "tile this" rather than "swap this" — you can
press it twice without undoing yourself, which is what you want on the way out
of a pile of floating windows. `Super + Shift + Space` is already the toggle.

`Super + Alt + T` is the scratchpad-aware version of the same idea — see
[Promoting a scratchpad](#promoting-a-scratchpad).

## Focusing Windows

| Shortcut | Action |
|---|---|
| `Super + H` | Focus left |
| `Super + J` / `Super + Down` | Focus down |
| `Super + K` / `Super + Up` | Focus up |
| `Super + L` | Focus right |

`Super + Left` and `Super + Right` are **not** focus binds — they slide between
workspaces (see below).

## Moving Windows

Moving lives on `Alt` so it stops colliding with the lock bind and the
named-workspace toggles.

| Shortcut | Action |
|---|---|
| `Super + Alt + H` | Move the window left |
| `Super + Alt + J` | Move the window down |
| `Super + Alt + K` | Move the window up |
| `Super + Alt + L` | Move the window right |
| `Super + left-drag` | Hyprland's own drag — a **tiled** window stays tiled and swaps place in the layout; a floating one is simply moved |
| `Super + Shift + left-drag` | **Pop a tiled window out of the layout** — shrink it around the pointer, float it there, and keep dragging |
| `Super + right-drag` | Resize |

The two drags cannot share a key: one has to mean "swap this" and the other
"float this". The bare `Super + drag` keeps the compositor's own meaning
because that is the one with the muscle memory behind it; popping a window out
is the rarer, deliberate act, which is what the extra modifier is for.
`Settings → Windows → dragToFloat` turns the Shift gesture off, in which case
it falls through to the plain drag.

## Resizing

All of these repeat while held.

| Shortcut | Action |
|---|---|
| `Super + Ctrl + H` | Shrink horizontally (−50 px) |
| `Super + Ctrl + J` | Grow vertically (+50 px) |
| `Super + Ctrl + K` | Shrink vertically (−50 px) |
| `Super + Ctrl + L` | Grow horizontally (+50 px) |
| `Super + -` | Shrink horizontally (−10 px) |
| `Super + =` | Grow horizontally (+10 px) |
| `Super + Shift + -` | Shrink vertically (−10 px) |
| `Super + Shift + =` | Grow vertically (+10 px) |

### Resize mode

Tap `Super + R` once to enter a resize submap, then resize with bare keys —
no modifier held. Unlike the workspace leader below, this submap **stays
armed**, because resizing is something you repeat.

| Key | Action |
|---|---|
| `H` / `Left` | Shrink horizontally (−50 px) |
| `J` / `Down` | Grow vertically (+50 px) |
| `K` / `Up` | Shrink vertically (−50 px) |
| `L` / `Right` | Grow horizontally (+50 px) |
| `Escape` or `Enter` | Leave resize mode |

## Workspaces

| Shortcut | Action |
|---|---|
| `Super + 1` … `Super + 9` | Switch to workspace 1–9 |
| `Super + 0` | Switch to workspace 10 |
| `Super + Shift + 1` … `Super + Shift + 9` | Move the window to workspace 1–9 |
| `Super + Shift + 0` | Move the window to workspace 10 |
| `Super + Tab` | Return to the last workspace |
| `Super + Left` | Slide to the previous existing workspace |
| `Super + Right` | Slide to the next existing workspace |
| `Super + Shift + Left` | Carry the window to the previous existing workspace |
| `Super + Shift + Right` | Carry the window to the next existing workspace |
| `Super + wheel up` | Previous existing workspace |
| `Super + wheel down` | Next existing workspace |

`Super + Left/Right` is the keyboard equivalent of the three-finger swipe. It is
deliberately not marked repeating, so holding the key cannot queue up more
switches than the animation can keep up with.

## Named and Special Workspaces

Named workspaces live behind a **`Super + W` leader**. Tap `Super + W`, then one
key. The submap is one-shot — it releases itself the moment you pick, so it
never swallows the keystroke after it.

| Then press | Workspace | Launches |
|---|---|---|
| `Enter` | `tmux` | Ghostty attached to tmux session `default` |
| `T` | `top` | btop in Ghostty ("top") |
| `N` | `nvim` | Neovim in Ghostty |
| `G` | `chrome` | Google Chrome (new window) |
| `B` | `brave` | Brave (new window) |
| `C` | `claude` | Claude Desktop |
| `D` | `debug` | Nothing — bare workspace |
| `Escape` / `Q` | — | Back out, do nothing |

btop needs the terminal around it: `exec btop` with no tty spawns a process
that exits immediately, which looked like the workspace opening empty.

Any other key also backs out silently (a `catchall` bind), so a mistype cannot
strand you in the submap — and, more importantly, cannot land the letter in
your editor while leaving the next keystroke hijacked.

They launch their app if the workspace is empty, and pressing the same sequence
again returns you to the previous workspace.

Special workspaces overlay the current one instead of replacing it. The only
ones bound now are the scratchpads below — `Super + D` used to toggle a bare
`special:desktop` overlay and now opens the dashboard instead.

## Scratchpads

Scratchpads are apps parked on their own hidden special workspace. The same key
drops one over whatever you are doing and takes it away again — it never claims
a tile. Each keeps its state between toggles, so the terminal keeps its shell
history and yazi keeps the directory you left it in.

| Shortcut | Workspace | App | Size | Pre-spawned at login |
|---|---|---|---|---|
| ``Super + ` `` | `special:scratch` | Ghostty | 1200 × 800 | Yes |
| `Super + E` | `special:files` | yazi in Ghostty | 1400 × 850 | Yes |
| `Super + Y` | `special:music` | YouTube Music PWA | 1300 × 850 | No — starts on first press |
| `Super + O` | `special:whatsapp` | WhatsApp Web PWA | 1200 × 850 | No — starts on first press |
| `Super + Shift + H` | `special:todo` | hyprtodo | fills the workspace | No — starts on first press |

Only the two Ghostty ones are pre-spawned. The three that are not are the
expensive ones: a Chrome process per login is real memory, and hyprtodo was
measured at 155 MB resident — the second-largest process on this machine after
the shell itself — for a list opened a few times a day. The toggle cold-starts
each of them on first press anyway; flip `prespawn = true` to trade the RAM for
an instant first open.

None of them appear in the dock, wherever they happen to be sitting —
`Settings.dock.exclude` matches them by window class, so a scratchpad dragged
onto a real workspace still stays out of the dock.

Quitting a scratchpad (exiting the shell, `q` in yazi, closing the PWA window)
is harmless: the next press of its key starts it again.

If one of these apps is already running somewhere else — a YouTube Music window
you opened before, or a scratchpad you deliberately threw onto a real workspace
— its key pulls it back onto its special workspace rather than opening a second
copy.

All five are declared in one table in `~/.config/hypr/scratchpads.lua`; adding
another is a single entry there, and `prespawn` is what decides whether it
starts at login.

### Promoting a scratchpad

`Super + Alt + T` promotes whichever scratchpad is currently showing: the window
stops being a centred overlay on a hidden workspace and becomes an ordinary tile
on the workspace you are looking at, and a fresh scratchpad spawns hidden in its
place.

It is for the quick thing that turned out not to be quick — the `tail -f` in the
`` Super + ` `` terminal that became the build you watch for an hour, which you
want *next to* the window you are watching it for rather than on top of it.

It works on any of the five, not just the terminal, which is why it lives next
to `Super + T` ("tile this") rather than hanging off any one toggle key. With no
scratchpad showing it is exactly `Super + T`, so it is safe to reach for without
checking what is focused.

Two things worth knowing:

- **The promoted window stops being that scratchpad's window.** Its key no
  longer pulls it back — that is the point, otherwise the next `` Super + ` ``
  would show you your build log instead of a clean terminal. It is marked with a
  Hyprland window tag (`scratchpad-promoted`), which is how the toggle tells it
  apart from a scratchpad you merely threw onto a real workspace by hand, and
  which survives `hyprctl reload`.
- **There is no "demote".** A promoted window is an ordinary window from then
  on; close it when you are done with it. Its replacement is already waiting on
  the special workspace.

It still will not appear in the dock, for the same class-matching reason as
above.

## Window Groups (tabs)

Stack several windows into a single tile and page between them, instead of
spending a whole workspace on windows you only glance at.

| Shortcut | Action |
|---|---|
| `Super + G` | Add the focused window to a group / pop it back out |
| `Super + Alt + G` | Lock the group — stops further windows joining it |
| `Super + [` | Previous window in the group |
| `Super + ]` | Next window in the group |

## Displays

`Super + Shift + X` toggles mirrored/extended. The arrow binds move the external
monitor around the laptop panel; the default placement is to its left.

| Shortcut | Action |
|---|---|
| `Super + Shift + X` | Toggle duplicate / extended |
| `Super + Ctrl + Shift + Left` | Place the external display to the left |
| `Super + Ctrl + Shift + Right` | Place the external display to the right |
| `Super + Ctrl + Shift + Up` | Place the external display above |
| `Super + Ctrl + Shift + Down` | Place the external display below |
| `Super + Shift + R` | **`hyprctl reload`** — panel recovery |

`Super + Shift + R` is worth knowing by feel, because by definition you cannot
see the screen when you need it: if the display is black after a resume but the
session is still alive, this re-enables the output and is the only thing that
does (see the note in `hypridle.conf`).

## Applications and Utilities

| Shortcut | Action |
|---|---|
| `Super + S` | Wofi application launcher |
| `Super + E` | yazi — the floating scratchpad (see [Scratchpads](#scratchpads)) |
| `Super + Alt + E` | yazi — a fresh **tiled** window, for browsing inside the layout |
| `Super + Shift + E` | Nautilus, for when a GTK file chooser or thumbnail grid is the better tool |
| `Super + C` | Google Chrome (new window) |
| `Super + Y` | YouTube Music — floating scratchpad |
| `Super + Shift + V` | VS Code |
| `Super + I` | Colour picker (hyprpicker) — copies the hex to the clipboard |
| `Super + F1` | GNOME Calculator |
| `Super + F2` | Emoji picker — search, categories, favourites |
| `Super + Alt + Space` | Toggle Waybar |
| `Super + Shift + A` | Stash the focused window, or bring the last stashed one back — one key, scoped to the current workspace |
| `Super + ;` | Launch Jcode home |
| `Super + '` | Launch the last Jcode project |
| `Super + Shift + '` | Launch the Jcode self-development project |

## Desktop Shell (Quickshell)

The interactive UI layer: panels, the launcher, the dock, the OSD and the
desktop widgets. Each one is a plain `exec_cmd` bind calling
`quickshell ipc call`, so these keys keep working exactly as written even if a
panel is disabled — a disabled target simply answers "unavailable" instead of
opening. List every target and function the running shell exposes with
`just qs-ipc` (or `quickshell ipc show`); bring the shell back with
`just qs-restart`.

Keys stay declared in `bindings.lua`, in the one place keys have always been
declared. Quickshell *can* register them itself through Hyprland's
global-shortcuts protocol, and deliberately does not — otherwise half the
desktop's keybindings would live in a file you would not think to grep.

| Shortcut | Action |
|---|---|
| `Super + Space` | **Workspace overview** — a rotating carousel of every workspace |
| `Super + A` | **Control Center** — Wi-Fi, Bluetooth, audio, brightness, power profile, night light |
| `Super + D` | Dashboard — clock, calendar, now playing, CPU/memory/disk/battery |
| `Super + ,` | Settings — every toggle in the shell, in one window |
| `Super + Shift + K` | **Command Center** — a searchable GUI over `~/Justfile` and the system CLI |
| `Super + Shift + W` | Wallpaper picker |
| `Super + Shift + T` | Themes — Settings on its Appearance page, where the swatches live |
| `Super + Shift + B` | Toggle the desktop audio visualizer |
| `Super + Shift + G` | Arrange the desktop widgets (drag to move; `Escape` or click the desktop to finish) |
| `Super + F2` | Emoji picker |
| `Super + M` | Power menu — log out, suspend, restart, shut down |
| `Super + Escape` | Lock the screen |

`Escape` closes any of them, and so does clicking outside. Opening one closes
whichever was already up, so two translucent panels can never overlap.

### Why none of the existing binds moved

Every shell key was checked against the rest of `bindings.lua` before it was
chosen. The deliberate near-misses, so a future edit does not "tidy" them into
a collision:

| The shell key | Means | The near-miss it avoids |
|---|---|---|
| `Super + A` | Control Center | `Super + Shift + A` is stash/unstash |
| `Super + Space` | Workspace overview | `Super + Shift + Space` floats; `Super + Alt + Space` toggles waybar |
| `Super + D` | Dashboard | used to toggle a `desktop` special workspace — that bind and the workspace are gone |
| `Super + Shift + W` | Wallpapers | `Super + W` is the workspace submap leader, untouched |
| `Super + Shift + B` | Visualiser | chosen over `Super + Shift + V`, already `code` |
| `Super + Shift + T` | Themes | `Super + W` then `T` is the `top` workspace — different leader |
| `Super + Shift + K` | Command Center | `Super + K` is focus-up and stays that way |

`Super + Shift + K` is the pattern the other two already follow: `K` is the
only mnemonic the Command Center has, so it moved one modifier across rather
than taking one of the four hjkl focus binds — the most-pressed keys on the
machine. Nothing else with `K` on it is disturbed (`Super + Alt + K` moves,
`Super + Ctrl + K` resizes, bare `K` resizes inside the `Super + R` submap, and
`Super + Shift + <digit>` is digits, not letters).

### Command Center

`Super + Shift + K`, or the KDE Connect button on waybar. **It is a page of Settings
now, not a panel of its own** — but the `commandcenter` IPC target is unchanged
and deliberately kept, so `commandcenter page|find|run|set` all still work. The
key is still a toggle: pressed with the Commands page already showing it closes
the window, and pressed while Settings is open on another page it brings you to
Commands instead of closing what you were reading.

### Locking

Every lock path goes through `~/.local/bin/lock-session`: `Super + Escape`,
hypridle's 300-second listener (via `loginctl lock-session`), its
`before_sleep_cmd`, and the shell's own Lock button. One script, one decision.

**The Quickshell lock screen is on** (`Settings.features.lockScreen`), and
`lock-session` picks it when it is enabled and the shell proves it actually
locked; hyprlock is the fallback on anything else. That it is on at all is the
result of three changes made after the session fell over while locked once —
under ext-session-lock the compositor correctly keeps the screen locked when
the lock client dies, which meant a TTY to get back in:

- the lock screen runs as **its own quickshell process**
  (`~/.config/quickshell/lock.qml`), so a fault in the dock or the visualiser
  can no longer take the locker down;
- `lock-session` **supervises** it — the lock writes
  `$XDG_RUNTIME_DIR/qs-lock-clean` on a clean unlock, and if the process exits
  without that marker hyprlock is started immediately, and retried until it
  comes up;
- `misc:allow_session_lock_restore` is **set at login** (`autostart.lua`), so a
  replacement locker can attach to a lock a dead one left behind. The session
  stays locked and still demands the password; it just no longer needs a TTY.

A crash now looks like "hyprlock appeared" instead of "reboot".

The `pidof hyprlock` test that used to guard `hypridle.conf` is gone, and with
it the blocker that kept the Quickshell locker switched off: that test could
not see a locker that was *not* hyprlock, so it launched hyprlock into an
already-locked session. `lock_cmd` is `~/.local/bin/lock-session` now and an
**flock** inside the script is what enforces one locker at a time — it covers
every entry point without having to recognise which locker is in use. (Locking
by hand does not set logind's `LockedHint`, so hypridle still fires its
listener five minutes later; the flock is what makes that a silent no-op.)

The `--grace 5` lives in `lock-session` too, applied only on the hyprlock
fallback path.

### Window controls

A cluster of three dots floats near the focused window's corner (top-right,
inset 8 px) — the macOS-style buttons, themed from `theme-switch`'s palette
rather than three hardcoded hex values. It has no keybind; it is
`Settings → Windows → controls`, or `quickshell ipc call windowcontrols
toggle`.

| Dot | Action |
|---|---|
| `×` red | Close the window |
| `−` amber | Stash it — the same mechanism as `Super + Shift + A` |
| `⬌` green | Maximize, or one step back towards normal if it is already there |

Hovering any one of them lights all three: the dots are 12 px, and hunting for
the exact one while they are still dim is not a control. The cluster hides
itself during a `Super + drag` — Hyprland emits no geometry event, so without
that it would rubber-band a frame behind the window — and the suspension
self-clears after 8 seconds, so a drag interrupted by a shell restart cannot
hide it permanently. `controlsExclude` keeps it off the scratchpads and the
share picker.

### Emoji picker

`Super + F2`. A search box, a grid, and a category strip, with a row of
favourites and recents across the top. 1376 emoji in 8 groups, generated from
Python's `unicodedata` into `modules/emoji/emoji.json` — regenerate it if the
system's Unicode version moves on.

| Key / action | Result |
|---|---|
| Type | Search by name and keywords; prefix matches rank first |
| `Enter` | Copy the first result |
| Click | Copy that emoji |
| **Right click** | Pin / unpin as a favourite |
| `Escape` | Clear the search; again to close |
| Click a category | Browse that group |

Picking an emoji **copies it** — paste it yourself. Copied with `wl-copy`, so
cliphist keeps it and `Super + V` finds it again. Favourites and recents live
in `settings.json` under `emoji`.

### Workspace overview

`Super + Space`. Every workspace as a card on a ring seen in perspective. Move
the pointer to spin it; the card at the front is the selection. Each card shows
the workspace number, its name, and an icon per window on it — a dot in the
corner marks a floating window.

Only workspaces actually in use are shown, plus the one you are standing on.
Special workspaces (the scratchpads) are excluded: they overlay what you are on
rather than being somewhere you go.

| Key / action | Result |
|---|---|
| Move the pointer | Nudge the ring, to peek either side |
| Scroll (either axis) | Step one workspace |
| `Left` / `Right` | Step one workspace |
| `1`–`9`, `0` | Jump straight to that workspace |
| `Enter` / `Space` | Switch to the front card |
| Click a card | Select it; click again to switch |
| `Escape` | Close, change nothing |

### Inside the dashboard calendar

The calendar takes the arrow keys while the dashboard is open.

| Key | Action |
|---|---|
| `Left` / `Right` | Previous / next month |
| `Up` / `Down` | Previous / next year |
| `Home` or `T` | Back to today |
| Scroll wheel | Page months |

Up is the past and down is the future, so both "back" directions are up-and-left
and both "forward" directions are down-and-right. The grid slides in the
direction of travel rather than swapping in place.

The dashboard also carries a row of quick actions — Themes, Wallpaper, Settings
and Power — which are the same IPC targets the keys above reach.

### What replaced what

Nothing below was deleted — each fallback still works if Quickshell is not
running, which matters most for the power menu.

| Old | Now | Old tool |
|---|---|---|
| `blueman-applet` (resident) | Control Center + on-demand pairing | `bt-pair` starts blueman only while pairing |
| Waybar cpu / memory pills | Dashboard | — |
| Waybar microphone, idle inhibitor, power profile | Control Center | — |
| Waybar `nm-applet` | Control Center | `nm-connection-editor` on right-click |
| Brightness / volume slider popups | Control Center | `slider-popup.py` (433 lines of GTK3) |
| Wi-Fi menu | Control Center | `wifi-menu.sh` (167 lines of shell + wofi) |
| Clock → calendar | Dashboard (drops down from the clock) | `waycal` |
| `nwg-dock-hyprland` | Quickshell dock | — |
| `nwg-drawer` | Wofi on `Super + S` | — |
| wlogout | Quickshell power menu | wlogout, then wofi |

The tray is the one thing that came back. It went away with `nm-applet` and
`blueman-applet`, but `kdeconnect-indicator` has no replacement: its menu
(ring, send file, browse device, run command, SMS) is richer than
`kdeconnect-app`'s window, and Quickshell implements no StatusNotifier host, so
with no tray the indicator ran completely invisibly. `show-passive-items` is
load-bearing there — the item goes Passive whenever no device is connected,
which is exactly when you most want to glance at it.

## Clipboard and Notifications

| Shortcut | Action |
|---|---|
| `Super + V` | Clipboard history — pick in Wofi, copies the selection |
| `Super + N` | Browse notification history in fzf; Enter reposts the notification |
| `Super + Ctrl + N` | Restore the most recently dismissed notification |

`Super + S` and `Super + V` go through the same guard script
(`scripts/wofi-launch.sh`), which serialises the decision behind an flock and
keeps exactly one wofi per mode. Before that, either key could open a second
layer surface on top of the first, both holding a keyboard grab.

Mako is the notification daemon; the shell's own notification surface is off
(`Settings.features.notifications`).

## Screenshots

Plain picks a region, `Alt` takes the whole screen; `Shift` saves to
`~/Pictures/Screenshots` instead of copying to the clipboard.

| Shortcut | Action |
|---|---|
| `Super + P` | Select an area, copy to clipboard |
| `Super + Shift + P` | Select an area, save to file |
| `Super + Alt + P` | Whole screen, copy to clipboard |
| `Super + Alt + Shift + P` | Whole screen, save to file |
| `Super + Shift + S` | Same as `Super + Shift + P` — kept for muscle memory |

### While the crosshair is up

`screenshot.sh` arms a submap for exactly as long as slurp is on screen:

| Key | Action |
|---|---|
| `Enter` (or keypad `Enter`) | Take the whole screen instead of a region |
| `Escape` | Cancel |
| `Space` | slurp's own modifier — move the selection instead of resizing it |

It has to be the compositor that catches Enter: slurp 1.5.0 reads only Escape
and Space, and neither is retargetable, while a plain global bind would have to
be non-consuming and would then fork a process on every newline typed on this
machine. There is no `catchall` here, unlike the workspaces submap — anything
not bound has to fall through to slurp untouched.

## Hardware and Media Keys

All of these are marked `locked`, so they keep working on the lock screen.
Brightness and volume repeat while held.

| Key | Action |
|---|---|
| `Brightness Down` / `Up` | Brightness ∓10% |
| `Volume Down` | Volume −5% |
| `Volume Up` | Volume +5%, capped at 100% |
| `Mute` | Toggle speaker mute |
| `Mic Mute` | Toggle microphone mute |
| `Play/Pause` | `playerctl play-pause` |
| `Next` / `Previous` | Skip track |

## The Lid

The lid is a key too: `lid.lua` binds Hyprland's native switch keys —
`switch:on:Lid Switch` when it shuts and `switch:off:...` when it opens — both
`locked`, so closing the laptop on a locked session still works. The device
name is read out of sysfs, so a machine with no lid switch registers no bind
rather than one that can never fire.

| Event | What happens |
|---|---|
| Lid closed, external attached | Internal panel **disabled**; the session continues out there |
| Lid closed, no external | Internal panel **blanked**, never disabled — with zero outputs there is no screen to get back to |
| Lid closed | Session locked, camera disabled |
| Lid opened | Internal panel back on |

`scripts/lid.sh` derives every action from state rather than from the event: it
reads the lid's actual position out of sysfs and the actual monitor list out of
Hyprland, and makes the world match. That is what makes a flapping lid, a lid
already shut when Hyprland started, and an external unplugged while the lid is
shut all one code path — `lid.lua` also calls it on startup and on
monitor added/removed.

logind's three `HandleLidSwitch*` keys are all set to `ignore`
(`/etc/systemd/logind.conf.d/10-lid-ignore.conf`), which is what stops it
suspending the machine out from under a build. But `ignore` means logind does
*nothing*, and nothing is not the same as the right thing — everything it
leaves undone is what `lid.sh` does. Each piece is a toggle in
`Settings → Lid`: lock on close, disable the internal panel, disable the
camera, keep the session on an external. All four are on.

## The Touchscreen

Another switch bind, and the only one that exists for a performance reason.

`touchscreen.lua` finds tablet-mode switches the same way `lid.lua` finds the
lid — by capability bitmap, not by name. An input device *is* a tablet switch if
it advertises `SW_TABLET_MODE` (bit 1 of `capabilities/sw`), which is a
different device from `Lid Switch` (`sw = 1`): on a flip convertible the lid
switch says the screen is shut, the tablet switch says it has been folded all
the way back.

It binds **every** candidate rather than picking one, and this machine is the
reason. Two devices advertise `SW_TABLET_MODE` and only one of them works:

| Device | Driver | Reports folds? |
|---|---|---|
| `HP WMI hotkeys` | `hp_wmi` | **No** — advertises the capability, never drives it |
| `Intel HID switches` | `intel_hid` (`INTC107B:00`) | **Yes** |

Worse, the one that works *does not exist at login*. `intel_hid` registers it
lazily, on the first fold:

```
intel-hid INTC107B:00: switch event received, enable switches supports
input: Intel HID switches as /devices/platform/INTC107B:00/input/input62
```

So a pure capability scan at config-parse time can only ever find the broken
one. `KNOWN_LATE_SWITCHES` in `touchscreen.lua` pre-registers the Intel name so
the first fold of a session works; binding a name that is not present is inert
in Hyprland, so it costs nothing. This is the one place a device name is
hardcoded rather than derived, because no capability is readable before the
device exists — `lid.lua`'s "register no bind rather than one that can never
fire" rule deliberately does not apply, since this bind *can* fire, just not
yet.

(`intel_vbtn` would be the usual driver for this on an Intel convertible —
`INT33D6:00` is present and `chassis_type` is 31 — but it is unbound and not
needed, because `intel_hid` already does the job. Not worth the moving part.)

| Event | What happens |
|---|---|
| Folded to tablet / tent mode | Digitizer **attached** — touch works |
| Opened back to laptop mode | Digitizer **detached** — costs nothing |
| `Super + Shift + D` | Toggle it by hand, either way |
| Session start | Settles on `START_ENABLED` (currently **off**) |

Both switch binds are `locked`, because folding the machine on a locked session
is exactly when touch is needed and there is no reachable keyboard to ask for it.

### Why the touchscreen is off by default

Measured, not assumed. While the digitizer's driver is attached, with nothing
touching the panel:

| | |
|---|---|
| `i2c_designware.2` (IRQ 20) | **41,601 interrupts/sec**, sustained |
| Total since boot | 2.06 billion in 13.8 h — lifetime average 41,678/s, i.e. constant from boot |
| Touchpad's bus, for scale | 12 M against the touchscreen bus's 2.06 B |

The cost is not mainly CPU percentage. IRQ 20 is serviced by cpu2, and cpu2 was
entering `C1` — the *shallowest* idle state — 31,975 times a second while
reaching the deep states essentially never (`C2` 3/sec, `C3` 2/sec). cpu0 over
the same window: `C1` 792/s, `C2` 813/s, `C3` 231/s. One of eight cores was
permanently held out of deep idle. Detaching the driver took IRQ 20 to **0/sec**
and cpu2's `C3` entries from 2/sec to **226/sec** — straight back to cpu0's
profile.

The underlying fault looks like the digitizer never being told to sleep: it
emits **620 HID reports/sec** with nobody touching it (the 41.6 k is ~67
controller FIFO interrupts per report), and `i2c-hid` only sends
`SET_POWER(SLEEP)` when the HID device runtime-suspends, which cannot happen
while libinput holds an input node open — which it does for the whole session.
So it is not the `BOGUS_IRQ` quirk, and `i2c_hid` exposes no module parameters
to tune. Nothing makes it cheap *while attached*, which is why the policy is
about **when** it is attached rather than how much it costs.

`scripts/touchscreen-toggle.sh` holds the policy; `scripts/touchscreen.sh` is
the one privileged part (binding a driver means writing to `/sys`) and is
installed root-owned behind a five-line sudoers drop-in by
`sudo ~/.config/hypr/scripts/install-touchscreen.sh` — the same shape as the lid
camera guard. Set `START_ENABLED = true` in `touchscreen.lua` for touch from
login, at the cost in the table above.

## Touchpad

- **Three-finger horizontal swipe** — slide between workspaces. The workspace
  tracks your fingers directly; release past 30% of the swipe distance (or flick
  fast) to commit. Keep swiping without lifting to cross several workspaces.
- Touchpad scrolling is natural; mouse scrolling is not.

## Waybar (mouse)

The right-hand side is one grouped pill now — network, CPU temperature, volume
and brightness read as a single unit rather than four separate islands, and
every one of them opens the same Control Center that `Super + A` does. The bar
is status; the shell is where you change things.

| Module | Left click | Right click | Middle click | Scroll |
|---|---|---|---|---|
| Launcher `󰣇` | Quickshell launcher | — | — | — |
| Workspaces | Activate | — | — | — |
| Todo | Toggle the todo scratchpad | Jump to the todo workspace | — | — |
| Window title | — | — | — | — |
| Clock | **Dashboard**, dropping down from the clock | — | — | — |
| KDE Connect `󰦉` | **Command Center** | `kdeconnect-app` | Ring the phone | — |
| Network | Control Center | nm-connection-editor | — | — |
| Temperature | Control Center | — | — | — |
| Volume | Control Center | Toggle mute | pavucontrol | ∓5% (capped at 100%) |
| Brightness | Control Center | — | — | ∓5% |
| Battery | Control Center | — | — | — |
| Tray | `kdeconnect-indicator`'s own menu | — | — | — |

The KDE Connect button replaced the tray's position rather than sitting beside
it — two buttons for one corner of the bar was the wrong answer, and the tray
could not simply be retargeted because it is a StatusNotifier *host*, not a
module with a command. The indicator's richer menu is still there, in the tray
that now sits to its right.

Opened from the clock the dashboard drops straight down out of the bar; opened
from `Super + D` it comes in at the top right. Same panel either way — only
where it lands differs, so the gesture that opened it is the one it appears to
come from.

### On-screen display

Volume, brightness and mute changes raise a small OSD rather than a
notification, whether the change came from a media key, a scroll on the bar or
the Control Center. It fades on its own and takes no input.

### Dock (mouse)

| Action | Result |
|---|---|
| Left click | Launch, or focus the running window |
| **Right click** | Pin / unpin, reorder a pinned app, open a new window, close all windows |
| Hover the bottom edge | Reveal the dock (when visibility is `auto`) |

Pin order is the order in the dock, and the menu's Move left / Move right
change it. A pinned app that is also running is still one tile.

### Desktop widgets

Clock, calendar, now playing, network, processor, memory and battery sit on the
wallpaper. They disappear entirely when a window covers the wallpaper, which
also stops the `/proc` reads behind the gauges.

All of them are click-through except the media widget — a decorative widget
that eats a click meant for the desktop is worse than no widget, but a play
button you cannot press is not a player. Only the media widget's rectangle is
punched out of the click-through mask:

| On the media widget | Action |
|---|---|
| Play / pause / skip | Control the player |
| Drag the seek bar | Scrub; click anywhere on it to jump |
| Click the artwork | Raise the player's window |
| Scroll | Volume ∓3% |

`Super + Shift + G` lifts them above your windows so they can be dragged.
Positions are saved as screen fractions, so a widget parked at the top right of
the laptop panel is still at the top right of the external monitor.

| Key / click | Action |
|---|---|
| Drag a widget | Move it; it snaps to the grid on release |
| `Escape`, click the desktop, or **Done** | Finish arranging |
| **Reset** | Put every widget back where it started |

Which widgets exist is Settings → Desktop.

## Mako notifications (mouse)

| Action | Result |
|---|---|
| Left click | Invoke the default action |
| Middle click | Action menu in Wofi |
| Right click | Dismiss |

Per-app overrides: notifications from Ghostty, Chrome/Chromium and Firefox focus
that window on left click instead, and the Battery and Temperature ones just
dismiss — there is nothing to open.

---

## Ideas not yet implemented

Deliberately unbuilt — each is a migration with a muscle-memory cost, so they
are written down rather than applied. Roughly in order of payoff.

### 1. `Super + Shift` is still a junk drawer

It carries window ops, workspace-moves, app launches, screenshots, display
layout, shell panels and a compositor reload — seven unrelated meanings on one
modifier. Everything below is really a consequence of fixing this. The target
scheme:

| Modifier | Means |
|---|---|
| `Super` | focus / go to |
| `Super + Shift` | act on the focused window |
| `Super + Alt` | launch an app |
| `Super + Ctrl` | adjust (resize, nudge) |

`Super + Shift + D` (touchscreen) is a new instance of exactly this problem: it
is a hardware toggle, not an operation on the focused window. Under the scheme
above it would belong with the other hardware keys, next to the brightness and
volume controls, rather than on `Super + Shift` at all.

### 2. Complete the `hjkl` grid

Focus is `Super + hjkl`, resize is `Super + Ctrl + hjkl` — but *moving* a window
is on `Super + Alt + hjkl`, which breaks the pattern and keeps `Super + Alt`
from being purely "launch". Moving window-moving to `Super + Shift + hjkl` makes
the three rows read focus / move / resize, and empties the `Alt` row for apps —
where `Alt + E` and `Alt + G` already live.

Blocked on: `Super + Shift + H` is the todo scratchpad (see 4), and
`Super + Shift + K` is the Command Center.

### 3. Pair launch keys with workspace keys

Same letter, different modifier — `Super + Alt + C` launches Chrome,
`Super + W` `G` goes to its workspace. Today Chrome launches on `Super + C` but
its workspace is `G`, while `Super + W` `C` is the *Claude Desktop* workspace —
so `C` already means two different apps depending on the leader. Brave has a
workspace on `B` with no launch key at all.

### 4. Scratchpads sit on five unrelated keys

`` Super + ` `` (terminal), `Super + E` (files), `Super + Y` (music),
`Super + O` (WhatsApp), `Super + Shift + H` (todo). The todo one is the odd one
out *and* it is squatting on the `hjkl` grid that item 2 needs.

`Super + T` used to be the obvious home for it and is now "tile the focused
window", so this needs a different key. `Super + U` and `Super + Z` are the
free ones left; neither is a mnemonic for a todo list, which is the real reason
this has not moved.

### 5. `N` means three different things

`Super + N` is notification history, `Super + Ctrl + N` restores the last
notification, and `Super + W` `N` is the nvim workspace. The first two belong
together; the third is unrelated and only shares the letter.

### 6. Arrows duplicate `hjkl`

`Super + Up/Down` do exactly what `Super + K/J` do. Freeing them gives two easy
keys — maximize / restore would be a natural home.

### 7. Keys currently free

- **`Super`**: `B U X Z`
- **`Super + Shift`**: `D I J L N O Q U Y Z`

`Super + Shift + D` came free when the dashboard moved to `Super + D`. Since
the last pass, `T` went to tiling and `Super + Shift + K` to the Command
Center, so the two shortest lists each lost a letter.

The shell migration took `A` (Control Center), `Space` (overview), `,`
(Settings) and `Shift + B/G/K/T/W` (visualizer, widgets, Command Center, theme,
wallpaper), so this drawer is still a good deal emptier than it was.

Obvious remaining candidate: `B` for the bar, which is today on
`Super + Alt + Space`.

### Non-keymap leftovers

- **`.docx` / `.pptx` open in Chrome but do not render.** Chrome cannot display
  Office files locally without the *Office Editing for Docs, Sheets & Slides*
  extension, which is not installed — as things stand it downloads them instead.
  Install that extension, or point those extensions at LibreOffice (already the
  system default) in `~/.config/hypr/scripts/open-file.sh`.
- **Ghostty's own `background-blur`** was left alone on purpose. It would be
  cheaper than compositor blur, but it changes the look, and keeping the current
  appearance was the priority.
- **More scratchpads are one table entry** in `~/.config/hypr/scratchpads.lua`
  now — a calculator or a notes buffer would cost three lines.
- **`binds.workspace_back_and_forth`** would make a workspace key pressed twice
  return you to the previous one, which pairs well with `Super + Tab`.
