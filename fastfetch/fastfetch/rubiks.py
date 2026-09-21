#!/usr/bin/env python3
"""Render an isometric Rubik's cube as ANSI half-block art (2 px per cell row)."""
import math, sys
from PIL import Image

C = {
    'W': (240, 240, 240),
    'Y': (254, 211,  20),
    'R': (200,  30,  56),
    'O': (255,  98,  12),
    'B': (  8,  92, 205),
    'G': (  0, 166,  98),
}
BODY = (22, 22, 26)

# Centre stickers are W (up) / R (left) / B (right): the classic, and a
# combination that actually exists on a real cube. The rest is a scramble
# picked for colour balance -- every colour appears at most 9 times.
TOP = [
    "OWG",
    "WWR",
    "YWB",
]
LEFT = [
    "RYR",
    "GRW",
    "RRO",
]
RIGHT = [
    "BGB",
    "OBB",
    "WBG",
]

FACE_LIGHT = {'T': 1.00, 'L': 0.85, 'R': 0.63}

GAP_K   = 0.075    # sticker inset, as a fraction of the cube half-cell width
ROUND_K = 0.105    # sticker corner radius, same units
GAP = ROUND = 0.0  # filled in by make_geom()
SS     = 5         # supersamples per axis


def shade(rgb, k):
    return tuple(max(0, min(255, int(c * k + 0.5))) for c in rgb)


def sticker_hit(fu, fv, hu, hv, e1, e2):
    """True if the point is inside the rounded, inset sticker.

    hu/hv are the perpendicular widths of the sticker parallelogram; e1/e2 its
    screen-space edge vectors. Corner rounding is evaluated in screen space so
    acute rhombus corners on the top face round the same as square ones.
    """
    t = GAP + ROUND
    du = fu * hu - t
    du2 = (1.0 - fu) * hu - t
    dv = fv * hv - t
    dv2 = (1.0 - fv) * hv - t

    # pick the violated constraint on each axis (at most one per axis)
    au = du if du < du2 else du2
    av = dv if dv < dv2 else dv2
    if au >= 0 and av >= 0:
        return True
    if av >= 0:
        return -au <= ROUND
    if au >= 0:
        return -av <= ROUND
    # both violated -> true distance to the rounded corner's centre
    ou = au / hu * (1 if du < du2 else -1)
    ov = av / hv * (1 if dv < dv2 else -1)
    dx = ou * e1[0] + ov * e2[0]
    dy = ou * e1[1] + ov * e2[1]
    return math.hypot(dx, dy) <= ROUND


def make_geom(W):
    global GAP, ROUND
    GAP, ROUND = GAP_K * W, ROUND_K * W
    H = W / 2.0
    V = math.hypot(W, H)
    A = (W, H)      # +x : right-and-down
    B = (-W, H)     # +y : left-and-down
    Cv = (0.0, -V)  # +z : up
    def perp(e1, e2):
        cr = abs(e1[0] * e2[1] - e1[1] * e2[0])
        return cr / math.hypot(*e2), cr / math.hypot(*e1)
    return dict(W=W, H=H, V=V, A=A, B=B, Cv=Cv,
                T=(A, B) + perp(A, B),
                R=(B, Cv) + perp(B, Cv),
                L=(A, Cv) + perp(A, Cv))


