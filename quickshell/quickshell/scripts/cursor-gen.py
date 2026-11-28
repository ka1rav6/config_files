#!/usr/bin/env python3
"""Accent-coloured cursor themes, written as XCursor themes.

Usage:
  cursor-gen.py STYLE '#rrggbb' [SPEED]     build; prints the theme name
  cursor-gen.py preview OUTDIR '#rrggbb'    PNG previews of every style

The colour may also be 'invert': the shapes are drawn pure white, rim and all,
for the qs-pointer plugin to draw INVERTED (the opposite of whatever is under
each pixel: white over black, black over white). On its own, without the
plugin inverting it, such a theme is just a white cursor. Its name uses
'invert' in place of the hex.

STYLE is Fluent, Circle, Dot, Ring or Arrow. SPEED (Fluent and Circle) is fast,
normal or slow.

Builds ~/.local/share/icons/QS-<Style>-<hex>[-<speed>]. The colour (and speed)
are part of the name because Hyprland will not reload a theme under a name it
has already loaded; older copies of the same style are removed.

THE STYLES
  Fluent  A dot that MORPHS into each shape -- a soft highlight over links, a
          thin bar over text, a pill with arrows for resizing, a ring with a
          slash for "not allowed". Each shape is a short animation starting
          from the dot whose last frame holds (Hyprland restarts a cursor's
          animation whenever the shape changes, which is what plays the morph).
          pop_<name> copies hold a short swell-and-settle that the qs-pointer
          Hyprland plugin plays on a click ("press bounce").
  Circle  ALWAYS the same round dot -- over links, text, resize edges, everything
          -- with the centre as the hotspot. Its pop_<name> copies are a
          springy pulse (swells, dips smaller, settles) that the plugin plays
          on every click.
  Dot     a still dot; links get a ring round it, text an I-beam
  Ring    a hollow ring; links get a filled dot
  Arrow   a classic arrow pointer, in the accent, clicking at its tip

Every shape is drawn 4x oversized and scaled down, at every common size, so it
stays crisp on the 1.5x panel and the 1x external monitor alike.
"""
import math
import shutil
import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ICONS = Path.home() / ".local/share/icons"
SIZES = [16, 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 96]
SS = 4
EDGE = (12, 14, 18)          # the rim that keeps it readable; set per colour in main()
HOLD = 3600000               # ms: "hold the last frame"
SPEEDS = {"fast": 10, "normal": 16, "slow": 28}   # ms per morph frame
MORPH_FRAMES = 8
POP_FRAMES = 10
SPIN_FRAMES = 12
CIRCLE_D = 0.30              # Circle: diameter as a fraction of the cursor size
CIRCLE_POP_FRAMES = 16
CIRCLE_SPEEDS = {"fast": 12, "normal": 18, "slow": 28}   # ms per pulse frame

