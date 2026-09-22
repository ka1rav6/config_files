# zathura, for someone who already knows vim

Written against zathura 0.5.4 / girara 0.4.2, and against the config in
`~/.config/zathura/zathurarc` next to this file. Bindings marked **[cfg]** are
additions from that config, not stock zathura.

---

## 1. The mental model

zathura is girara (a vim-ish GTK shell) wrapped around a rendering plugin. That
heritage buys you more than a coat of paint: modes, a command line, counts,
marks, a jumplist, and incremental search all behave the way you expect.

Where the analogy breaks is the **unit of motion**. In vim your text is one
continuous buffer and lines are the atom. In zathura there are *two* atoms and
they are bound to different keys:

| Atom | What moves | Keys |
|------|-----------|------|
| **the viewport** | slides over a continuous scroll of pages | `h j k l`, `^d ^u`, `^f ^b`, `Space` |
| **the page** | jumps to the next/previous *page object* | `J`, `K`, `nG`, `gg`, `G` |

Almost every "why did it do that" moment traces back to confusing the two.
`j` at the bottom of page 4 flows into page 5 without stopping; `J` skips to the
top of page 5 regardless of where you were. In a 600-page book you scroll with
`j`/`^d` and you *navigate* with `G`.

There is **no insert mode and no buffer to edit.** The only text entry is the
command line. So the entire lowercase alphabet is free for commands, and
zathura spends it — which is where the traps in §12 come from.

---

## 2. Modes

| Mode | Enter | Leave | What it is |
|------|-------|-------|-----------|
| normal | — | — | everything below, unless stated |
| index | `Tab` | `Tab`, `q` **[cfg]**, `Esc` **[cfg]** | the document outline as a tree |
| fullscreen | `F11` | `F11`, `q` | no chrome, still scrollable |
| presentation | `F5` | `F5`, `q` | one page = one screen, fitted, paging only |
| command line | `:` `/` `?` | `Esc`, `Enter` | girara's inputbar |

Stock zathura gives fullscreen and presentation mode a *much* thinner keymap
than normal mode — no `j`/`k`, no `/`, no index. The config re-adds them, so
those modes now feel like normal mode with the chrome removed. That is the
single biggest quality-of-life change in the file.

`Esc` and `^c` abort out of anything, everywhere.

---

## 3. Moving

### Scrolling the viewport

```
h  j  k  l        left, down, up, right      (scroll-step 70px)
^d ^u             half page down / up        ← same as vim
^f ^b             full page down / up        ← same as vim
Space  <S-Space>  full page down / up
^t ^y             half page LEFT / RIGHT     ← NOT vim's line-scroll
t  y              full page LEFT / RIGHT     ← NOT yank
H  L              top / bottom of the current page
P                 snap the view to the current page (un-straddle the fold)
```

Full-page scrolls keep 8% overlap (`scroll-full-overlap`), so the line sitting
on the fold appears at the top of the next screenful instead of vanishing.

### Jumping to a page

```
gg        first page
G         last page
15G       page 15               ← counts work exactly like vim
J  K      next / previous page  (also PgDn / PgUp)
:goto 15  same as 15G
```

**Page numbers are the PDF's, not the book's.** A paper with a cover and roman
front matter will be off by however many. `:offset 12` shifts the numbering so that
PDF page 13 answers to `13G` as printed page 1, and the statusbar follows suit
for the rest of the session (negate it if it lands the wrong way). Set it once when you open a scanned book and stop doing
mental arithmetic.

### The jumplist — identical to vim

```
^o        back to where you jumped from
^i        forward again
```

Populated by `G`, `nG`, index selections, search hits and followed links — the
same "big motions" rule as vim. Following a citation to the bibliography and
`^o`-ing back is the single most useful two-key sequence in the program.

### `^j` / `^k` — bisect, which vim has no equivalent for

Between your last two jump points, `^j` and `^k` binary-search. Land on page 40,
jump to page 600, then `^j` → 320, `^j` → 160, `^k` → 240. Six presses to find
the chapter you half-remember, without knowing its number. Learn this one; it is
genuinely better than anything vim offers for the same problem.

---

## 4. Search

```
/pattern      search forward
?pattern      search backward
n  N          next / previous hit           ← wraps, crosses pages
:nohl         clear the highlights
Esc           also clears them (abort-clear-search)
```

Incremental, so results move under you as you type. All hits on screen are
amber; the *current* hit is coral — that distinction is configured, not stock,
and it is what makes `n` legible on a page with fifteen matches.

Note what is missing: **no regex, no `*`, no word-boundary matching.** It is a
plain substring search against the text layer. Two consequences worth knowing:

- Ligatures and hyphenation defeat it. Searching `workflow` misses a line-broken
  `work-\nflow`, and in some LaTeX PDFs `fi`/`fl` are single glyphs that do not
  match the letters you typed.
- A scanned PDF with no text layer returns nothing at all, silently. If a search
  you are certain about finds zero hits, that is the diagnosis — run it through
  OCR (`ocrmypdf in.pdf out.pdf`) rather than assuming the word is not there.