def sample(sx, sy, g):
    W, H, V = g['W'], g['H'], g['V']
    p = (sy + 3 * V) / H
    q = sx / W
    x, y = (q + p) / 2.0, (p - q) / 2.0
    if -1e-9 <= x <= 3 and -1e-9 <= y <= 3:
        face, u, v = 'T', x, y
        base = TOP[min(2, int(v))][min(2, int(u))]
    else:
        y = 3 - sx / W
        z = ((3 + y) * H - sy) / V
        if -1e-9 <= y <= 3 and -1e-9 <= z <= 3:
            face, u, v = 'R', y, z
            base = RIGHT[2 - min(2, int(v))][2 - min(2, int(u))]
        else:
            x = 3 + sx / W
            z = ((x + 3) * H - sy) / V
            if -1e-9 <= x <= 3 and -1e-9 <= z <= 3:
                face, u, v = 'L', x, z
                base = LEFT[2 - min(2, int(v))][min(2, int(u))]
            else:
                return None

    fu, fv = u - math.floor(u), v - math.floor(v)
    if fu >= 1.0: fu = 0.999999
    if fv >= 1.0: fv = 0.999999
    e1, e2, hu, hv = g[face]

    k = FACE_LIGHT[face] * (1.045 - 0.145 * ((sy + 3 * V) / (3 * V + 6 * H)))

    if sticker_hit(fu, fv, hu, hv, e1, e2):
        a, b = fu - 0.5, fv - 0.5
        if face == 'T':
            k *= 1.0 + 0.09 * (-(a + b))
        elif face == 'L':
            k *= 1.0 + 0.12 * (b - a)
        else:
            k *= 1.0 + 0.12 * (a + b)
        return shade(C[base], k)
    return shade(BODY, k)


def render(W):
    g = make_geom(W)
    px_w = int(round(6 * W))
    px_h = int(math.ceil(3 * g['V'] + 6 * g['H']))
    if px_h % 2:
        px_h += 1
    x0, y0 = -3 * W, -3 * g['V']
    grid = []
    for py in range(px_h):
        row = []
        for px in range(px_w):
            acc = [0, 0, 0]; hits = 0
            for sj in range(SS):
                for si in range(SS):
                    c = sample(x0 + px + (si + 0.5) / SS,
                               y0 + py + (sj + 0.5) / SS, g)
                    if c:
                        acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]; hits += 1
            row.append(None if hits * 2 < SS * SS
                       else tuple(v // hits for v in acc))
        grid.append(row)
    return grid


def to_ansi(grid, pad=0):
    out = []
    for r in range(0, len(grid), 2):
        top, bot = grid[r], grid[r + 1]
        line = []; cfg = cbg = None
        for i in range(len(top)):
            t, b = top[i], bot[i]
            if t is None and b is None:
                if cfg is not None or cbg is not None:
                    line.append("\033[0m"); cfg = cbg = None
                line.append(" ")
            elif b is None:
                if cbg is not None:
                    line.append("\033[0m"); cfg = cbg = None
                if t != cfg:
                    line.append("\033[38;2;%d;%d;%dm" % t); cfg = t
                line.append("▀")
            elif t is None:
                if cbg is not None:
                    line.append("\033[0m"); cfg = cbg = None
                if b != cfg:
                    line.append("\033[38;2;%d;%d;%dm" % b); cfg = b
                line.append("▄")
            else:
                if t != cfg:
                    line.append("\033[38;2;%d;%d;%dm" % t); cfg = t
                if b != cbg:
                    line.append("\033[48;2;%d;%d;%dm" % b); cbg = b
                line.append("▀")
        line.append("\033[0m")
        out.append(" " * pad + "".join(line))
    return "\n".join(out)


def to_png(grid, path, zoom=12, bg=(14, 14, 18)):
    h, w = len(grid), len(grid[0])
    img = Image.new("RGB", (w * zoom, h * zoom), bg)
    px = img.load()
    for y in range(h):
        for x in range(w):
            c = grid[y][x]
            if c is None: continue
            for dy in range(zoom):
                for dx in range(zoom):
                    px[x * zoom + dx, y * zoom + dy] = c
    img.save(path)


if __name__ == "__main__":
    Wp = float(sys.argv[1]) if len(sys.argv) > 1 else 7.5
    g = render(Wp)
    print("size: %d cols x %d rows" % (len(g[0]), len(g) // 2), file=sys.stderr)
    if len(sys.argv) > 2:
        to_png(g, sys.argv[2])
    sys.stdout.write(to_ansi(g) + "\n")
