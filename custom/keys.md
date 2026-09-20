# Keyboard Shortcuts

Everything bound across the Hyprland session and the Wayland tools around it.
Generated from `~/.config/hypr/bindings.lua`, `~/.config/hypr/scratchpads.lua`,
`~/.config/hypr/input.lua`, `~/.config/waybar/config.jsonc`,
`~/.config/quickshell/shell.qml` and `~/.config/mako/config`.

Hyprland is still the whole behaviour layer — every key below is declared in
`bindings.lua` and nowhere else. The Quickshell keys are ordinary
`exec_cmd` binds that call `quickshell ipc call <target> <function>`, so the
shell never registers a global shortcut of its own and `hyprctl binds` remains
the single source of truth.

## Conventions

- `Super` is the Windows/Meta key (`mainMod = SUPER`).
- **Caps Lock and Escape are swapped** (`kb_options = caps:swapescape`), so the
  Caps Lock key sends Escape.
- Key repeat is fast and eager: 40 Hz after a 250 ms delay.
- Terminal is Ghostty, file manager is Nautilus. **Wofi is the launcher**, on
  `Super + S`, and is what `Super + V` pipes clipboard history through. The
  Quickshell launcher still exists and still answers
  `quickshell ipc call launcher toggle`, but it is deliberately unbound —
  `Super + Space` went to the workspace overview instead.
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
| `Super + M` | Power menu (Lock / Logout / Restart / Shutdown) |
| `Super + Escape` | Lock the screen with Hyprlock (Caps Lock sends Escape, so `Super + CapsLock` works too) |
| `Super + F` | Toggle fullscreen |
| `Super + Shift + F` | Toggle maximized — fills the monitor but keeps gaps, borders and the bar |
| `Super + Shift + Space` | Toggle floating |
| `Super + Shift + C` | Center the focused window |
| `Super + Shift + M` | Send the focused window to the next monitor (wraps) |
| `Alt + Tab` | Cycle to the next window |

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
| `Super + left-drag` | Move a floating window |
| `Super + right-drag` | Resize a floating window |

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
no modifier held:

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
| `T` or `Enter` | `tmux` | Ghostty attached to tmux session `default` |
| `N` | `nvim` | Neovim in Ghostty |
| `M` | `top` | btop in Ghostty ("monitor") |
| `G` | `chrome` | Google Chrome (new window) |
| `B` | `brave` | Brave (new window) |
| `D` | `debug` | Nothing — bare workspace |
| `Escape` / `Q` | — | Back out, do nothing |

Any other key also backs out silently (a `catchall` bind), so a mistype cannot
strand you in the submap.

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

None of them appear in the dock, wherever they happen to be sitting —
`Settings.dock.exclude` matches them by window class, so a scratchpad dragged
onto a real workspace still stays out of the dock.
| `Super + Shift + H` | `special:todo` | hyprtodo | fills the workspace | Yes |

Quitting a scratchpad (exiting the shell, `q` in yazi, closing the PWA window)
is harmless: the next press of its key starts it again.

If one of these apps is already running somewhere else — a YouTube Music window
you opened before, or a scratchpad you deliberately threw onto a real workspace
— its key pulls it back onto its special workspace rather than opening a second
copy.

All five are declared in one table in `~/.config/hypr/scratchpads.lua`; adding
another is a single entry there, and `prespawn = true` is what decides whether
it starts at login.

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
opening.

| Shortcut | Action |
|---|---|
| `Super + Space` | **Workspace overview** — a rotating carousel of every workspace |
| `Super + A` | **Control Center** — Wi-Fi, Bluetooth, audio, brightness, power profile, night light |
| `Super + D` | Dashboard — clock, calendar, now playing, CPU/memory/disk/battery |
| `Super + ,` | Settings — every toggle in the shell, in one window |
| `Super + Shift + W` | Wallpaper picker |
| `Super + Shift + T` | Theme switcher |
| `Super + Shift + B` | Toggle the desktop audio visualizer |
| `Super + Shift + G` | Arrange the desktop widgets (drag to move; `Escape` or click the desktop to finish) |
| `Super + M` | Power menu — log out, suspend, restart, shut down |
| `Super + Escape` | Lock the screen |

`Super + D` used to toggle a `desktop` special workspace; that bind and the
workspace are gone.

### Locking

`Super + Escape` goes through `~/.local/bin/lock-session`. **hyprlock is the
locker.** hypridle also calls hyprlock directly for idle and sleep, so the
automatic path never depends on the shell.

There is a Quickshell lock screen in the tree, and it is **off**. It was on for
one afternoon; the session fell over while locked, and under ext-session-lock
the compositor correctly keeps the screen locked when the lock client dies —
which meant a TTY to get back in. Three things changed after that:

- the lock screen moved into **its own quickshell process**
  (`~/.config/quickshell/lock.qml`), so a fault in the dock or the visualiser
  can no longer take the locker down;
- `lock-session` **supervises** it — the lock writes a marker on a clean
  unlock, and if the process exits without one, hyprlock is started
  automatically;
- `misc:allow_session_lock_restore` is **set at login** (`autostart.lua`), so a
  replacement locker can attach to a lock a dead one left behind. The session
  stays locked and still demands the password; it just no longer needs a TTY.