`zathura -f "some phrase" file.pdf` opens with the search already run.

---

## 5. The index (`Tab`)

A tree of the document's outline. Vim motions work, plus tree operations:

```
j  k            down / up a row
l  L            expand this entry / expand everything
h  H            collapse this entry / collapse everything
gg  G           first / last row          [cfg]
^d  ^u          faster up / down          [cfg]
Return, Space   jump there and close the index
Tab, q, Esc     close without moving      [cfg for q/Esc]
```

`L` then `/`-ing in normal mode is often a faster way into a big technical book
than the table of contents page. If `Tab` does nothing, the PDF simply has no
outline — common for scans and for anything exported from Word.

---

## 6. Zoom and fit

```
+  -  =         zoom in, out, reset to 100%
zI zO z0        the same three, spelled out
150=            zoom to exactly 150%        ← count prefix again
a               adjust: best-fit (whole page on screen)
s               adjust: width (page fills horizontally)
^scroll         zoom with the mouse wheel
```

Documents open fitted to **width** (`adjust-open width`) because that is the
reading default for A4 text on a widescreen display; `a` is one key away when a
full-page figure needs to be seen whole. Zoom is centre-anchored (`zoom-center`),
so `+` magnifies what you are looking at rather than the top-left corner.

`a` and `s` also *un-stick* a document that you have zoomed and panned into a
confusing position. Treat them as a reset.

---

## 7. View modes

```
d           dual page — two-up, like a printed spread
F11         fullscreen
F5          presentation
^r  or  i   recolor (dark mode for the page itself)     [i is cfg]
r           rotate 90° clockwise
<A-r>       rotate 90° counter-clockwise                [cfg]
R           reload the document
^n          toggle the statusbar
^m          toggle the inputbar
```

**Dual page** is configured with `first-page-column "1:2"`, which puts page 1
alone in the right column so that every subsequent spread is odd-left /
even-right, the way the printed book actually falls open. Without it every
spread is off by one and figure captions land on the wrong side.

**Recolor** (`^r` / `i`) is a two-colour remap, not a real dark mode. The config
sets `recolor-keephue` so saturated colours in charts survive, and
`recolor-reverse-video` so an embedded dark-themed screenshot is not inverted
back to white. It is still wrong for heat maps and syntax-highlighted listings —
toggle it per document rather than leaving it on. To default it on, flip
`set recolor false` → `true` in the rc.

**`R` is rarely needed** now that `filemonitor` is on: a recompiled LaTeX PDF or
a regenerated report reloads itself, in place, keeping your page and zoom.

---

## 8. Links — zathura's `f`

```
f       label every link on screen; type the number to follow it
F       label them, then show the target instead of following
c       copy a link target to the clipboard
```

This is hint-mode, the same idea as vimium or flash.nvim, not vim's
find-character. Following a link pushes onto the jumplist, so `f`, read, `^o` is
the citation-chasing loop.

`F` before `f` is worth the habit on PDFs from the internet: it tells you whether
that footnote marker goes to the bibliography or to a URL, before you launch a
browser.

---

## 9. The command line

`:` opens it, with completion on `Tab` and history on `Up`/`Down`.

| Command | Does |
|---|---|
| `:open path` / `:o` | open another document (`o` and `O` are the shortcuts; `O` prefills the current directory) |
| `:close` | close the document, keep zathura open |
| `:quit` / `:q` | quit |
| `:write file` | save a copy; `:write!` overwrites |
| `:info` | metadata — title, author, producer, encryption, signatures |
| `:print` | GTK print dialog (also `^p` **[cfg]**) |
| `:export attachment file` | pull an embedded attachment out |
| `:offset n` | renumber pages (see §3) |
| `:nohl` | clear search highlighting |
| `:set option value` | change any rc setting live, no restart |
| `:dump file` | write every current setting, with descriptions, to a file |
| `:exec cmd` | run a shell command; `$FILE`, `$PAGE`, `$DBUS` expand |
| `:bmark name` / `:blist` / `:bdelete name` | named bookmarks (§10) |

`:set` and `:dump` together are how you explore this program. `:dump /tmp/z` then
reading `/tmp/z` is faster and more complete than the man page, and anything you
like you can paste into the rc.

---

## 10. Marks, bookmarks, and "where was I"

Three different mechanisms, easy to confuse:

**Quickmarks** — vim's marks, exactly.
```
ma      set quickmark a at the current position
'a      jump to it
```
Single letter or digit. Persisted per-document in the database, so `'a` still
works next week.

**Named bookmarks** — no vim equivalent.
```
:bmark intro       name the current page "intro"
:blist             list them
:bdelete intro     remove one
```
Use these for the handful of places worth naming in a long book, quickmarks for
the two or three you are bouncing between right now.

