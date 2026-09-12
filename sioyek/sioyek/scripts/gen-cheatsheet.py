#!/usr/bin/env python3
"""
Build a dark-themed PDF cheatsheet from the *live* sioyek config.

It reads ~/.config/sioyek/keys_user.config, so the sheet can never drift
out of sync with your actual keybindings. Page 1-2 are the bindings grouped
by the section headers in that file; the last pages are a complete index of
every command sioyek 2.0 knows, with its key if you've bound one.

Usage: gen-cheatsheet.py [output.pdf]
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

HOME = os.path.expanduser('~')
KEYS_USER = f'{HOME}/.config/sioyek/keys_user.config'
KEYS_DEFAULT = '/etc/sioyek/keys.config'
COMMANDS_RST = '/usr/share/doc/sioyek/html/_sources/commands.rst.txt'
SIOYEK_BIN = '/usr/bin/sioyek'
DEFAULT_OUT = f'{HOME}/.local/share/sioyek/help/sioyek-cheatsheet.pdf'

# ── palette (mirrors prefs_user.config) ────────────────────────────────
COLORS = {
    'bg':      '0C0D10',
    'surface': '15171F',
    'rule':    '272B36',
    'text':    'D8DCE6',
    'muted':   '79839A',
    'accent':  '7AA2F7',   # blue   — section headers
    'amber':   'E0AF68',   # amber  — keycaps (matches search highlight)
    'green':   '9ECE6A',
}

# ── commands sioyek documents poorly or not at all ─────────────────────
EXTRA_DESCRIPTIONS = {
    'goto_beginning': 'Jump to the first page. With a count, jump to that page (150gg).',
    'goto_begining': 'Alias of goto_beginning kept for backwards compatibility.',
    'move_down': 'Scroll down by vertical_move_amount (default 1 inch).',
    'move_up': 'Scroll up by vertical_move_amount (default 1 inch).',
    'move_left': 'Slide the page left, i.e. look further right.',
    'move_right': 'Slide the page right, i.e. look further left.',
    'goto_top_of_page': 'Jump to the top edge of the current page.',
    'goto_bottom_of_page': 'Jump to the bottom edge of the current page.',
    'goto_left': 'Scroll to the left edge of the page, margins included.',
    'goto_right': 'Scroll to the right edge of the page, margins included.',
    'goto_left_smart': 'Scroll to where the text actually starts, ignoring white margins.',
    'goto_right_smart': 'Scroll to where the text actually ends, ignoring white margins.',
    'next_page': 'Advance by exactly one page height.',
    'previous_page': 'Go back by exactly one page height.',
    'next_chapter': 'Jump to the next top-level entry in the table of contents.',
    'prev_chapter': 'Jump to the previous top-level entry in the table of contents.',
    'chapter_search': 'Search, pre-filled with the page range of the current chapter.',
    'ranged_search': 'Search inside an explicit page range you type.',
    'fit_to_page_width': 'Zoom so one page exactly fills the window width.',
    'fit_to_page_width_smart': 'Fit to width, ignoring the page margins so text fills the screen.',
    'fit_to_page_width_ratio': 'Fit to width, but only to fit_to_page_width_ratio of the window.',
    'fit_to_page_height': 'Zoom so one page exactly fills the window height.',
    'fit_to_page_height_smart': 'Fit to height, ignoring the page margins.',
    'goto_next_highlight': 'Jump to the next highlight in this document.',
    'goto_prev_highlight': 'Jump to the previous highlight in this document.',
    'goto_next_highlight_of_type': 'Jump to the next highlight of the selected colour only.',
    'goto_prev_highlight_of_type': 'Jump to the previous highlight of the selected colour only.',
    'goto_highlight_ranged': 'Open the highlight list restricted to a page range.',
    'set_select_highlight_type': 'Choose which colour (a-z) new highlights use.',
    'toggle_select_highlight': 'Auto-highlight anything you select with the mouse.',
    'embed_annotations': 'Write highlights and bookmarks into a real PDF other readers can see.',
    'enter_visual_mark_mode': 'Enter ruler mode without reaching for the mouse.',
    'close_visual_mark': 'Leave ruler mode.',
    'move_visual_mark_down': 'Move the reading ruler down one line, scrolling as needed.',
    'move_visual_mark_up': 'Move the reading ruler up one line.',
    'visual_mark_under_cursor': 'Drop the reading ruler on the line under the mouse.',
    'toggle_visual_scroll': 'Ruler mode: the wheel moves line by line instead of pixel by pixel.',
    'toggle_smooth_scroll_mode': 'Momentum scrolling instead of instant jumps.',
    'toggle_scrollbar': 'Show or hide the scrollbar.',
    'toggle_statusbar': 'Show or hide the status bar.',
    'toggle_titlebar': 'Show or hide the window titlebar.',
    'toggle_fastread': 'Experimental: bolds the leading letters of each word to pull the eye along.',
    'toggle_typing_mode': 'Experimental: type the text you are reading to keep pace.',
    'toggle_hyperdrive_mode': 'Experimental accelerated scrolling mode.',
    'toggle_show_last_command': 'Display the last executed command in the status bar.',
    'keyboard_overview': 'Label on-screen references, then peek at one by typing its label.',
    'keyboard_smart_jump': 'Label on-screen references, then jump to one by typing its label.',
    'overview_under_cursor': 'Peek at whatever the mouse is pointing at, in the overview popup.',
    'smart_jump_under_cursor': 'Jump straight to whatever the mouse is pointing at.',
    'goto_overview': 'Jump to the location currently shown in the overview popup.',
    'close_overview': 'Close the overview popup.',
    'portal_to_overview': 'Create a portal to whatever the overview popup is showing.',
    'overview_to_portal': 'Turn the open overview into a permanent portal.',
    'overview_next_item': 'Show the next search result inside the overview popup.',
    'overview_prev_item': 'Show the previous search result inside the overview popup.',
    'next_preview': 'The guessed reference was wrong — try the next candidate.',
    'previous_preview': 'The guessed reference was wrong — try the previous candidate.',
    'pop_state': 'Go back one step and forget the step you came from.',
    'new_window': 'Open a second sioyek window.',
    'close_window': 'Close this window.',
    'goto_window': 'Search the list of open sioyek windows and switch.',
    'set_page_offset': 'Tell sioyek how far PDF page 1 is from printed page 1, so N gg is honest.',
    'goto_selected_text': 'Re-centre the view on the current selection.',
    'select_rect': 'Drag out a rectangular region — useful for figures and tables.',
    'focus_text': 'Put the ruler on the first line matching a string (used by extensions).',
    'synctex_under_cursor': 'Open the LaTeX source line corresponding to the spot under the mouse.',
    'enter_password': 'Unlock an encrypted document.',
    'reload': 'Reload the current document from disk.',
    'reload_config': 'Re-read prefs and keys without restarting sioyek.',
    'source_config': 'Load an additional config file at runtime.',
    'prefs': 'Open the default preferences file (read-only reference).',
    'prefs_user': 'Open your own prefs_user.config.',
    'prefs_user_all': 'List every preferences file being loaded, in priority order.',
    'keys': 'Open the default keybindings file (read-only reference).',
    'keys_user': 'Open your own keys_user.config.',
    'keys_user_all': 'List every keybindings file being loaded, in priority order.',
    'import': 'Import highlights, bookmarks and portals from a JSON export.',
    'export': 'Export highlights, bookmarks and portals to a JSON file.',
    'execute': 'Run a shell command; %1 is the file path, %2 the file name.',
    'execute_predefined_command': 'Run one of the execute_command_* entries from your prefs.',
    'set_status_string': 'Write a message into the status bar (used by scripts).',
    'clear_status_string': 'Clear a message set by set_status_string.',
    'set_custom_text_color': 'Change the custom-mode text colour at runtime.',
    'set_custom_background_color': 'Change the custom-mode background colour at runtime.',
    'copy_window_size_config': 'Copy the current window geometry as config lines you can paste.',
    'toggle_one_window': 'Show or hide the helper (second) window.',
    'toggle_window_configuration': 'Cycle through the main/helper window layouts.',
    'toggle_horizontal_scroll_lock': 'Stop sideways drift — handy on touchpads.',
    'toggle_mouse_drag_mode': 'Drag with the mouse to pan instead of selecting text.',
    'toggle_custom_color': 'Switch to your custom page colours (custom_*_color in prefs).',
    'goto_link': 'Deprecated alias for goto_portal.',
    'edit_link': 'Deprecated alias for edit_portal.',
    'delete_link': 'Deprecated alias for delete_portal.',
    'search_selected_text_in_google_scholar': 'Legacy: superseded by external_search with search_url_s.',
    'search_selected_text_in_libgen': 'Legacy: superseded by external_search with search_url_l.',
    'donate': 'Open the author\'s donation page.',
    'debug': 'Internal debugging command.',
    'test_command': 'Internal test command.',
}

# Commands in the binary that aren't user-facing
NOT_COMMANDS = {
    'shader_path', 'default_config_path', 'default_keys_path',
    'execute_command_', 'setconfig_',
}

# Custom commands defined in prefs_user.config
CUSTOM_DESCRIPTIONS = {
    '_help': 'Open this cheatsheet (rebuilds it if your keys have changed).',
    '_rebuild_help': 'Force a rebuild of this cheatsheet.',
    '_copy_clean': 'Yank the selection with hyphenation and hard line-breaks repaired.',
    '_cite': 'Copy "Title, p. N" — plus the selection as a quote — to the clipboard.',
    '_export_highlights': 'Write every highlight in this document to a Markdown file.',
    '_backup': 'Snapshot the highlights/bookmarks/portals database.',
    '_reveal': 'Open the current document\'s folder in the file manager.',
}


# ── LaTeX helpers ──────────────────────────────────────────────────────
def tex_escape(s):
    repl = {'\\': r'\textbackslash{}', '&': r'\&', '%': r'\%', '$': r'\$',
            '#': r'\#', '_': r'\_', '{': r'\{', '}': r'\}',
            '~': r'\textasciitilde{}', '^': r'\textasciicircum{}',
            '<': r'\textless{}', '>': r'\textgreater{}'}
    return ''.join(repl.get(c, c) for c in s)


KEY_NAMES = {
    'space': 'Space', 'tab': 'Tab', 'esc': 'Esc', 'backspace': 'Bksp',
    'home': 'Home', 'end': 'End', 'pageup': 'PgUp', 'pagedown': 'PgDn',
    'left': '<--', 'right': '-->', 'up': 'Up', 'down': 'Down',
    'enter': 'Enter', 'return': 'Enter', 'delete': 'Del', 'insert': 'Ins',
}
MODS = {'C': 'Ctrl', 'S': 'Shift', 'A': 'Alt', 'M': 'Meta'}


def split_tokens(key):
    """Split a sioyek key spec into individual chords."""
    out, i = [], 0
    while i < len(key):
        if key[i] == '<':
            depth, j = 0, i
            while j < len(key):
                if key[j] == '<':
                    depth += 1
                elif key[j] == '>':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            out.append(key[i:j + 1])
            i = j + 1
        else:
            out.append(key[i])
            i += 1
    return out


def pretty_chord(tok):
    if not tok.startswith('<'):
        return [tok]
    inner = tok[1:-1]
    parts = []
    m = re.match(r'^((?:[CSAM]-)+)(.*)$', inner)
    if m:
        for mod in re.findall(r'([CSAM])-', m.group(1)):
            parts.append(MODS[mod])
        inner = m.group(2)
    if inner.startswith('<') and inner.endswith('>'):
        inner = inner[1:-1]
    low = inner.lower()
    if low in KEY_NAMES:
        parts.append(KEY_NAMES[low])
    elif re.fullmatch(r'f\d{1,2}', low):
        parts.append('F' + low[1:])
    elif inner:
        parts.append(inner)
    return parts


def render_key(key):
    """Render a key spec as a row of LaTeX keycaps."""
    caps = []
    for tok in split_tokens(key):
        chord = pretty_chord(tok)
        caps.append('\\,'.join(f'\\kc{{{tex_escape(c)}}}' for c in chord))
    return '~'.join(caps)


# ── config parsing ─────────────────────────────────────────────────────
def parse_keys(path):
    """-> [(section, [(command, key, comment), ...]), ...]"""
    sections, current, pending = [], None, []
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n')
        hdr = re.match(r'^#\s*[─\-=]{2,}\s*(.+?)\s*[─\-=]{2,}\s*$', line)
        if hdr:
            current = (hdr.group(1).strip(), [])
            sections.append(current)
            pending = []
            continue
        if line.strip().startswith('#'):
            txt = line.strip().lstrip('#').strip()
            if txt and not re.match(r'^[─\-=#]+$', txt):
                pending.append(txt)
            continue
        if not line.strip():
            pending = []
            continue
        parts = line.split()
        if len(parts) >= 2 and current is not None:
            cmd, key = parts[0], parts[-1]
            comment = ' '.join(pending) if pending else ''
            current[1].append((cmd, key, comment))
            pending = []
    return [(name, items) for name, items in sections if items]


def parse_rst_descriptions():
    if not os.path.exists(COMMANDS_RST):
        return {}
    src = open(COMMANDS_RST, encoding='utf-8').read()
    out = {}
    for block in re.split(r'\n(?=:code:`)', src):
        m = re.match(r'((?::code:`[^`]+`(?:,\s*)?)+)\n\^+\n(.*)', block, re.S)
        if not m:
            continue
        desc = ' '.join(m.group(2).split())
        desc = re.sub(r':code:`([^`]+)`', r'\1', desc)
        desc = re.sub(r'`([^`<]+)\s*<[^>]+>`_', r'\1', desc)
        desc = desc.split('.. ')[0].strip()
        if len(desc) > 240:
            cut = desc[:240].rsplit('. ', 1)[0]
            desc = (cut + '.') if cut else desc[:240] + '...'
        for name in re.findall(r':code:`([^`]+)`', m.group(1)):
            out[name.strip()] = desc
    return out


def _binary_commands():
    """Command names stored as standalone strings in the sioyek binary.

    Incomplete on its own: the compiler pools string literals, so names that
    are a suffix of a longer one (search <- chapter_search, portal <-
    goto_portal) have no standalone entry. Hence the union in all_commands().
    """
    try:
        raw = subprocess.run(['strings', '-n', '3', SIOYEK_BIN],
                             capture_output=True, text=True, timeout=60).stdout
    except Exception:
        return set()
    lines = raw.splitlines()
    try:
        start = lines.index('goto_beginning')
    except ValueError:
        return set()
    names, misses = set(), 0
    for s in lines[start:]:
        if re.fullmatch(r'[a-z][a-z0-9_]{2,}', s):
            names.add(s)
            misses = 0
        else:
            misses += 1
            if misses > 12:
                break
    return names


def _keyfile_commands(path):
    """Commands referenced by a keys.config, including commented-out ones."""
    names = set()
    if not os.path.exists(path):
        return names
    for line in open(path, encoding='utf-8'):
        line = line.strip().lstrip('#').strip()
        parts = line.split()
        # a binding is exactly "command  key"; prose has more fields
        if len(parts) != 2:
            continue
        cmd, key = parts
        if not re.fullmatch(r'(<[^>]*>|[^\s]{1,8})', key):
            continue
        for c in cmd.split(';'):
            if re.fullmatch(r'[a-z_][a-z0-9_]{2,}', c) and not re.fullmatch(r'command\d', c):
                names.add(c)
    return names


# Real commands that are neither standalone strings nor referenced anywhere
KNOWN_EXTRA = {
    'search_selected_text_in_google_scholar',
    'search_selected_text_in_libgen',
}


def all_commands():
    """Every command sioyek 2.0 accepts, from every source we can check."""
    names = _binary_commands()
    names |= set(parse_rst_descriptions())
    names |= _keyfile_commands(KEYS_DEFAULT)
    names |= _keyfile_commands(KEYS_USER)
    names |= KNOWN_EXTRA
    names = {n for n in names if not n.startswith('_')}
    return sorted(names - NOT_COMMANDS)


# ── document ───────────────────────────────────────────────────────────
PREAMBLE = r'''
\documentclass[8pt]{extarticle}
\usepackage[a4paper,landscape,margin=11mm,top=13mm,bottom=11mm]{geometry}
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage{sourcesanspro}
\usepackage[varqu,varl]{inconsolata}
\usepackage{xcolor}
\usepackage{multicol}
\usepackage{tikz}
\usepackage{microtype}
\usepackage[hidelinks]{hyperref}
\usetikzlibrary{shapes.misc}
\pagestyle{empty}
\setlength{\parindent}{0pt}
\setlength{\columnsep}{7mm}
\setlength{\columnseprule}{0.4pt}

%%COLORS%%
\pagecolor{bg}\color{text}
\def\columnseprulecolor{\color{rule}}

% a keycap
\newcommand{\kc}[1]{%
  \tikz[baseline=(n.base)]{
    \node[inner xsep=3pt, inner ysep=1.6pt, rounded corners=2pt,
          fill=surface, draw=rule, line width=0.4pt,
          text=amber, font=\ttfamily\footnotesize] (n) {#1};}}

% one binding row: keys on the left, meaning on the right
\newcommand{\row}[2]{%
  \begin{minipage}[t]{0.40\linewidth}\raggedright\strut #1\end{minipage}%
  \hfill%
  \begin{minipage}[t]{0.575\linewidth}\raggedright\strut
    \color{text}\footnotesize #2\end{minipage}%
  \par\vspace{2.1pt}}

% section header
\newcommand{\sect}[1]{%
  \vspace{4pt}%
  {\color{accent}\bfseries\small\MakeUppercase{#1}}%
  \par\vspace{1pt}%
  {\color{rule}\rule{\linewidth}{0.6pt}}%
  \par\vspace{3.5pt}}

\newcommand{\irow}[2]{%
  \begin{minipage}[t]{0.45\linewidth}\raggedright\strut #1\end{minipage}%
  \hfill%
  \begin{minipage}[t]{0.525\linewidth}\raggedright\strut
    \color{text}\footnotesize #2\end{minipage}%
  \par\vspace{2.1pt}}

\newcommand{\cmdname}[1]{{\ttfamily\footnotesize\color{green}#1}}
\newcommand{\muted}[1]{{\color{muted}#1}}
'''


def build_tex(sections, descriptions, commands, bound):
    L = []
    colors = '\n'.join(f'\\definecolor{{{k}}}{{HTML}}{{{v}}}'
                       for k, v in COLORS.items())
    L.append(PREAMBLE.replace('%%COLORS%%', colors))
    L.append(r'\begin{document}')

    # ── masthead ──
    L.append(r'''
\noindent
\begin{minipage}[b]{0.58\linewidth}
  {\fontsize{26}{28}\selectfont\bfseries\color{text}sioyek}\;%
  {\color{accent}\large vim keymap}\\[3pt]
  \muted{\footnotesize Generated from your live
  \texttt{\string~/.config/sioyek/keys\string_user.config}.
  Press \kc{Ctrl}\,\kc{h} any time.}
\end{minipage}%
\hfill
\begin{minipage}[b]{0.40\linewidth}\raggedleft\footnotesize
  \muted{Most motions take a count:} \kc{1}\kc{0}\kc{j}
  \muted{= ten lines,} \kc{1}\kc{5}\kc{0}\kc{g}\kc{g}
  \muted{= page 150.}\\[2pt]
  \muted{Press} \kc{:} \muted{for the fuzzy command palette.}\\[2pt]
  \muted{Edit keys with} \kc{Ctrl}\,\kc{,} \muted{then reload with}
  \kc{Alt}\,\kc{r}\muted{.}
\end{minipage}
\par\vspace{4pt}
{\color{accent}\rule{\linewidth}{1pt}}
\par\vspace{6pt}
''')

    # ── bindings ──
    L.append(r'\begin{multicols}{3}')
    for name, items in sections:
        # collapse duplicate commands into one row with both keys
        merged, order = {}, []
        for cmd, key, comment in items:
            if cmd not in merged:
                merged[cmd] = {'keys': [], 'comment': comment}
                order.append(cmd)
            merged[cmd]['keys'].append(key)
            if comment and not merged[cmd]['comment']:
                merged[cmd]['comment'] = comment
        L.append(f'\\sect{{{tex_escape(name.lower())}}}')
        for cmd in order:
            e = merged[cmd]
            keys = r'\;\muted{/}\; '.join(render_key(k) for k in e['keys'])
            desc = e['comment'] or descriptions.get(cmd) or \
                CUSTOM_DESCRIPTIONS.get(cmd) or cmd.replace('_', ' ')
            desc = tex_escape(desc)
            L.append(f'\\row{{{keys}}}{{{desc} \\muted{{\\tiny {tex_escape(cmd)}}}}}')
    L.append(r'\end{multicols}')

    # ── full command index ──
    L.append(r'\clearpage')
    L.append(r'''
\noindent
{\fontsize{20}{22}\selectfont\bfseries\color{text}Every command}\;%
{\color{accent}\large sioyek 2.0.0}\\[3pt]
\muted{\footnotesize All %%N%% commands. Ones you have bound show their key;
the rest are reachable from the \kc{:} palette.}
\par\vspace{4pt}
{\color{accent}\rule{\linewidth}{1pt}}
\par\vspace{6pt}
'''.replace('%%N%%', str(len(commands))))
    L.append(r'\begin{multicols}{3}')
    for cmd in commands:
        desc = descriptions.get(cmd, '')
        desc = tex_escape(desc) if desc else r'\muted{--}'
        keys = bound.get(cmd, [])
        # plain spaces here are breakable, so wide rows wrap inside the column
        keytex = (' '.join(render_key(k) for k in keys[:2])) if keys else ''
        head = f'\\cmdname{{{tex_escape(cmd)}}}'
        if keytex:
            head += f' {keytex}'
        L.append(f'\\irow{{{head}}}{{{desc}}}')
    L.append(r'\end{multicols}')
    L.append(r'\end{document}')
    return '\n'.join(L)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUT
    keys_path = KEYS_USER if os.path.exists(KEYS_USER) else KEYS_DEFAULT

    sections = parse_keys(keys_path)
    descriptions = parse_rst_descriptions()
    descriptions.update(EXTRA_DESCRIPTIONS)
    descriptions.update(CUSTOM_DESCRIPTIONS)

    bound = {}
    for _, items in sections:
        for cmd, key, _c in items:
            bound.setdefault(cmd, []).append(key)

    commands = all_commands()
    commands += [c for c in CUSTOM_DESCRIPTIONS
                 if c in bound or c in ('_help', '_rebuild_help')]
    commands = sorted(set(commands))

    tex = build_tex(sections, descriptions, commands, bound)

    with tempfile.TemporaryDirectory() as td:
        src = os.path.join(td, 'cheatsheet.tex')
        with open(src, 'w', encoding='utf-8') as f:
            f.write(tex)
        for _ in range(2):          # twice, so \hfill columns settle
            p = subprocess.run(
                ['pdflatex', '-interaction=nonstopmode', '-halt-on-error',
                 '-output-directory', td, src],
                capture_output=True, text=True)
        pdf = os.path.join(td, 'cheatsheet.pdf')
        if not os.path.exists(pdf):
            sys.stderr.write(p.stdout[-4000:])
            return 1
        os.makedirs(os.path.dirname(out), exist_ok=True)
        shutil.copy(pdf, out)

    print(out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
