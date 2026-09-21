# sioyek setup

    ~/.config/sioyek/
      prefs_user.config    theme, behaviour, custom command definitions
      keys_user.config     vim keybindings  (the cheatsheet is generated from this)
      scripts/             the custom commands
      backup-*/            your pre-existing config, saved before this setup

    ~/.local/share/sioyek/
      help/                generated cheatsheet PDF + build log
      backups/             database snapshots from <C-S-b>

## Known limits of Ubuntu's sioyek 2.0.0 build

Two things in the upstream docs do not work in `2.0.0+dfsg-4build2`:

**`new_command` never executes.** sioyek parses the definition and will bind
the name to a key — the startup log even confirms the binding — but it never
spawns the process. Verified with a minimal probe (`new_command _probe
/path/touch-a-file.sh`) bound to `<F2>`: the key is delivered (other `<F2>`
bindings fire), the command is registered, the file is never created. Also
fails via tab-separated syntax, with `enable_experimental_features 1`, via
`--execute-command`, and via the older `execute_command_*` +
`execute_predefined_command` route. So all seven custom commands are
commented out in the configs rather than left as keys that do nothing.

**`startup_commands` never runs.** Dark mode is therefore set with the
deprecated `default_dark_mode 1` instead. Smooth scrolling has no
preference at all — only the `toggle_smooth_scroll_mode` command — so it
must be switched on per session with `<A-s>`.

## The cheatsheet

Generated from `keys_user.config`, so it cannot go stale — two pages of your
bindings, then an index of every command. Build and open it from a shell:

    ~/.config/sioyek/scripts/help.sh /usr/bin/sioyek

It rebuilds automatically when `keys_user.config` is newer than the PDF.

## Editing config

`g,` opens `prefs_user.config`, `g.` opens `keys_user.config`,
then `<A-r>` reloads both without restarting sioyek.
The shipped defaults are `prefs` / `keys` in the `:` palette.

After editing keys, run `scripts/check-keys.sh`. It boots a throwaway sioyek
in its own IPC namespace (so your open window is untouched) and reports the
warnings sioyek prints at load time.

## Scripts

| script                 | command              | key       |
|------------------------|----------------------|-----------|
| `help.sh`              | `_help`              | `<C-h>`   |
| `gen-cheatsheet.py`    | `_rebuild_help`      | palette   |
| `copy-clean.sh`        | `_copy_clean`        | `Y`       |
| `cite.sh`              | `_cite`              | `gc`      |
| `export-highlights.py` | `_export_highlights` | `ge`      |
| `backup.sh`            | `_backup`            | `<C-S-b>` |
| `reveal.sh`            | `_reveal`            | `gf`      |
| `check-keys.sh`        | —  (run from a shell) | —        |

The key column is what these *would* use on a build where `new_command`
works. On this build, run them from a shell — each takes the sioyek binary
path first, then its own arguments, e.g.

    ~/.config/sioyek/scripts/backup.sh /usr/bin/sioyek \
        ~/.local/share/sioyek/local.db ~/.local/share/sioyek/shared.db

They report back through sioyek's status bar via
`--execute-command set_status_string`, which does work.

## Notes

- **A shorter binding kills every longer one.** `/etc/sioyek/keys.config`
  binds `]` to `portal_to_definition`, which makes `]]` and `]h` permanently
  unreachable. A user file can override a key but cannot *remove* one —
  `<unbound>` does not free it. So chapters are `gj`/`gk`, not `]]`/`[[`.
- **Never use a bare `<` or `>` as a key.** `g<` misparses into a terminal
  `g` sequence that silently swallows every `g`-binding defined after it.
- Sioyek prints ~11 override warnings at startup. They are deliberate — each
  displaced default has a new home (`add_highlight` moved to `H`, `search` to
  `/`, `goto_portal` to `<tab>`, `goto_top_of_page` to `zt`, `next_chapter`
  to `gj`). `should_warn_about_user_key_override` does not suppress them in
  2.0.0; setting it to 0 changes nothing.
- `<C-f>` is "forward one page" (vim), not find. Search is `/`.
- Highlight colours are the stock 26 (`highlight_color_a..z` in the defaults);
  `H` then a letter picks one.
