#!/usr/bin/env python3
"""
Export the current document's highlights (and bookmarks) to Markdown.

Highlights are grouped by colour, in reading order, each one linking back
into sioyek so clicking a quote in your notes reopens that exact spot.

Usage: export-highlights.py <sioyek_path> <file_path> <local_db> <shared_db>
"""
import os
import re
import sqlite3
import subprocess
import sys
import urllib.parse
from datetime import datetime

# Sioyek's built-in highlight palette (matches highlight_color_* in prefs)
COLOR_NAMES = {
    'a': 'Amethyst', 'b': 'Blue',   'c': 'Caramel', 'd': 'Damson',
    'e': 'Ebony',    'f': 'Forest', 'g': 'Green',   'h': 'Honeydew',
    'i': 'Iron',     'j': 'Jade',   'k': 'Khaki',   'l': 'Lime',
    'm': 'Mallow',   'n': 'Navy',   'o': 'Orpiment','p': 'Pink',
    'q': 'Quagmire', 'r': 'Red',    's': 'Sky',     't': 'Turquoise',
    'u': 'Uranium',  'v': 'Violet', 'w': 'Wine',    'x': 'Xanthin',
    'y': 'Yellow',   'z': 'Zinnia',
}


def status(sioyek, msg):
    try:
        subprocess.run([sioyek, '--execute-command', 'set_status_string',
                        '--execute-command-data', msg],
                       timeout=5, capture_output=True)
    except Exception:
        pass


def clean(text):
    """Repair PDF extraction artefacts."""
    if not text:
        return ''
    text = re.sub(r'[­‐-—-]\n\s*', '', text)
    text = re.sub(r'\s*\n\s*', ' ', text)
    text = text.replace('ﬁ', 'fi').replace('ﬂ', 'fl')
    text = text.replace(' ', ' ').replace('­', '')
    return re.sub(r'\s{2,}', ' ', text).strip()


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        return 1
    sioyek, file_path, local_db, shared_db = sys.argv[1:5]
    file_path = file_path.strip('"')

    if not os.path.exists(file_path):
        status(sioyek, '  no document open')
        return 0

    # path -> md5 hash, which is how annotations are keyed
    with sqlite3.connect(f'file:{local_db}?mode=ro', uri=True) as lc:
        row = lc.execute('select hash from document_hash where path = ?',
                         (file_path,)).fetchone()
    if not row:
        status(sioyek, '  document not in database yet')
        return 0
    doc_hash = row[0]

    with sqlite3.connect(f'file:{shared_db}?mode=ro', uri=True) as sc:
        highlights = sc.execute(
            'select type, desc, begin_y from highlights '
            'where document_path = ? order by begin_y', (doc_hash,)).fetchall()
        bookmarks = sc.execute(
            'select desc, offset_y from bookmarks '
            'where document_path = ? order by offset_y', (doc_hash,)).fetchall()

    if not highlights and not bookmarks:
        status(sioyek, '  no highlights or bookmarks in this document')
        return 0

    title = os.path.splitext(os.path.basename(file_path))[0]
    out_path = os.path.join(os.path.dirname(file_path), f'{title}.highlights.md')

    def plural(n, word):
        return f'{n} {word}' + ('' if n == 1 else 's')

    url = 'file://' + urllib.parse.quote(file_path)
    lines = [
        f'# {title}',
        '',
        f'*{plural(len(highlights), "highlight")}, '
        f'{plural(len(bookmarks), "bookmark")} — '
        f'exported {datetime.now():%Y-%m-%d %H:%M}*',
        '',
        f'Source: [`{os.path.basename(file_path)}`]({url})',
        '',
    ]

    if bookmarks:
        lines += ['## Bookmarks', '']
        for desc, y in bookmarks:
            lines.append(f'- {clean(desc)}')
        lines.append('')

    if highlights:
        # group by colour, preserving reading order inside each group
        groups = {}
        for htype, desc, y in highlights:
            groups.setdefault(htype, []).append((desc, y))

        lines += ['## Highlights', '']
        for htype in sorted(groups):
            name = COLOR_NAMES.get(htype, htype)
            lines += [f'### {name}  `{htype}`', '']
            for desc, y in groups[htype]:
                text = clean(desc)
                if not text:
                    continue
                lines += [f'> {text}', '']

    with open(out_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    status(sioyek,
           f'  {plural(len(highlights), "highlight")} -> {os.path.basename(out_path)}')
    print(out_path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
