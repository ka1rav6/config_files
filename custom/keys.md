# Keyboard Shortcuts

Everything bound across the Hyprland session and the Wayland tools around it.
Generated from `~/.config/hypr/bindings.lua`, `~/.config/hypr/input.lua`,
`~/.config/waybar/config.jsonc` and `~/.config/mako/config`.

## Conventions

- `Super` is the Windows/Meta key (`mainMod = SUPER`).
- **Caps Lock and Escape are swapped** (`kb_options = caps:swapescape`), so the
  Caps Lock key sends Escape.
- Key repeat is fast and eager: 40 Hz after a 250 ms delay.
- Terminal is Ghostty, launcher is Wofi, file manager is Nautilus.

> **Careful:** `Super + L` focuses the window to the right — it does **not**
> lock the screen. Locking is `Super + Shift + L`.

## Session and Windows

| Shortcut | Action |
|---|---|
| `Super + Enter` | Open Ghostty |
| `Super + Q` | Close the focused window |
| `Alt + F4` | Close the focused window |
| `Super + M` | Power menu (Lock / Logout / Restart / Shutdown) |
| `Super + Shift + L` | Lock the screen with Hyprlock |
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

Named workspaces launch their app if the workspace is empty. Pressing the same
shortcut again returns you to the previous workspace.

| Shortcut | Workspace | Launches |
|---|---|---|
| `Super + Shift + Enter` | `tmux` | Ghostty attached to tmux session `default` |
| `Super + Shift + N` | `nvim` | Neovim in Ghostty |
| `Super + Shift + T` | `top` | btop in Ghostty |
| `Super + Shift + G` | `chrome` | Google Chrome (new window) |
| `Super + Shift + R` | `brave` | Brave (new window) |
| `Super + Shift + D` | `debug` | Nothing — bare workspace |

Special workspaces overlay the current one instead of replacing it:

| Shortcut | Workspace | Contents |
|---|---|---|
| `Super + D` | `special:desktop` | Scratchpad-style desktop |
| `Super + Shift + H` | `special:todo` | hyprtodo, pre-spawned at startup |
| `Super + Alt + T` | `special:scratch` | Scratchpad Ghostty, pre-spawned at startup |

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
| `Super + E` | Nautilus |
| `Super + C` | Google Chrome (new window) |
| `Super + Shift + V` | VS Code |
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

| Shortcut | Action |
|---|---|
| `Super + P` | Select an area and copy it to the clipboard |
| `Super + Shift + S` | Select an area and save it to `~/Pictures/Screenshots` |

`~/.config/hypr/scripts/screenshot.sh` also supports `full` and `full-save` for
whole-screen capture, but neither is currently bound to a key.

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