# --- which cursor names get which shape ---------------------------------------
GROUPS = {
    "pointer": ["default", "left_ptr", "arrow", "top_left_arrow", "right_ptr", "context-menu", "copy",
                "alias", "dnd-copy", "dnd-link", "dnd-ask", "center_ptr", "draft", "color-picker",
                "pencil", "vertical-text", "zoom-in", "zoom-out"],
    "hand": ["pointer", "hand", "hand1", "hand2", "pointing_hand", "link",
             "e29285e634086352946a0e7090d73106", "9d800788f1b08800ae810202380a0822"],
    "text": ["text", "xterm", "ibeam"],
    "grab": ["grab", "openhand", "5aca4d189052212118709018842178c0"],
    "grabbing": ["grabbing", "closedhand", "move", "fleur", "all-scroll", "size_all", "dnd-move",
                 "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f"],
    "ew": ["ew-resize", "e-resize", "w-resize", "col-resize", "size_hor", "sb_h_double_arrow",
           "h_double_arrow", "left_side", "right_side", "split_h",
           "14fef782d02440884392942c11205230", "028006030e0e7ebffc7f7070c0600140"],
    "ns": ["ns-resize", "n-resize", "s-resize", "row-resize", "size_ver", "sb_v_double_arrow",
           "v_double_arrow", "top_side", "bottom_side", "split_v",
           "2870a09082c103050810ffdffffe0204", "00008160000006810000408080010102"],
    "nwse": ["nwse-resize", "nw-resize", "se-resize", "size_fdiag", "top_left_corner",
             "bottom_right_corner", "c7088f0f3e6c8088236ef8e1e3e70000"],
    "nesw": ["nesw-resize", "ne-resize", "sw-resize", "size_bdiag", "top_right_corner",
             "bottom_left_corner", "fcf1c3c7cd4491d801f1e1c78f100000"],
    "no": ["not-allowed", "no-drop", "dnd-no-drop", "dnd-none", "crossed_circle", "forbidden",
           "X_cursor", "pirate", "03b6e0fcb3499374a867c041f52298f0"],
    "cross": ["crosshair", "cross", "tcross", "cell", "plus", "diamond_cross"],
    "help": ["help", "question_arrow", "whats_this", "d9ce0ab605698f320427677b458ad60b",
             "5c6cd98b3f3ebcb1f9c7f1c204630408"],
    "wait": ["wait", "watch", "progress", "left_ptr_watch", "half-busy",
             "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd",
             "3ecb610c1bf2410f44200f48c40d3599"],
}


def rgb(hexstr):
    if hexstr == "invert":
        return (255, 255, 255)
    h = hexstr.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def tag(color):
    """What the colour is called in theme and preview names."""
    return "invert" if color == "invert" else color.lstrip("#").lower()[:6]


def set_colour(color):
    """The accent, and the rim to go with it. Inverted cursors get a white
    rim: under inversion a dark rim would just darken the screen round the
    shape, while a white one at partial opacity becomes a soft inverted edge."""
    accent = rgb(color)
    set_edge(accent)
    if color == "invert":
        global EDGE
        EDGE = (255, 255, 255)
    return accent


def set_edge(accent):
    """A dark rim round light colours, a light rim round dark ones, so a black
    cursor still reads on a dark window and a white one on a white page."""
    global EDGE
    r, g, b = accent
    lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
    EDGE = (12, 14, 18) if lum > 0.3 else (232, 234, 238)


def canvas(size):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def finish(img, size):
    return img.resize((size, size), Image.LANCZOS)


# --- Fluent: one rounded shape that changes size, fill and decoration ----------
# (width, height, fill alpha, outlined, decoration, rotation) as fractions of
# the cursor size; the decoration fades in with the morph.
def tri(d, x, y, ang, r, col):
    pts = [(x + r * math.cos(math.radians(ang + k)), y - r * math.sin(math.radians(ang + k))) for k in (0, 140, -140)]
    d.polygon(pts, fill=col)


def arrows(dirs, dist):
    def deco(d, s, c, accent, t):
        if t <= 0:
            return
        for a in dirs:
            r = s * dist * t
            x, y = c + r * math.cos(math.radians(a)), c - r * math.sin(math.radians(a))
            tri(d, x, y, a, s * 0.09, EDGE + (round(150 * t),))
            tri(d, x, y, a, s * 0.065, accent + (round(255 * t),))
    return deco


def slash(d, s, c, accent, t):
    if t > 0:
        k, w = s * 0.17 * t, max(SS, round(s * 0.05))
        d.line((c - k, c + k, c + k, c - k), fill=accent + (round(255 * t),), width=w)


def crosshair(d, s, c, accent, t):
    if t <= 0:
        return
    k, g, w = s * 0.3 * t, s * 0.08, max(SS, round(s * 0.04))
    for col, extra in ((EDGE + (round(140 * t),), 2 * SS), (accent + (round(255 * t),), 0)):
        for a, b in ((1, 0), (0, 1)):
            d.line((c - k * a, c - k * b, c - g * a, c - g * b), fill=col, width=w + extra)
            d.line((c + g * a, c + g * b, c + k * a, c + k * b), fill=col, width=w + extra)


