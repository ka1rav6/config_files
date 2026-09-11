# wlogout — the power menu

Opened from waybar's power button (`custom/power` →
`~/.config/waybar/scripts/power-menu.sh`) and by the Hyprland keybinding in
`~/.config/hypr/bindings.lua`.

## Why the documentation lives here and not in `layout`

`layout` is parsed by json-glib in **strict** JSON mode. It accepts neither
`//` nor `#` comments — either one makes the whole file fail with
`WARNING: Invalid JSON Data` and the menu comes up empty. That is verified
behaviour, not caution: both forms were tested against this exact wlogout
build and both failed.

So `layout` stays comment-free and this file carries the explanation.

## Format of `layout`

A stream of JSON objects, **not** a JSON array — no enclosing `[ ]`, no commas
between objects. Each object is one button, rendered in file order:

| Key       | Meaning |
|-----------|---------|
| `label`   | The CSS selector name. `#lock`, `#logout` … in `style.css` match these, and each also picks the button's background icon. Renaming a label without renaming its CSS rule leaves the button unstyled. |
| `action`  | Shell command run when the button is activated. |
| `text`    | Visible caption. The leading glyph is a Nerd Font icon, so a terminal or editor without a Nerd Font shows a placeholder box — that is a font issue, not a corrupted file. |
| `keybind` | Single key that triggers the button directly. |

## The buttons

| Button   | Key | Action | Notes |
|----------|-----|--------|-------|
| Lock     | `l` | `hyprlock` | Config in `~/.config/hypr/hyprlock.conf`. |
| Logout   | `e` | `hyprctl dispatch 'hl.dsp.exit()'` | **Lua-config syntax.** Under Hyprland's Lua config, `hyprctl dispatch` evaluates its argument as Lua, so the older bare `exit` form silently fails to parse. Same reason the dispatches in `hypridle.conf` and `waybar/config.jsonc` are written this way. |
| Suspend  | `u` | `systemctl suspend` | `hypridle` also triggers this after 15 min idle. |
| Restart  | `r` | `systemctl reboot` | |
| Shutdown | `s` | `systemctl poweroff` | |

## Editing safely

After any change, confirm the file still parses before relying on it:

```bash
python3 -c "import json,sys; d=open('/home/kairav/.config/wlogout/layout').read(); [json.loads(o+'}') for o in d.split('}')[:-1]]; print('layout parses OK')"
```

Styling — colours, radius, the 2×3 grid — is in `style.css` alongside this file.