One blocker remains before it is safe to turn back on. `hypridle.conf` runs
`pidof hyprlock || hyprlock --grace 5` five minutes into idle; with the
Quickshell locker holding the session that test fails, so hyprlock launches
into an already-locked session. `lock_cmd` has to become
`~/.local/bin/lock-session` first.


`Escape` closes any of them, and so does clicking outside. Opening one closes
whichever was already up, so two translucent panels can never overlap.

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

### What replaced what

Nothing below was deleted — each fallback still works if Quickshell is not
running, which matters most for the power menu.

| Old | Now | Old tool |
|---|---|---|
| `blueman-applet` (resident) | Control Center + on-demand pairing | `bt-pair` starts blueman only while pairing |
| Waybar cpu / memory pills | Dashboard | — |
| Waybar microphone, idle inhibitor, power profile | Control Center | — |
| Waybar tray + `nm-applet` | Control Center | `nm-connection-editor` on right-click |
| Brightness / volume slider popups | Control Center | `slider-popup.py` (433 lines of GTK3) |
| Wi-Fi menu | Control Center | `wifi-menu.sh` (167 lines of shell + wofi) |
| Clock → calendar | Dashboard (drops down from the clock) | `waycal` |
| `nwg-dock-hyprland` | Quickshell dock | — |
| `nwg-drawer` | Wofi on `Super + S` | — |
| wlogout | Quickshell power menu | wlogout, then wofi |

## Clipboard and Notifications

| Shortcut | Action |
|---|---|
| `Super + V` | Clipboard history — pick in Wofi, copies the selection |
| `Super + N` | Browse notification history in fzf; Enter reposts the notification |
| `Super + Ctrl + N` | Restore the most recently dismissed notification |

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
| Network | Control Center | nm-connection-editor | — | — |
| Temperature | Control Center | — | — | — |
| Volume | Control Center | Toggle mute | pavucontrol | ∓5% (capped at 100%) |
| Brightness | Control Center | — | — | ∓5% |
| Battery | Control Center | — | — | — |

Opened from the clock the dashboard drops straight down out of the bar; opened
from `Super + Shift + D` it comes in at the top right. Same panel either way —
only where it lands differs, so the gesture that opened it is the one it appears
to come from.

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

Clock, now playing, network, processor, memory and battery sit on the
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
that window on left click instead.

---

## Ideas not yet implemented

Deliberately unbuilt — each is a migration with a muscle-memory cost, so they
are written down rather than applied. Roughly in order of payoff.

### 1. `Super + Shift` is still a junk drawer

It carries window ops, workspace-moves, app launches, screenshots and display
layout — five unrelated meanings on one modifier. Everything below is really a
consequence of fixing this. The target scheme:

| Modifier | Means |
|---|---|
| `Super` | focus / go to |
| `Super + Shift` | act on the focused window |
| `Super + Alt` | launch an app |
| `Super + Ctrl` | adjust (resize, nudge) |

### 2. Complete the `hjkl` grid

Focus is `Super + hjkl`, resize is `Super + Ctrl + hjkl` — but *moving* a window
is on `Super + Alt + hjkl`, which breaks the pattern and keeps `Super + Alt`
from being purely "launch". Moving window-moving to `Super + Shift + hjkl` makes
the three rows read focus / move / resize, and empties the `Alt` row for apps —
where `Alt + E` and `Alt + G` already live.

Blocked on: `Super + Shift + H` is the todo scratchpad (see 4).

### 3. Pair launch keys with workspace keys

Same letter, different modifier — `Super + Alt + C` launches Chrome,
`Super + W` `G` goes to its workspace. Today Chrome launches on `C` but its
workspace is `G`, and Brave has a workspace with no launch key at all.

### 4. Scratchpads sit on five unrelated keys

`` Super + ` `` (terminal), `Super + E` (files), `Super + Y` (music),
`Super + O` (WhatsApp), `Super + Shift + H` (todo). The todo one is the odd one
out *and* it is squatting on the `hjkl` grid that item 2 needs. `Super + T` is
free and would fit the set.

### 5. `N` means three different things

`Super + N` is notification history, `Super + Ctrl + N` restores the last
notification, and `Super + W` `N` is the nvim workspace. The first two belong
together; the third is unrelated and only shares the letter.

### 6. Arrows duplicate `hjkl`

`Super + Up/Down` do exactly what `Super + K/J` do. Freeing them gives two easy
keys — maximize / restore would be a natural home.

### 7. Keys currently free

- **`Super`**: `B T U X Z`
- **`Super + Shift`**: `D I J K L N O Q U Y Z`

`Super + Shift + D` came free when the dashboard moved to `Super + D`. `O` went
to the WhatsApp scratchpad, and `Space` to the workspace overview.

Obvious remaining candidates: `T` for the todo scratchpad per item 4, `B` for
the bar (today `Super + Alt + Space`).

The shell migration took `A` (Control Center), `Space` (launcher), `,`
(Settings) and `Shift + B/D/G/T/W` (visualizer, dashboard, widgets, theme,
wallpaper), so this drawer is a good deal emptier than it was.

Obvious remaining candidates: `O` for a general "open", `T` for the todo
scratchpad per item 4.

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