def question(d, s, c, accent, t):
    if t > 0:
        d.text((c, c), "?", fill=accent + (round(255 * t),), anchor="mm", font_size=s * 0.32)


FLUENT = {
    "pointer":  (0.20, 0.20, 255, False),
    "hand":     (0.58, 0.58, 60, True),
    "text":     (0.085, 0.60, 255, False),
    "grab":     (0.38, 0.38, 60, True),
    "grabbing": (0.15, 0.15, 255, False, arrows((0, 90, 180, 270), 0.3)),
    "ew":       (0.42, 0.13, 255, False, arrows((0, 180), 0.32)),
    "ns":       (0.13, 0.42, 255, False, arrows((90, 270), 0.32)),
    "nwse":     (0.42, 0.13, 255, False, arrows((0, 180), 0.32), -45),
    "nesw":     (0.42, 0.13, 255, False, arrows((0, 180), 0.32), 45),
    "no":       (0.46, 0.46, 40, True, slash),
    "cross":    (0.07, 0.07, 255, False, crosshair),
    "help":     (0.46, 0.46, 40, True, question),
}


def blob(size, accent, w, h, fill, edge, deco=None, t=1.0, rot=0):
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS
    c, w, h, p = s / 2, w * s / 2, h * s / 2, SS * 2
    d.rounded_rectangle((c - w - p, c - h - p, c + w + p, c + h + p), min(w, h) + p, fill=EDGE + (120,))
    d.rounded_rectangle((c - w, c - h, c + w, c + h), min(w, h), fill=accent + (fill,),
                        outline=accent + (255,) if edge else None, width=max(SS, round(s * 0.035)))
    if deco:
        deco(d, s, c, accent, t)
    if rot:
        img = img.rotate(rot, Image.BICUBIC)
    return finish(img, size)


def fluent_frame(size, accent, shape, f):
    """Frame f of the morph from the dot to `shape` (ease-out)."""
    t = 1 - (1 - f / (MORPH_FRAMES - 1)) ** 3
    a, b = FLUENT["pointer"], FLUENT[shape]
    lerp = lambda i: a[i] + (b[i] - a[i]) * t
    deco = b[4] if len(b) > 4 else None
    rot = (b[5] if len(b) > 5 else 0) * t
    return blob(size, accent, lerp(0), lerp(1), round(lerp(2)), b[3] if t > 0.5 else a[3], deco, t, rot)


def pop_frame(size, accent, shape, f):
    """Frame f of the press bounce: swells fast, settles back to the shape."""
    x = f / (POP_FRAMES - 1)
    k = 1 + 0.4 * (x / 0.3 if x < 0.3 else 1 - ((x - 0.3) / 0.7) ** 0.7) if x < 1 else 1
    b = FLUENT[shape]
    return blob(size, accent, b[0] * k, b[1] * k, b[2], b[3], b[4] if len(b) > 4 else None, 1, b[5] if len(b) > 5 else 0)


# --- Circle: one dot for every shape, pulsing on a click -------------------------
def circle(size, accent, k=1.0):
    """The dot, scaled by k (1 = rest)."""
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS
    c, r, rim = s / 2, s * CIRCLE_D / 2 * k, max(SS * 1.5, s * 0.03)
    d.ellipse((c - r - rim, c - r - rim, c + r + rim, c + r + rim), fill=EDGE + (150,))
    d.ellipse((c - r, c - r, c + r, c + r), fill=accent + (255,))
    return finish(img, size)


def circle_pulse(x):
    """Scale at x in 0..1 of the click pulse: a damped spring that swells to
    ~1.6x, dips to ~0.7x, overshoots a touch and lands back on exactly 1."""
    return 1 + 0.85 * math.exp(-2.2 * x) * math.sin(3 * math.pi * x)


