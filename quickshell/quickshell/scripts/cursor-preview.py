#!/usr/bin/env python3
"""PNG previews of installed XCursor themes, for the Settings > Cursor page.

Usage: cursor-preview.py OUTDIR THEME...
Writes OUTDIR/<THEME>.png (the theme's pointer and hand side by side, at 48 px)
for every theme that does not have one yet, and prints "<THEME>\t<path>" for
each theme it has a preview for. Themes it cannot read are skipped silently.
"""
import os
import struct
import sys
from pathlib import Path

from PIL import Image

DIRS = [Path.home() / ".local/share/icons", Path.home() / ".icons", Path("/usr/share/icons")]
WANT = 48


def find(theme, names):
    for d in DIRS:
        for n in names:
            p = d / theme / "cursors" / n
            if p.exists():
                return p
    return None


def read(path):
    data = path.read_bytes()
    if data[:4] != b"Xcur":
        return None
    _, hsize, _, ntoc = struct.unpack_from("<4sIII", data, 0)
    best = None
    for i in range(ntoc):
        typ, sub, pos = struct.unpack_from("<III", data, hsize + i * 12)
        if typ != 0xFFFD0002:
            continue
        if best is None or abs(sub - WANT) < abs(best[0] - WANT):
            best = (sub, pos)
    if best is None:
        return None
    _, _, _, _, w, h, _, _, _ = struct.unpack_from("<IIIIIIIII", data, best[1])
    raw = data[best[1] + 36: best[1] + 36 + w * h * 4]
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for i in range(w * h):
        (v,) = struct.unpack_from("<I", raw, i * 4)
        a = v >> 24
        r, g, b = (v >> 16) & 255, (v >> 8) & 255, v & 255
        if a:  # un-premultiply
            r, g, b = min(255, r * 255 // a), min(255, g * 255 // a), min(255, b * 255 // a)
        px[i % w, i // w] = (r, g, b, a)
    return img.resize((WANT, WANT), Image.LANCZOS) if (w, h) != (WANT, WANT) else img


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for theme in sys.argv[2:]:
        dest = out / f"{theme}.png"
        if not dest.exists():
            try:
                imgs = [read(p) for p in (find(theme, ["left_ptr", "default", "arrow"]),
                                          find(theme, ["hand2", "pointer", "pointing_hand"])) if p]
                imgs = [i for i in imgs if i]
                if not imgs:
                    continue
                sheet = Image.new("RGBA", (WANT * len(imgs) + 8 * (len(imgs) - 1), WANT), (0, 0, 0, 0))
                for k, im in enumerate(imgs):
                    sheet.alpha_composite(im, (k * (WANT + 8), 0))
                sheet.save(dest)
            except Exception:
                continue
        print(f"{theme}\t{dest}")


if __name__ == "__main__":
    main()