**Last position** — automatic. `set database sqlite` is what makes zathura reopen
a document on the page (and at the zoom) you left it on. This does not work with
the default `plain` backend, which is why it is set explicitly in the rc.
Everything lives in `~/.local/share/zathura/bookmarks.sqlite`.

---

## 11. Selecting text

Mouse only — there is no visual mode.

```
drag Button1        select text
^drag Button1       select a rectangular region
hold Button2        pan
```

Selections go to the **clipboard** (`selection-clipboard clipboard`), not to
X11's primary selection, so `Ctrl+V` reaches them. Stock zathura uses primary,
which is why selection appears to do nothing in most people's setup.

Column-selecting from a two-column paper needs the `^drag` rectangular mode;
plain dragging will interleave the columns.

---

## 12. Things vim taught you that are wrong here

Worth reading once, in full. These are the keys that will bite.

| Key | vim | zathura |
|-----|-----|---------|
| `y` | yank | **scroll a full page right** |
| `t` | till-char | **scroll a full page left** |
| `^y` `^e` | scroll one line | `^y` is **half page right**; `^e` is unbound |
| `d` | delete operator | **toggle dual-page view** |
| `r` | replace char | **rotate 90°** |
| `i` | insert | **recolor** (config; unbound by default) |
| `p` | paste | unbound — `P` is **snap to page** |
| `f` | find char in line | **follow link** (hint mode) |
| `c` | change operator | **copy link target** |
| `n=` | — | **zoom to n%**, not a repeat count for `=` |
| `a` `s` | append / substitute | **fit page / fit width** |
| `o` `O` | open line | **open a document** |
| `R` | replace mode | **reload document** |

The nastiest is `y`/`t`: on a page already fitted to width they appear to do
nothing at all, and on a zoomed page they fling the view sideways. If the
document suddenly jumps horizontally for no reason, you hit one of them — `s`
puts it back.

The friendly surprise is that counts, `/`, `n`, `N`, `gg`, `G`, `ma`/`'a`,
`^o`/`^i`, `:`, `Esc` and `^c` all mean exactly what you expect.

---

## 13. What the config adds

Normal mode:

```
i           recolor                       (invert; <C-r> is awkward to type)
<A-r>       rotate counter-clockwise      (r only goes clockwise)
^p          print
Y           copy the document's path to the clipboard (wl-copy)
gy          open this file's directory in yazi, in a new ghostty
```

Plus the mode-parity work in §2: fullscreen gains scrolling, search, the index,
links, fit and the jumplist; presentation gains `h j k l`; index gains `gg`,
`G`, `^d`, `^u` and `q`/`Esc` to leave.

Everything else in the rc is settings rather than bindings — the palette, sqlite
for last-position, clipboard selection, fit-to-width on open, and the dual-page
column offset. Each line is commented in place.

---

## 14. Recipes

**Reading a paper.** Open, `s` if it is not already width-fitted, `^d` through
it. Hit a citation: `f`, number, read, `^o`. Hit a figure reference: `/Figure 3`,
`n` until you land on it, `^o` back.

**Working through a textbook.** `Tab` for the index, `L` to expand, `Return` on
the chapter. `ma` where you stop. Next session it reopens on the same page
anyway (sqlite), and `'a` is there if you wandered. `:offset` first if the PDF
page numbers and the printed ones disagree.

**Reading at night.** `^r`. If the figures go strange, `^r` again and turn down
the monitor instead — that is the honest answer for anything with real graphics.

**Presenting slides.** `F5`, then `l`/`h` or `Space`/`<S-Space>`. `F11` if you
want fullscreen but still need to scroll and search — in this config that mode
is fully usable, which it is not by default.

**A PDF that will not search.** `:info` to see whether it is a scan. If it is,
`ocrmypdf in.pdf out.pdf` and reopen; `filemonitor` means writing over the same
filename reloads it under you.  (`ocrmypdf` is an apt package, not installed.)

**Iterating on a generated PDF.** Just leave zathura open. `filemonitor` plus
`smooth-reload` means each rebuild appears in place without losing your page,
scroll position or zoom. No keypress, no window switching.

---

## 15. Where the state lives

```
~/.config/zathura/zathurarc              this config
~/.local/share/zathura/bookmarks.sqlite  quickmarks, bookmarks, last position
~/.local/share/zathura/history           recently opened
~/.cache/zathura/                        render cache; safe to delete
```

Deleting the sqlite file resets every bookmark and every remembered page, for
every document, with no confirmation. It is the one file here worth backing up.

---

## 16. Command-line flags worth knowing

```
zathura -P 42 file.pdf              open on page 42
zathura -f "phrase" file.pdf        open with a search already run
zathura -b intro file.pdf           open at a named bookmark
zathura --mode=presentation f.pdf   straight into F5
zathura -w password file.pdf        encrypted PDF
zathura -c /tmp/altconfig f.pdf     different config dir — how to test rc edits
                                    without touching the real one
```

That last one is the answer to "zathura only reads its config at startup": point
a throwaway instance at a scratch config directory, iterate there, then paste the
lines you kept into the real rc.