# --- still styles (Dot, Ring, Arrow) -------------------------------------------
def still(kind, style, size, accent):
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS
    c = s / 2
    acc = accent + (255,)
    edge = EDGE + (200,)
    rim = max(SS, s // 28)

    def dot(r, fill=acc):
        d.ellipse((c - r - rim, c - r - rim, c + r + rim, c + r + rim), fill=edge)
        d.ellipse((c - r, c - r, c + r, c + r), fill=fill)

    def ring(r, w):
        d.ellipse((c - r - rim, c - r - rim, c + r + rim, c + r + rim), outline=edge, width=w + 2 * rim)
        d.ellipse((c - r, c - r, c + r, c + r), outline=acc, width=w)

    def double_arrow(angle):
        L, head, w = s * 0.36, s * 0.13, max(SS * 2, s // 14)
        ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        p0 = (c - ca * (L - head), c - sa * (L - head))
        p1 = (c + ca * (L - head), c + sa * (L - head))
        for col, extra in ((edge, 2 * rim), (acc, 0)):
            d.line([p0, p1], fill=col, width=w + extra)
            for sgn in (1, -1):
                tip = (c + sgn * ca * L, c + sgn * sa * L)
                base = (c + sgn * ca * (L - head * 1.6), c + sgn * sa * (L - head * 1.6))
                nx, ny = -sa * head, ca * head
                pts = [tip, (base[0] + nx, base[1] + ny), (base[0] - nx, base[1] - ny)]
                if extra:
                    gx, gy = sum(p[0] for p in pts) / 3, sum(p[1] for p in pts) / 3
                    k = 1 + extra * 0.8 / head
                    pts = [(gx + (p[0] - gx) * k, gy + (p[1] - gy) * k) for p in pts]
                d.polygon(pts, fill=col)

    if kind == "pointer" and style == "Arrow":
        # Classic arrow, tip at (0.2, 0.12) of the canvas: that is the hotspot.
        pts = [(0.0, 0.0), (0.0, 0.66), (0.16, 0.51), (0.27, 0.76), (0.37, 0.71), (0.26, 0.47), (0.47, 0.47)]
        pts = [(s * (0.2 + x * 0.95), s * (0.12 + y * 0.95)) for x, y in pts]
        d.polygon(pts, fill=edge, outline=edge, width=rim * 3)
        d.polygon(pts, fill=acc)
    elif kind == "pointer":
        if style == "Ring":
            ring(s * 0.17, max(SS * 2, s // 16))
            dot(s * 0.045)
        else:
            dot(s * 0.15)
    elif kind == "hand":
        if style == "Ring":
            dot(s * 0.2)
        else:
            ring(s * 0.24, max(SS * 2, s // 18))
            dot(s * 0.1)
    elif kind == "text":
        w, h = max(SS * 2, s // 12), s * 0.62
        d.rounded_rectangle((c - w / 2 - rim, c - h / 2 - rim, c + w / 2 + rim, c + h / 2 + rim), radius=w, fill=edge)
        d.rounded_rectangle((c - w / 2, c - h / 2, c + w / 2, c + h / 2), radius=w / 2, fill=acc)
    elif kind == "cross":
        L, w = s * 0.32, max(SS * 2, s // 16)
        for col, extra in ((edge, 2 * rim), (acc, 0)):
            d.line([(c - L, c), (c + L, c)], fill=col, width=w + extra)
            d.line([(c, c - L), (c, c + L)], fill=col, width=w + extra)
    elif kind in ("grab", "grabbing"):
        double_arrow(0)
        double_arrow(90)
    elif kind == "no":
        r, w = s * 0.26, max(SS * 2, s // 12)
        ring(r, w)
        o = r * 0.7
        for col, extra in ((edge, 2 * rim), (acc, 0)):
            d.line([(c - o, c + o), (c + o, c - o)], fill=col, width=w + extra)
    elif kind == "help":
        ring(s * 0.24, max(SS * 2, s // 16))
        d.text((c, c), "?", fill=acc, anchor="mm", font_size=s * 0.3)
    elif kind in ("ew", "ns", "nwse", "nesw"):
        double_arrow({"ew": 0, "ns": 90, "nwse": 45, "nesw": 135}[kind])
    return finish(img, size)


def spinner(size, accent, frame):
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS
    c, r, w = s / 2, s * 0.24, max(SS * 2, round(s * 0.07))
    box = (c - r, c - r, c + r, c + r)
    d.ellipse((box[0] - SS, box[1] - SS, box[2] + SS, box[3] + SS), outline=EDGE + (110,), width=w + 2 * SS)
    d.ellipse(box, outline=accent + (70,), width=w)
    a = frame * 360 / SPIN_FRAMES
    d.arc(box, a, a + 110, fill=accent + (255,), width=w)
    return finish(img, size)


# --- XCursor writer -------------------------------------------------------------
def xcursor(frames):
    """frames(size) -> list of (PIL image, delay ms, hotspot x fraction, hotspot y fraction)."""
    chunks = []
    for size in SIZES:
        for img, delay, hx, hy in frames(size):
            r, g, b, a = img.convert("RGBa").split()       # premultiplied
            px = Image.merge("RGBA", (b, g, r, a)).tobytes()  # little-endian ARGB
            hdr = struct.pack("<9I", 36, 0xFFFD0002, size, 1, size, size,
                              min(size - 1, round(size * hx)), min(size - 1, round(size * hy)), delay)
            chunks.append((size, hdr + px))
    out = [struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(chunks))]
    pos = 16 + 12 * len(chunks)
    for size, data in chunks:
        out.append(struct.pack("<III", 0xFFFD0002, size, pos))
        pos += len(data)
    return b"".join(out + [d for _, d in chunks])


def files_for(style, accent, speed):
    """[(names, bytes)] for a style."""
    out = []
    spin = lambda size: [(spinner(size, accent, f), 60, 0.5, 0.5) for f in range(SPIN_FRAMES)]
    if style == "Fluent":
        delay = SPEEDS.get(speed, 16)

        def morph(shape):
            return lambda size: [(fluent_frame(size, accent, shape, f),
                                  HOLD if f == MORPH_FRAMES - 1 else delay, 0.5, 0.5)
                                 for f in range(MORPH_FRAMES)]

        def bounce(shape):
            return lambda size: [(pop_frame(size, accent, shape, f),
                                  HOLD if f == POP_FRAMES - 1 else 16, 0.5, 0.5)
                                 for f in range(POP_FRAMES)]

        for group, names in GROUPS.items():
            if group == "wait":
                data = xcursor(spin)
                out.append((names, data))
                out.append((["pop_" + n for n in names], data))
                continue
            # The plain pointer holds still: Hyprland restarts an animation
            # whenever the shape is set again, and a grow-in would flicker.
            if group == "pointer":
                first = lambda size: [(fluent_frame(size, accent, "pointer", MORPH_FRAMES - 1), 0, 0.5, 0.5)]
            else:
                first = morph(group)
            out.append((names, xcursor(first)))
            out.append((["pop_" + n for n in names], xcursor(bounce(group))))
    elif style == "Circle":
        delay = CIRCLE_SPEEDS.get(speed, 18)
        n = CIRCLE_POP_FRAMES
        rest = xcursor(lambda size: [(circle(size, accent), 0, 0.5, 0.5)])
        pulse = xcursor(lambda size: [(circle(size, accent, circle_pulse(f / (n - 1))),
                                       HOLD if f == n - 1 else delay, 0.5, 0.5)
                                      for f in range(n)])
        # Every name, "wait" included, is the same dot: it never changes shape.
        everything = [name for names in GROUPS.values() for name in names]
        out.append((everything, rest))
        out.append((["pop_" + name for name in everything], pulse))
    else:
        for group, names in GROUPS.items():
            if group == "wait":
                out.append((names, xcursor(spin)))
                continue
            tip = style == "Arrow" and group == "pointer"
            out.append((names, xcursor(lambda size, g=group, tip=tip:
                                       [(still(g, style, size, accent), 0, 0.2 if tip else 0.5, 0.12 if tip else 0.5)])))
    return out


def ensure_reachable(name):
    """Make ~/.local/share/icons/<name> findable through ~/.icons.

    Ubuntu's libXcursor (what Hyprland draws its cursor with) searches only
    ~/.icons:/usr/share/icons:/usr/share/pixmaps, and reads that once, at
    start. libwayland-cursor (Qt, Chrome) skips ~/.local/share/icons unless
    XDG_DATA_HOME is set. Themes only under ~/.local/share/icons therefore fall
    back to the plain arrow there. ~/.icons is searched by all of them, and
    re-checked on every theme load, so this works without a restart."""
    legacy = Path.home() / ".icons"
    if not legacy.exists() and not legacy.is_symlink():
        legacy.symlink_to(ICONS)                    # the whole directory
    elif legacy.is_dir() and legacy.resolve() != ICONS.resolve():
        link = legacy / name                        # a real ~/.icons: per theme
        if not link.exists():
            if link.is_symlink():
                link.unlink()
            link.symlink_to(ICONS / name)


def build(style, color, speed):
    accent = set_colour(color)
    hexname = tag(color)
    name = f"QS-{style}-{hexname}" + (f"-{speed}" if style in ("Fluent", "Circle") else "")
    dest = ICONS / name
    if not (dest / "cursors" / "default").exists():
        tmp = ICONS / f".{name}.new"
        shutil.rmtree(tmp, ignore_errors=True)
        (tmp / "cursors").mkdir(parents=True)
        (tmp / "index.theme").write_text(f"[Icon Theme]\nName={name}\nComment=Accent {style} cursor, generated by Quickshell\n")
        for names, data in files_for(style, accent, speed):
            (tmp / "cursors" / names[0]).write_bytes(data)
            for alias in names[1:]:
                (tmp / "cursors" / alias).symlink_to(names[0])
        shutil.rmtree(dest, ignore_errors=True)
        tmp.rename(dest)
    for old in ICONS.glob(f"QS-{style}-*"):
        if old.name != name:
            shutil.rmtree(old, ignore_errors=True)
    ensure_reachable(name)
    print(name)


def preview(outdir, color):
    """accent-<Style>-<hex>.png: pointer, link and text side by side at 48 px."""
    accent = set_colour(color)
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    hexname = tag(color)
    for style in ("Fluent", "Circle", "Dot", "Ring", "Arrow"):
        dest = out / f"accent-{style}-{hexname}.png"
        if dest.exists():
            continue
        if style == "Circle":
            # rest, swelled, dipped: the click pulse at a glance
            imgs = [circle(48, accent, k) for k in (1.0, 1.6, 0.7)]
        elif style == "Fluent":
            imgs = [fluent_frame(48, accent, k, MORPH_FRAMES - 1) for k in ("pointer", "hand", "text")]
        else:
            imgs = [still(k, style, 48, accent) for k in ("pointer", "hand", "text")]
        sheet = Image.new("RGBA", (48 * 3 + 16, 48), (0, 0, 0, 0))
        for i, im in enumerate(imgs):
            sheet.alpha_composite(im, (i * 56, 0))
        sheet.save(dest)
    print(out)


def main():
    if len(sys.argv) >= 4 and sys.argv[1] == "preview":
        preview(sys.argv[2], sys.argv[3])
        return
    if len(sys.argv) < 3 or sys.argv[1] not in ("Fluent", "Circle", "Dot", "Ring", "Arrow"):
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    build(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "normal")


if __name__ == "__main__":
    main()
