# HyprTodo

Keyboard-first task dashboard for Hyprland. Real Rust/Tauri + Svelte source,
audited and SQL-tested against real SQLite (see below) but **not compiled**
by the assistant that wrote it — no network/toolchain in that sandbox.
Build it and paste back any error.

## Features

- SQLite-backed tasks + categories, shared by the GUI and `hyprtodo-cli`
- Dashboard: one panel per category + a synthetic "Critical" panel
- **Lua config** (`~/.config/hyprtodo/config.lua`, falls back to bundled
  default): define/rename categories and set column count, sandboxed VM
  (no `io`/`os`/`require`)
- **Tiling-manager-style layout**: change column count live, reorder panels
  with Ctrl+h/l
- Add/rename categories from the keyboard, no config-file editing required
- Full keyboard nav; **Shift+H** shows every shortcut

## Keybindings

| Key | Action |
|---|---|
| `j`/`k`, `↑`/`↓` | move focus within a panel |
| `h`/`l`, `←`/`→`, `Tab`/`Shift+Tab` | move between panels |
| `Ctrl+h` / `Ctrl+l` | reorder the focused panel left/right |
| `1`-`9` | jump to panel N |
| `Space`/`c` | toggle complete |
| `a` | add task | `A` | add category | `r` | rename category | `d` | delete task |
| `-` / `=` | fewer / more columns |
| `Shift+H` | show all shortcuts | `Esc` | close overlay |

## Configuring

Copy `config/default.lua` to `~/.config/hyprtodo/config.lua` and edit:

```lua
category("research", { name = "Research", icon = "󰂺", color = "#d29922" })
columns(3)
```

Runs on every launch and upserts each category by its `id`, so re-running never
duplicates anything. Lua only adds or updates; it never deletes. A category
deleted in-app is recreated if its `category(...)` line remains in the config;
a category removed from the config remains in the database. In-app renames and
reordering survive the next reload. The Lua VM removes `io`, `os`, `require`,
`dofile`, and `loadfile`, so config code cannot access files or run commands.
If Lua fails, startup continues with the categories already in the database and
logs a warning.

## Building

```bash
npm install
cargo tauri dev      # GUI
cargo tauri build    # .deb / AppImage
```

CLI (shares the same DB, no IPC needed):
```bash
cd src-tauri
cargo run --bin hyprtodo-cli -- add "Read paper" --category college
cargo run --bin hyprtodo-cli -- list
cargo run --bin hyprtodo-cli -- done <id-prefix>
```

Needs Rust (stable), Node 18+, and Tauri's Linux prerequisites
(`webkit2gtk-4.1`, etc — see tauri.app/start/prerequisites).

## What's verified vs. what isn't

Every SQL statement in `src-tauri/src/{tasks,categories,db}` was executed
for real against SQLite (via Python, since no Rust toolchain was available
in this environment) — insert/update/delete/reorder/upsert/foreign-key
cascade all confirmed correct. The Rust type-checking, Tauri wiring, and
Svelte/TS side were manually audited line-by-line but not compiled. Real
compile errors, if any, are typically config/toolchain issues (see git
history / prior conversation) — send the exact error and it'll get fixed.

## Desktop integration

HyprTodo stores the active Hyprland workspace on new tasks, filters the view to
that workspace when IPC is available, and runs in the named `todo` special
workspace. The active config binds `Super+Shift+Y` to toggle it and starts the
app again after reloads. Waybar displays pending, critical, and overdue counts.
Due tasks trigger a D-Bus notification through `notify-send` once per app run.

The existing GitHub-style theme remains the default. `preferences({...})` in
Lua can override its colors, the workspace name, and named keybinding values;
the VM remains filesystem and process sandboxed.
