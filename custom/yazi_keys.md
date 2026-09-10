# Yazi Keys

Complete keymap for yazi 26.9.1 as configured on this machine.
Keys marked **★** are custom (from `~/.config/yazi/keymap.toml`); everything else is a yazi default.

Press `~` inside yazi for the live version of this list. Pausing after a prefix key
(`g`, `c`, `m`, `t`, `,`) pops up a menu of what follows it.

---

## Contents

- [Shell](#shell)
- [Hyprland](#hyprland)
- [Manager — the main view](#manager--the-main-view)
  - [Navigation](#navigation)
  - [Bookmarks (`g`)](#bookmarks-g)
  - [Selection](#selection)
  - [Copy / move / delete](#copy--move--delete)
  - [Create & rename](#create--rename)
  - [Clipboard & permissions (`c`)](#clipboard--permissions-c)
  - [Find, filter, search](#find-filter-search)
  - [Opening files](#opening-files)
  - [Tabs](#tabs)
  - [View: linemode (`m`) and sorting (`,`)](#view-linemode-m-and-sorting-)
  - [Shell & tasks](#shell--tasks)
  - [Plugins](#plugins)
  - [Quit](#quit)
- [Other modes](#other-modes)
  - [Task manager (`w`)](#task-manager-w)
  - [Spot popup (`Tab`)](#spot-popup-tab)
  - [Input / prompt](#input--prompt)
  - [Picker, confirm, completion, help](#picker-confirm-completion-help)

---

## Shell

| Command | Action |
| --- | --- |
| `y` | Open yazi; on quit the shell `cd`s to where you ended up |
| `y <path>` | Same, starting at `<path>` |
| `yazi` | Plain yazi — shell stays put |
| `ya pkg upgrade` | Update all plugins |
| `ya pkg list` | List installed plugins |

---

## Hyprland

| Key | Action |
| --- | --- |
| `Super` + `E` | Yazi as a **scratchpad** — floating, centred, 1400×850, on its own hidden workspace |
| `Super` + `Alt` + `E` | Yazi in a fresh **tiled** Ghostty window |
| `Super` + `Shift` + `E` | Nautilus |

`Super`+`E` is one long-lived instance, toggled in and out exactly like the
`` Super+` `` scratchpad terminal. It stays in whatever directory you left it in,
and quitting with `q` is harmless — the next press starts it again. Reach for
`Super`+`Alt`+`E` when you want a file manager *in* the layout instead of over it.

---

## Manager — the main view

### Navigation

| Key | Action |
| --- | --- |
| `j` / `k` | Down / up |
| `↓` / `↑` | Down / up |
| `h` | Leave for the parent directory |
| `l` **★** | Enter the directory, **or open the file** (smart-enter) |
| `→` **★** | Same as `l` |
| `←` | Same as `h` |
| `H` | Back through directory history |
| `L` | Forward through directory history |
| `gg` | Top of the list |
| `G` | Bottom of the list |
| `Home` / `End` | Top / bottom |
| `Ctrl`+`u` / `Ctrl`+`d` | Half page up / down |
| `Ctrl`+`b` / `Ctrl`+`f` | Full page up / down |
| `PageUp` / `PageDown` | Full page up / down |
| `Shift`+`PageUp` / `Shift`+`PageDown` | Half page up / down |
| `K` / `J` | Scroll the **preview pane** without moving the cursor |
| `Tab` | Spot the hovered file — metadata popup |

### Bookmarks (`g`)

| Key | Goes to |
| --- | --- |
| `gh` | `~` |
| `gc` | `~/.config` |
| `gd` | `~/Downloads` |
| `gt` | Trash bin |
| `gf` | Follow the hovered symlink to its target |
| `g` `Space` | Type a path, with completion |
| `gv` **★** | `~/dev` |
| `go` **★** | `~/dotfiles` |
| `gp` **★** | `~/cp` |
| `gl` **★** | `~/college` |
| `gu` **★** | `~/docs` |
| `gm` **★** | `~/media` |
| `gn` **★** | `~/.config/nvim` |
| `gy` **★** | `~/.config/yazi` |

### Selection

Hovered ≠ selected. Actions apply to the selection if one exists, otherwise to the hovered file.
Selection persists across directories.

| Key | Action |
| --- | --- |
| `Space` | Toggle selection on the hovered file, then step down |
| `v` | Visual mode — move to extend the selection |
| `V` | Visual mode that **un**selects as it moves |
| `Ctrl`+`a` | Select all files here |
| `Ctrl`+`r` | Invert the selection |
| `Esc` | Clear selection / leave visual mode / cancel search |
| `Ctrl`+`[` | Same as `Esc` |

### Copy / move / delete

`y` and `x` only *mark* files. Nothing happens until `p`.

| Key | Action |
| --- | --- |
| `y` | Yank (copy) |
| `x` | Yank in cut mode |
| `p` | Paste here |
| `P` | Paste, overwriting existing files |
| `Y` / `X` | Cancel the pending yank |
| `-` | Symlink the yanked files here (absolute path) |
| `_` | Symlink relative |
| `Ctrl`+`-` | Hardlink the yanked files |
| `d` | Move to trash (recover via `gt`) |
| `D` | **Delete permanently** — confirms first |

### Create & rename

| Key | Action |
| --- | --- |
| `a` | Create a file — end the name with `/` for a directory |
| `A` | Bulk-create from a list |
| `r` | Rename; cursor parked before the extension |

> `r` on a multi-selection opens all the filenames in nvim as a plain buffer.
> Edit with macros / `:%s///` / visual block, then `:wq` — yazi diffs and applies.

### Clipboard & permissions (`c`)

| Key | Action |
| --- | --- |
| `cc` | Copy full path |
| `cC` | Copy file URL |
| `cd` | Copy containing directory path |
| `cD` | Copy directory URL |
| `cf` | Copy filename |
| `cn` | Copy filename without extension |
| `cm` **★** | chmod the selection |

### Find, filter, search

| Key | Scope | Action |
| --- | --- | --- |
| `f` | this directory | **Filter** — hides non-matching entries as you type |
| `/` | this directory | **Find** forward |
| `?` | this directory | Find backward |
| `n` / `N` | this directory | Next / previous match |
| `s` | recursive | **Search by filename** via `fd` |
| `S` | recursive | **Search by content** via `ripgrep` |
| `Ctrl`+`s` | — | Cancel a running search |
| `z` | recursive | fzf over everything below here |
| `Z` | anywhere | zoxide — jump by frecency (shares the DB with shell `z`) |
| `F` **★** | this directory | Jump to the next entry starting with the next char you press |

Rule of thumb: `f` when you can see it, `s` when it's below you, `Z` when it's elsewhere.

### Opening files

| Key | Action |
| --- | --- |
| `Enter` **★** | Open with the first matching rule (smart-enter) |
| `o` **★** | Open with the **right app for the file type**, and tuck yazi away |
| `O` **★** | Open with the first matching rule, **in place** (the stock `o`) |
| `Shift`+`Enter` | **Open interactively** — pick from every registered opener |

`o` and `O` are both shifted one slot right of the yazi defaults. The point of
`o`: the `edit` opener is `block = true`, so opening a text file in place hands
nvim yazi's own window and you cannot browse again until you quit it.

`o` instead dispatches on the file's extension
(`~/.config/hypr/scripts/open-file.sh`):

| Extension | Opens in |
| --- | --- |
| `.pdf` | sioyek |
| `.md` `.markdown` `.mdown` `.mkd` | ghostwriter |
| `.doc` `.docx` `.ppt` `.pptx` `.xls` `.xlsx` | Google Chrome |
| anything else | `$EDITOR` (nvim) in a new Ghostty |

Adding a type is one line in the `case` block of that script. Selecting several
code files and pressing `o` gives you **one** editor with all of them as
buffers, not a terminal each.

Media (images, audio, video) deliberately falls through to the editor — use
`Shift`+`Enter` or `O` for those, which run the opener table below.

Whichever app it picks:

- **yazi hides itself**, exactly as if you had pressed `Super`+`E` again — it
  keeps running, in the directory you left it in, one keypress away.
- **the app opens on the workspace you are looking at**, as an ordinary tiled
  window. A terminal inherits the directory you were browsing.

That second point is the whole reason `o` runs a script rather than calling the
apps directly. Hyprland maps a new window onto the *active* workspace, and while the
scratchpad is showing that is `special:files` — so a naive spawn opened the
app hidden, tiled beside yazi, and it disappeared with the scratchpad on the
next toggle. The script dismisses the scratchpad first, so focus is back on the
real workspace before anything starts.

Outside a scratchpad — the tiled yazi on `Super`+`Alt`+`E`, or yazi in any
ordinary terminal — nothing is hidden and `o` just opens the app beside you.

Nothing was lost in the shuffle — interactive open, the stock `O`, is still on
`Shift`+`Enter`, which is a yazi default.

Configured openers (`~/.config/yazi/yazi.toml`):

| Type | Opens with |
| --- | --- |
| text, code, JSON/TOML/YAML/XML | nvim (blocking) |
| images | Eye of GNOME — `Shift`+`Enter` also offers nvim |
| audio, video | VLC — `Shift`+`Enter` also offers an `ffprobe` dump |
| PDF | sioyek |
| HTML | Brave |
| archives | Extract in place |
| anything else | `xdg-open` |

### Tabs

| Key | Action |
| --- | --- |
| `tt` | New tab in the current directory |
| `tr` | Rename the current tab |
| `1` … `9` | Switch to tab N |
| `[` / `]` | Previous / next tab |
| `{` / `}` | Move the current tab left / right |
| `Ctrl`+`c` | Close the tab (quits if it's the last one) |

### View: linemode (`m`) and sorting (`,`)

Linemode is the trailing column on each row. Default here is `size`.

| Key | Shows |
| --- | --- |
| `ms` | Size |
| `mp` | Permissions |
| `mb` | Birth time |
| `mm` | Modified time |
| `mo` | Owner |
| `mn` | Nothing |

Sorting — capitalise the second key to reverse:

| Key | Sorts by |
| --- | --- |
| `,n` / `,N` | Natural (default) |
| `,a` / `,A` | Alphabetical |
| `,s` / `,S` | Size |
| `,m` / `,M` | Modified time |
| `,b` / `,B` | Birth time |
| `,e` / `,E` | Extension |
| `,r` | Random |

| Key | Action |
| --- | --- |
| `.` | Toggle hidden files |
| `~` or `F1` | Help — the live keymap |

### Shell & tasks

| Key | Action |
| --- | --- |
| `;` | Run a shell command in the background |
| `:` | Run one and block until it finishes |
| `!` **★** | Drop into a full shell here; `exit` returns to yazi |
| `Ctrl`+`n` **★** | Open this directory in Nautilus |
| `Ctrl`+`Enter` **★** | Open this directory in a new terminal (non-blocking) |
| `w` | Task manager — copy progress and errors |
| `Ctrl`+`z` | Suspend yazi to the background |

`!` blocks yazi and hands you a shell in place; `Ctrl`+`Enter` spawns a separate
window and leaves yazi running.

Inside `;` and `:`, refer to files with yazi's own placeholders:

- `%s` — your selected files, or the hovered one when nothing is selected
- `%s1` — strictly the hovered file

They arrive already shell-quoted, so names with spaces stay a single argument.

e.g. `mv %s ~/archive` · `ffmpeg -i %s1 out.mp4`

> **Not** `"$0"` / `"$@"`. Yazi does not populate the shell's positional
> parameters, so `"$0"` silently expands to the string `sh` and the command runs
> against a file that does not exist. Only the `%s` forms work.

### Plugins

| Key | Plugin | Action |
| --- | --- | --- |
| `l` `Enter` `→` **★** | smart-enter | Enter a directory or open a file |
| `F` **★** | jump-to-char | Jump to an entry by first character |
| `cm` **★** | chmod | Change permissions on the selection |
| `M` **★** | mount | List, mount and unmount drives |
| `=` **★** | diff | Yank one file, hover another, diff them |
| `z` | fzf | Fuzzy jump |
| `Z` | zoxide | Frecency jump |
| `gt` | trash | Browse the trash bin |
| — | full-border | Rounded frame (no key) |
| — | git | Per-file git status in the linemode (no key) |

### Quit

| Key | Action |
| --- | --- |
| `q` | Quit — with the `y` wrapper, the shell follows you |
| `Q` | Quit **without** writing the cwd — the shell stays put |
| `Ctrl`+`c` | Close the tab, or quit if it's the last |

---

## Other modes

### Task manager (`w`)

| Key | Action |
| --- | --- |
| `j` / `k` | Next / previous task |
| `Enter` | Inspect the task |
| `x` | Cancel the task |
| `w` / `Esc` / `Ctrl`+`c` | Close |

### Spot popup (`Tab`)

| Key | Action |
| --- | --- |
| `j` / `k` | Next / previous line |
| `h` / `l` | Swipe to the previous / next file |
| `cc` | Copy the selected cell |
| `Tab` / `Esc` | Close |

### Input / prompt

Prompts are modal, like vim. You start in normal mode.

| Key | Action |
| --- | --- |
| `i` / `a` | Insert / append |
| `I` / `A` | Insert at start / append at end of line |
| `v` | Visual mode |
| `r` | Replace one character |
| `h` / `l` | Move by character |
| `b` / `w` / `e` | Word motions (`B` / `W` / `E` for WORDs) |
| `0` / `$` | Start / end of line |
| `^` or `_` | First non-whitespace character |
| `d` / `D` | Cut selection / cut to end of line |
| `c` / `C` | Cut and insert / cut to EOL and insert |
| `s` / `S` | Cut char and insert / cut whole line and insert |
| `x` | Cut the character under the cursor |
| `y` / `p` / `P` | Copy / paste after / paste before |
| `u` / `U` | Undo (lowercase in visual mode) / uppercase |
| `Ctrl`+`r` | Redo |
| `Ctrl`+`u` / `Ctrl`+`k` | Kill to start / end of line |
| `Ctrl`+`w` | Kill the previous word |
| `Ctrl`+`a` / `Ctrl`+`e` | Start / end of line |
| `k` / `j` or `Ctrl`+`p` / `Ctrl`+`n` | Recall previous / next input |
| `Enter` | Submit |
| `Esc` | Back to normal mode, or cancel |
| `Ctrl`+`c` | Cancel outright |

### Picker, confirm, completion, help

| Key | Action |
| --- | --- |
| `j` / `k` | Next / previous item |
| `Enter` | Submit |
| `Esc` / `Ctrl`+`c` | Cancel |
| `y` / `n` | Confirm dialogs only: yes / no |
| `Tab` | Completion only: accept the completion |
| `Alt`+`j` / `Alt`+`k` | Completion only: next / previous candidate |

---

## Learning order

1. `j` `k` `h` `l` `q` — just navigate, launched via `y`
2. `Space` `y` `x` `p` `d` — the whole file-management vocabulary
3. `f` and `z` — filtering makes deep trees painless
4. `r` on a multi-selection — bulk rename in nvim
5. `;` and `!` — once you notice you keep leaving yazi to run one command

Config lives in `~/.config/yazi/`: `yazi.toml` (behaviour), `theme.toml` (colours),
`keymap.toml` (the ★ entries), `init.lua` (plugin setup).
