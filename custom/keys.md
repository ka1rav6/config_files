# Keyboard Shortcuts

Everything bound across the Hyprland session and the Wayland tools around it.
Generated from `~/.config/hypr/bindings.lua`, `~/.config/hypr/scratchpads.lua`,
`~/.config/hypr/input.lua`, `~/.config/waybar/config.jsonc` and
`~/.config/mako/config`.

## Conventions

- `Super` is the Windows/Meta key (`mainMod = SUPER`).
- **Caps Lock and Escape are swapped** (`kb_options = caps:swapescape`), so the
  Caps Lock key sends Escape.
- Key repeat is fast and eager: 40 Hz after a 250 ms delay.
- Terminal is Ghostty, launcher is Wofi, file manager is Nautilus.
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

Special workspaces overlay the current one instead of replacing it:

| Shortcut | Workspace | Contents |
|---|---|---|
| `Super + D` | `special:desktop` | Bare overlay workspace, nothing pre-loaded |

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
| `Super + Shift + H` | `special:todo` | hyprtodo | fills the workspace | Yes |

Quitting a scratchpad (exiting the shell, `q` in yazi, closing the PWA window)
is harmless: the next press of its key starts it again.

If one of these apps is already running somewhere else — a YouTube Music window
you opened before, or a scratchpad you deliberately threw onto a real workspace
— its key pulls it back onto its special workspace rather than opening a second
copy.

All four are declared in one table in `~/.config/hypr/scratchpads.lua`; adding
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
| `Super + Alt + Space` | Toggle Waybar |
| `Super + Shift + A` | Minimize the focused window |
| `Super + Shift + B` | Restore the oldest minimized window |
| `Super + ;` | Launch Jcode home |
| `Super + '` | Launch the last Jcode project |
| `Super + Shift + '` | Launch the Jcode self-development project |

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

| Module | Left click | Right click | Middle click | Scroll |
|---|---|---|---|---|
| Launcher `󰣇` | nwg-drawer | — | — | — |
| Workspaces | Activate | — | — | — |
| Todo | Toggle the todo scratchpad | Jump to the todo workspace | — | — |
| Brightness | Slider popup | — | — | ∓5% |
| Volume | Slider popup | Toggle mute | pavucontrol | ∓5% (capped at 100%) |
| Microphone | Slider popup | Toggle mute | — | ∓5% |
| Network | nm-connection-editor | — | — | — |
| Clock | waycal | — | — | — |
| Power `󰐥` | Power menu | — | — | — |

### Slider popups

Clicking brightness, volume or the microphone opens a slider card under the bar,
centered on the cursor. Inside it:

| Key | Action |
|---|---|
| Drag / scroll the slider | Change the level live |
| `Left` / `Right` | Nudge by 1% |
| Type a number + `Enter` | Jump to that exact percentage |
| `M` | Toggle mute (volume and microphone only) |
| `Escape` or `Enter` | Close |

It also closes when you click elsewhere, when you click the same module again,
or after 5 seconds if you never interact with it.

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

### 4. Scratchpads sit on four unrelated keys

`` Super + ` `` (terminal), `Super + E` (files), `Super + Y` (music),
`Super + Shift + H` (todo). The todo one is the odd one out *and* it is squatting
on the `hjkl` grid that item 2 needs. `Super + T` is free and would fit the set.

### 5. `N` means three different things

`Super + N` is notification history, `Super + Ctrl + N` restores the last
notification, and `Super + W` `N` is the nvim workspace. The first two belong
together; the third is unrelated and only shares the letter.

### 6. Arrows duplicate `hjkl`

`Super + Up/Down` do exactly what `Super + K/J` do. Freeing them gives two easy
keys — maximize / restore would be a natural home.

### 7. Keys currently free

- **`Super`**: `A B O T U X Z`
- **`Super + Shift`**: `D G I J K L N O Q R T U W Y Z`

Obvious candidates: `B` for the bar (today `Super + Alt + Space`), `O` for a
general "open", `T` for the todo scratchpad per item 4.

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
