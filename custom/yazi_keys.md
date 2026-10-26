# Yazi Keys

Complete keymap for yazi 26.9.1 as configured on this machine.
Keys marked **★** are custom (from `~/.config/yazi/keymap.toml`); everything else is a yazi default.

Press `Ctrl`+`h` **★** (or `~`, or `F1`) inside yazi for the live version of this
list — it is generated from the running config, so it is never out of date, and it
has a filter box. Pausing after a prefix key (`g`, `c`, `m`, `t`, `,`) pops up a
menu of what follows it.

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
  - [Convert files (`c z`)](#convert-files-c-z)
  - [Menu keys](#menu-keys)
  - [What converts to what](#what-converts-to-what)
  - [Converting without yazi](#converting-without-yazi)
  - [Conversion requirements](#conversion-requirements)
  - [ImageMagick 6 and the `magick` shim](#imagemagick-6-and-the-magick-shim)
  - [Markdown out of Word files](#markdown-out-of-word-files)
  - [Verified on this machine](#verified-on-this-machine)
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
| `ya pkg add <owner>/<repo>` | Install a plugin from GitHub |
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
| `cz` **★** | Convert to… — see below |
| `cZm` **★** | Convert straight to Markdown |

### Convert files (`c z`)

**★** omniconvert. Hover a file or select several, press `c z`, and a menu lists
only the formats those files can actually become — one keypress each.

| Key | Action |
| --- | --- |
| `cz` **★** | Convert to… — the menu |
| `cZm` **★** | Straight to Markdown, no menu |

```
 ╭ Convert ─────────────────────────────╮
 │ m   .md    Markdown — portable text  │
 │ j   .jpg   JPEG — photos             │
 │ w   .webp  WebP — small, web         │
 │ a   .avif  AVIF — smallest           │
 │ d   .pdf   PDF — document            │
 │ M   .pdf   Merge all selected …      │
 ╰──────────────────────────────────────╯
```

The menu is not a fixed list. The plugin asks the `omniconvert` script what the
hovered file can reach and builds the menu from the answer, so it can never
offer a conversion that would fail. Select several files and you get the
**intersection** — only formats every one of them can reach, and a warning
instead of a menu when they share none. Select images only and an extra `M`
appears: merge all of them into one PDF.

Nothing is ever overwritten. `photo.png` becomes `photo.webp`, or `photo-2.webp`
if that name is taken, and the original is left alone.

### Menu keys

Mnemonics only have to be unique inside one menu, so `o` is Opus for audio and
ODT for documents — no input reaches both. Markdown leads every menu it appears
in and always takes `m`.

| Group | Keys |
| --- | --- |
| Markdown | `m` |
| Images | `p` png · `j` jpg · `w` webp · `a` avif · `h` heic · `x` jxl · `g` gif · `b` bmp · `t` tiff · `T` tga · `i` ico · `d` pdf |
| Audio | `3` mp3 · `o` opus · `c` aac · `m` m4a · `f` flac · `s` wav · `O` ogg · `W` wma |
| Video | `4` mp4 · `e` webm · `k` mkv · `v` mov · `A` avi · `F` flv · `V` wmv |
| Documents | `D` docx · `o` odt · `r` rtf · `t` txt · `h` html · `x` xlsx · `s` ods · `C` csv · `p` pptx · `P` odp |
| Images only | `M` merge the selection into one PDF |

`Esc` closes the menu without converting. A format the backend gains but these
tables don't know about still shows up, on a leftover key.

### What converts to what

| From | To |
| --- | --- |
| Images (png jpg webp avif heic jxl gif bmp tiff tga ico svg psd + camera RAW) | png jpg webp avif heic jxl gif bmp tiff tga ico pdf **md** |
| PDF | png jpg webp avif tiff — one image per page — **md** |
| Audio | mp3 opus aac m4a flac wav ogg wma |
| Video | mp4 webm mkv mov avi flv wmv gif, **or** any audio format, which pulls out the soundtrack |
| doc docx odt rtf txt md | pdf docx odt rtf txt html **md** |
| html htm | pdf odt txt **md** |
| xls xlsx ods csv tsv | pdf xlsx ods csv **md** |
| ppt pptx odp | pdf pptx odp **md** |

`omniconvert list` prints the current list; `omniconvert targets <file>` answers
for one file, which is exactly what the menu asks.

Markdown takes a different route for each source — LibreOffice for Writer files,
markitdown for spreadsheets, decks and HTML, `pdftotext -layout` for a PDF with
a text layer, and tesseract OCR for one without and for images. OCR runs only
when it has to, so an ordinary PDF converts in under a tenth of a second. Expect
text, not structure: OCR recovers the words on a scan, not its tables.

### Converting without yazi

The backend is an ordinary script and is useful on its own:

```sh
omniconvert webp photo.png            # one file
omniconvert mp3 *.flac                # batch
omniconvert m4a podcast.mp4           # extract audio from video
omniconvert pdf report.docx           # document → pdf
omniconvert md report.xlsx            # spreadsheet → markdown table
omniconvert md scan.pdf               # scanned pdf → OCR'd markdown
omniconvert jpg scan.pdf              # pdf pages → jpgs
omniconvert pdf --merge *.jpg         # many images → ONE pdf
```

Quality is set by environment variables, with these defaults:

```sh
JPG_QUALITY=90  WEBP_QUALITY=85  AVIF_QUALITY=55  HEIC_QUALITY=80
PDF_DPI=200     GIF_FPS=12       GIF_WIDTH=720
MP3_VBR=2       VIDEO_CRF=23
OCR_DPI=300     PDF_TEXT_MIN=64
```

Per run — `WEBP_QUALITY=95 omniconvert webp *.png` — or in the shell profile to
change the default. `PDF_TEXT_MIN` is how many characters of text layer a PDF
needs before it counts as born-digital rather than a scan.
`OMNICONVERT_OCR_LANG` overrides the OCR language, otherwise `eng`; tesseract
has no autodetect, so a language it was not given is a language it cannot read.

### Conversion requirements

| Tool | Needed for | Here |
| --- | --- | --- |
| `omniconvert` (the script) | everything — the plugin is only a menu | `~/.local/bin/omniconvert` |
| imagemagick | images, image→pdf | v6 + a `magick` shim — see below |
| ffmpeg | audio and video | yes |
| libreoffice | documents | 24.2 — see below |
| poppler (`pdftoppm`, `pdfinfo`, `pdftotext`) | pdf→images, pdf→md | yes |
| ghostscript | pdf→webp/avif | yes |
| markitdown | spreadsheets, decks, html and docx → md | `uv tool install 'markitdown[docx,pptx,xlsx,xls]'` |
| tesseract | OCR — scanned pdfs and images → md | **not installed** |

Only the tools for formats you actually use matter; the menu offers whatever is
installed and leaves out what it cannot do. Until tesseract is there, `.md` is
simply absent from an image's menu, and a scanned PDF reports a missing tool:

```sh
sudo apt install tesseract-ocr
```

> **`ya pkg add` does not finish the install.** `ya pkg` deploys a plugin's Lua,
> README and LICENSE and nothing else, so the `omniconvert` script never comes
> across with it — and without the script `c z` is a menu with nothing behind
> it. It has to be fetched separately into `~/.local/bin`, which is already on
> `PATH`:
>
> ```sh
> curl -fsSL https://raw.githubusercontent.com/skylightlim/omniconvert.yazi/main/omniconvert \
>   -o ~/.local/bin/omniconvert && chmod +x ~/.local/bin/omniconvert
> ```
>
> `omniconvert list` confirms it landed. The alternative is to clone the repo
> into `~/.config/yazi/plugins/` and symlink the script out of it, which keeps
> both halves on one `git pull` but gives up `ya pkg upgrade` for this plugin.

### ImageMagick 6 and the `magick` shim

omniconvert calls `magick`, the ImageMagick **7** binary. Ubuntu 24.04 only
packages ImageMagick 6, which provides `convert` and no `magick` at all — and
because the menu is filtered by what is installed, the effect was not an error
but an *empty* menu: `omniconvert targets photo.png` printed nothing and `c z`
on an image offered no formats.

`~/.local/bin/magick` is a shim forwarding to the IM6 tools. Every call the
script makes is the plain `magick [options] input output` form, which `convert`
accepts unchanged; the shim also passes IM7's subcommand form through, so
`magick identify x.png` reaches `identify` and interactive use works too.

Two formats are refused by the shim rather than forwarded. IM6 cannot *write*
HEIC or JPEG XL, and instead of saying so it writes a PNG under the name it was
given — a `photo.heic` that is really a PNG, exit status 0. The shim exits 1 for
those two extensions so the failure is visible. They still appear in the menu,
because the script only checks that `magick` exists, so `h` and `x` report a
failed conversion instead of quietly producing a mislabelled file.

Installing a real ImageMagick 7 — an AppImage from imagemagick.org, or a build
from source; there is no apt package on 24.04 — makes the shim removable and
HEIC and JXL work for real.

### Markdown out of Word files

`docx odt rtf txt → md` is the one documented route that does not work here.
The script sends Writer files through LibreOffice, which has exported Markdown
only since **26.8**; this machine has 24.2, so the filter does not exist and the
conversion exits 1.

Everything else reaching `.md` is unaffected, because nothing else goes that
way — spreadsheets, decks and HTML use markitdown, and PDFs use `pdftotext`.

For a Word file in the meantime, markitdown reads `.docx` directly once the
`[docx]` extra is installed, which it now is:

```sh
markitdown report.docx > report.md
```

`.odt` and `.rtf` have no such shortcut — `omniconvert docx` first, then the
line above. Upgrading LibreOffice past 26.8 removes the whole detour.

### Verified on this machine

Working: all 9 writable image formats (png jpg webp avif gif bmp tiff tga ico)
and image→pdf; every audio target from wav; every video target from mp4 plus
soundtrack extraction; `md → pdf docx odt rtf txt html`; `csv → md xlsx ods
pdf`; `pptx → md odp pdf`; `pdf → png jpg tiff webp md`. The no-overwrite rule
holds — a second conversion lands on `-2`.

Not working: `heic` and `jxl` out (ImageMagick 6), `docx → md` (LibreOffice
24.2), and anything needing OCR (no tesseract).

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
| `Ctrl`+`h` **★** | Help — the live keymap |
| `~` or `F1` | Same |

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
| `cz` `cZm` **★** | omniconvert | Convert the selection — menu of valid targets |
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
