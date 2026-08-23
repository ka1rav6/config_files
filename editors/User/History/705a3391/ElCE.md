# HyprTodo — User Guide

A complete reference to every feature of HyprTodo and how to use it.

## Table of contents

1. [What is HyprTodo?](#1-what-is-hyprtodo)
2. [Core concepts](#2-core-concepts)
3. [Installing and running](#3-installing-and-running)
4. [A tour of the dashboard](#4-a-tour-of-the-dashboard)
5. [Keyboard controls — complete reference](#5-keyboard-controls--complete-reference)
6. [Working with tasks](#6-working-with-tasks)
7. [Working with categories](#7-working-with-categories)
8. [Changing the layout (columns)](#8-changing-the-layout-columns)
9. [Configuring with Lua](#9-configuring-with-lua)
10. [The CLI (`hyprtodo-cli`)](#10-the-cli-hyprtodo-cli)
11. [The Waybar module](#11-the-waybar-module)
12. [Where your data lives](#12-where-your-data-lives)
13. [Integrating with Hyprland](#13-integrating-with-hyprland)
14. [Current limitations](#14-current-limitations)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. What is HyprTodo?

HyprTodo is a **keyboard-first task dashboard** built for Hyprland and other
Linux/Wayland compositors. It is designed around three ideas:

- **Your hands stay on the home row.** Everything — navigating, adding,
  completing, deleting, rearranging — is a single keypress. Vim-style keys
  (`h/j/k/l`) work everywhere.
- **Local-first, single source of truth.** All data lives in one SQLite file on
  your disk. No accounts, no sync, no network access.
- **GUI, CLI, and config share one database.** The graphical app, the
  `hyprtodo-cli` tool, and the Lua startup config all read/write the same
  store, so a task added from a terminal appears on the dashboard instantly
  (and vice versa).

Under the hood it is a Tauri 2 desktop app: a Rust backend (SQLite via
rusqlite, Lua config via mlua) driving a Svelte frontend.

---

## 2. Core concepts

| Concept | What it means |
|---|---|
| **Task** | One to-do item: title, status, optional criticality, optional due date, optional category. Identified by a UUID; the CLI shows its first 8 characters (e.g. `3f2b81c0`). |
| **Status** | `pending` (open), `completed` (done), or `archived` (hidden). New tasks start `pending`. |
| **Criticality** | Importance: `low`, `normal` (default), `high`, `critical`. Tasks marked `critical` also appear in the synthetic **Critical** panel. |
| **Category** | A named bucket rendered as one panel on the dashboard. Has an optional icon (Nerd Font glyph) and accent color. |
| **Panel** | One dashboard column. Every category gets a panel, plus one built-in virtual panel called **Critical** that collects all pending critical tasks from every category. It always sits last and cannot be renamed, moved, deleted, or given tasks of its own. |
| **Mode** | The app is in `normal` mode (keys act as shortcuts) or a modal state (`addingTask`, `addingCategory`, `renamingCategory`) where keystrokes go into a text field. |

How tasks appear:

- Each category panel lists its tasks whose status is **not** `archived`;
  completed tasks remain visible (struck through).
- The **Critical** panel lists tasks with criticality `critical` that are still
  `pending`, regardless of category.
- Within a panel, tasks are ordered by their internal sort order (newest added
  goes to the bottom).

---

## 3. Installing and running

### Prerequisites

- Rust stable (`rustup`)
- Node.js 18+ and npm
- Tauri's Linux system dependencies (Debian/Ubuntu names):
  `libwebkit2gtk-4.1-dev build-essential curl wget file libxdo-dev libssl-dev
  libayatana-appindicator3-dev librsvg2-dev` — full list at
  https://tauri.app/start/prerequisites

### Build & run

```bash
npm install          # install frontend deps (once)

cargo tauri dev      # dev run: compiles Rust, serves UI on port 1420
cargo tauri build    # production: .deb and AppImage under target/release/bundle/
```

Two binaries are produced:

| Binary | Purpose |
|---|---|
| `hyprtodo` | The GUI dashboard window. |
| `hyprtodo-cli` | Headless terminal tool sharing the same database. |

On first launch the database is created and seeded with four starter
categories — **College**, **Clubs**, **Today**, and **General** — so a fresh
install looks good with zero configuration.

---

## 4. A tour of the dashboard

```
┌────────────────────────────────────────────────────────────────────────┐
│ HyprTodo                                                  7 tasks      │
├──────────────┬──────────────┬──────────────┬──────────────┬───────────┤
│ COLLEGE    2 │ CLUBS      1 │ TODAY      2 │ GENERAL    1 │ CRITICAL 1│
│ ○ essay      │ ○ meetup     │ ○ review     │ ● haircut    │ ○ club fai│
│ ○ lab report │              │ ○ call mum   │              │           │
└──────────────┴──────────────┴──────────────┴──────────────┴───────────┘
```

- **Title bar** — app name plus a live count of *pending* tasks ("7 tasks").
- **Panels** — each shows its category icon, name (uppercased), and a count
  badge. Empty panels say "nothing here".
- **Focused panel** — outlined in the category's accent color (or the global
  blue accent). All single-key actions target the focused panel/task.
- **Focused task** — highlighted background plus outline. Focus resets to the
  first task whenever you switch panels.
- **Task card anatomy**:
  - `○` open / `●` completed marker, colored by criticality (grey = low,
    white = normal, amber = high, red = critical);
  - the title;
  - optional badges: red `CRITICAL` pill or amber `high` pill (hidden once
    completed);
  - optional due chip: `42m`, `5h`, `tomorrow`, `3d`, or a bold red `OVERDUE`.
  - Completed tasks are dimmed and struck through.

While data loads you will see "loading…" instead of the grid.

Task cards can be clicked to edit them. Modal dialogs can be cancelled with
Escape or by clicking their backdrop.

---

## 5. Keyboard controls — complete reference

Press **Shift+H** any time in normal mode to see this list inside the app.

### Navigation

| Keys | Action |
|---|---|
| `j` / `↓` | Move task focus down within the focused panel (stops at last) |
| `k` / `↑` | Move task focus up (stops at first) |
| `l` / `→` | Next panel (wraps around) |
| `h` / `←` | Previous panel (wraps around) |
| `Tab` / `Shift+Tab` | Next / previous panel; task focus jumps to first task |
| `1` … `9` | Jump directly to panel N (if it exists) |

### Tasks

| Keys | Action |
|---|---|
| `Space` / `c` | Toggle focused task pending ⇄ completed |
| `d` | Delete focused task; press `u` to undo |
| `a` | Add an uncategorized task |

### Categories & layout

| Keys | Action |
|---|---|
| `A` | Add a new category (type display name; id auto-generated) |
| `r` | Rename the focused category (not available on Critical panel) |
| `D` | Delete the focused category (not available on Critical panel); press `u` to undo |
| `Ctrl+h` / `Ctrl+l` | Move focused category panel left / right (persisted) |
| `-` | Fewer columns (min 1) |
| `=` / `+` | More columns (max 6) |

### Global

| Keys | Action |
|---|---|
| `Shift+H` | Open the keybindings overlay |
| `/` | Focus task search |
| `Esc` | Close overlay / cancel current modal |

### Inside modals (adding task/category, renaming)

| Keys | Action |
|---|---|
| `Enter` | Submit (empty input is ignored) |
| `Esc` | Cancel |
| click backdrop | Cancel |

While a modal is open all other keys are captured as text — shortcuts are
suspended until you submit or escape.

---

## 6. Working with tasks

### Adding a task

1. Press `a`. The task editor appears.
2. Enter the title and optional description, priority, due date, and estimate.
3. Press `Enter` or click Add (or press `Esc` to cancel).

Notes:

- New tasks start uncategorized, pending, with normal priority and no due date.
  Assign a category later from the editor (`e` or click a task).

### Completing / reopening

Focus a task and press `Space` or `c`. This toggles between pending and
completed and stamps/clears the completion timestamp. Completed tasks stay in
their panel struck-through; they are excluded from the Critical panel and from
the header count.

### Deleting

Press `d` on a focused task. The row is removed and an Undo action appears;
press `u` or click it to restore the task.

### Due dates and overdue display

The dashboard shows relative time remaining for any task with a `due_at`
value: minutes (`42m`), hours (`5h`), `tomorrow`, days (`3d`). Once the
deadline passes the chip becomes bold red **OVERDUE**. Due dates are only
settable through the CLI today.

---

## 7. Working with categories

### Add

- Press `A`, type a name ("Research"), press `Enter`.
- The stored id is slugified from your input (`Research` → `research`;
  punctuation becomes `-`; if everything is stripped, an id like `cat-1724…`
  is generated). The new panel appears at the far right.

### Rename

- Focus the category's panel, press `r`, edit the pre-filled name, `Enter`.
- Renaming changes only the display name, not the id — existing tasks stay
  attached.

### Reorder

- `Ctrl+h` / `Ctrl+l` swap the focused category with its neighbor. The order
  is persisted in the database, so it survives restarts.

### Delete

1. Focus the category's panel and press `D` (Shift+d).
2. The category is removed and an Undo action appears.
3. Press `u` or click Undo to restore the category and its task assignments.

Notes:

- The **Critical** panel cannot be deleted; `D` is ignored while it's focused.
- Focus is clamped to a valid panel after deletion.
- If the deleted category is still defined in your `config.lua`, the Lua
  loader re-creates it on next launch — remove its `category(...)` line to
  make the deletion stick (see §9).

---

## 8. Changing the layout (columns)

- Press `-` to reduce the grid width by one column, `=` (or `+`) to increase.
- Allowed range: **1–6** columns; panels wrap onto extra rows automatically.
- The choice is saved (in the database's `schema_meta` table) and restored on
  the next launch.

---

## 9. Configuring with Lua

HyprTodo reads `~/.config/hyprtodo/config.lua` on **every launch**. If that
file does not exist it falls back to the bundled default (`config/default.lua`
in the repo), which defines College/Clubs/Today/General and 2 columns.

Start customizing:

```bash
mkdir -p ~/.config/hyprtodo
cp config/default.lua ~/.config/hyprtodo/config.lua
$EDITOR ~/.config/hyprtodo/config.lua
```

Two functions are available:

```lua
-- Define or update a category/panel:
category("research", {
  name  = "Research",     -- display name (defaults to id)
  icon  = "󰂺",            -- optional Nerd Font glyph
  color = "#d29922",      -- optional accent color (any CSS color)
})

-- Grid width at launch, 1–6:
columns(3)
```

Semantics you should know:

- The file runs on **every launch** and *upserts* each category by its id —
  re-running never duplicates anything.
- Lua only **adds or updates**; it never deletes. Consequence: if you delete
  a category in-app (`D`) but its `category(...)` line is still in the config,
  it will be re-created on next launch. A category removed from the config
  keeps living in the database, and renames/reorders you performed in-app
  survive the next reload.
- The interpreter is **sandboxed**: `io`, `os`, `require`, `dofile`,
  `loadfile` are all removed, so a config file cannot touch the filesystem or
  run commands.
- If your Lua has an error, startup continues using whatever categories were
  already in the database; a warning is logged.

---

## 10. The CLI (`hyprtodo-cli`)

Build it alongside the GUI:

```bash
cd src-tauri && cargo build --release
# binary: target/release/hyprtodo-cli   (install somewhere on $PATH)
```

It opens the same SQLite file as the GUI — no daemon, no IPC — so both views
are always in sync.

### `add`

```bash
hyprtodo-cli add "Read the paper"                 # uncategorized task
hyprtodo-cli add "Buy oat milk" --category clubs  # into category id
hyprtodo-cli add "Fix prod" -C critical --due "2026-08-30T17:00:00Z"
```

| Flag | Meaning |
|---|---|
| `-c, --category <id>` | Attach to a category by its slug id (`college`, `clubs`, `today`, …) |
| `-C, --criticality <level>` | `low`, `normal`, `high`, or `critical` |
| `--due <iso-date>` | ISO-8601 deadline string |

Criticality `critical` + still-pending ⇒ shows up in the GUI's Critical
panel. Use full ISO timestamps for reliable OVERDUE detection.

### `list`

```bash
hyprtodo-cli list                 # pending tasks only
hyprtodo-cli list --category today
hyprtodo-cli list --all           # include completed/archived
```

Output format: `[ ] 3f2b81c0 Fix prod  (due 2026-08-30T17:00:00Z)`
(`[x]` = completed, `[-]` = archived).

### `done`

```bash
hyprtodo-cli done 3f2b81c0    # any unambiguous prefix works
```

Marks the matching pending task completed. Ambiguous prefixes are rejected;
unknown prefixes print an error.

---

## 11. The Waybar module

`assets/waybar-hyprtodo.sh` renders a Waybar widget with the pending count,
querying the database via the CLI instead of launching the GUI.

Copy it into place and register it in your Waybar config:

```bash
install -m755 assets/waybar-hyprtodo.sh ~/.config/waybar/scripts/
```

```jsonc
// ~/.config/waybar/config.jsonc
"custom/hyprtodo": {
  "exec": "~/.config/waybar/scripts/waybar-hyprtodo.sh",
  "return-type": "json",
  "interval": 30,
  "on-click": "hyprctl dispatch togglespecialworkspace todo"
}
```

Current behavior: shows `TODO <n>` plus a tooltip with pending, critical, and
overdue counts. Clicking it toggles the `special:todo` workspace. The module
also finds `~/.local/bin/hyprtodo-cli` when it is not on `$PATH`.

---

## 12. Where your data lives

| Path | Contents |
|---|---|
| `~/.local/share/hyprtodo/hyprtodo.db` | SQLite database: `tasks`, `categories`, `schema_meta` (WAL mode, foreign keys on) |
| `~/.config/hyprtodo/config.lua` | Optional user config (falls back to bundled default) |

Back up the single `.db` file and you have backed up everything. To start
fresh, quit the app and delete the database; it will be recreated and reseeded
(College/Clubs/Today/General) on next launch.

Useful schema facts:

- Tasks reference their category by id; deleting a category (`D` on its
  panel, or via SQL) leaves those tasks intact but uncategorized.
- Statuses/criticalities are enforced by CHECK constraints.
- The column count is stored as the `"columns"` key of `schema_meta`.

---

## 13. Integrating with Hyprland

The window opens borderless (no decorations) and transparent, 900×640 by
default (min 480×360) — it is meant to be launched/floated by your compositor.

Example bindings in `hyprland.conf`:

```ini
# Launch / focus HyprTodo
bind = $mainMod, T, exec, hyprtodo

# Float it like a launcher-style overlay
windowrulev2 = float, class:^(hyprtodo)$
windowrulev2 = size 900 640, class:^(hyprtodo)$
```

Because there are no window decorations, close HyprTodo with your usual WM
kill binding (`$mainMod, Q` → `killactive` by default) — there is currently no
in-app quit shortcut.

---

## 14. Current limitations

- The app reads the active Hyprland workspace when it starts; tasks created
  outside Hyprland are not assigned a workspace.
- Undo restores the most recent task or category action only.
- External CLI/database changes appear after the app refreshes or restarts.

---

## 15. Troubleshooting

| Symptom | Fix |
|---|---|
| `cargo tauri dev` fails about webkit/GTK | Install Tauri's Linux prerequisites (§3); on Debian/Ubuntu ensure `libwebkit2gtk-4.1-dev` specifically (not 4.0). |
| Dev server port error | Port 1420 is strict-pinned for Tauri; free it before running dev. |
| Icons/glyphs look like boxes | Install a Nerd Font (e.g. JetBrainsMono Nerd Font, Symbols Nerd Font Mono). |
| Transparent window shows black behind it | Transparency needs a compositor; under Hyprland it works out of the box. |
| My Lua config broke everything? | Errors are non-fatal: fix/delete `~/.config/hyprtodo/config.lua` and relaunch — the bundled default takes over. |
| Task added by CLI doesn't appear in the GUI | The GUI loads once at startup; press any refresh-triggering action or restart the app (auto-refresh on external DB writes is on the roadmap). |
| `hyprtodo-cli done` says ambiguous | Use more characters of the id shown by `list`. |

---

*Generated from source analysis of the repo (Svelte frontend, Tauri/Rust
backend, migrations, CLI, Lua loader, Waybar script). Behavior described
matches the code as of version 0.1.0.*

