#!/usr/bin/env python3
"""
Anchored slider popup for Waybar (Hyprland / wlr-layer-shell).

Usage: slider-popup.py {brightness|volume|mic}

Opens a small panel just under the bar, near the mouse cursor, with a live
slider plus a numeric field for typing an exact percentage.
Re-running the same mode closes an open popup (click-to-toggle).
"""

import os
import re
import signal
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell  # noqa: E402

# Geometry, in logical pixels. BAR_OFFSET = margin-top + height + gap.
WIDTH = 320
BAR_OFFSET = 8 + 38 + 6
EDGE_PAD = 12
AUTOCLOSE_MS = 5000
FOCUS_GRACE_MS = 700
APPLY_THROTTLE_MS = 40


def run(*args):
    try:
        return subprocess.run(
            args, capture_output=True, text=True, timeout=2
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def spawn(*args):
    try:
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


# --- backends -------------------------------------------------------------


class Brightness:
    name = "brightness"
    title = "Brightness"
    icon = "\U000f00df"
    accent = "#f4c47b"
    lo, hi = 1, 100
    mutable = False

    def get(self):
        line = run("brightnessctl", "-m", "-c", "backlight")
        parts = line.split(",")
        if len(parts) >= 5:
            try:
                cur, mx = int(parts[2]), int(parts[4])
                if mx:
                    return round(cur * 100 / mx), False
            except ValueError:
                pass
        return 50, False

    def set(self, pct):
        spawn("brightnessctl", "-c", "backlight", "-q", "set", f"{pct}%")


class Sink:
    name = "volume"
    title = "Volume"
    icon = "\U000f057e"
    icon_muted = "\U000f075f"
    accent = "#a9c7ff"
    lo, hi = 0, 100
    mutable = True
    target = "@DEFAULT_AUDIO_SINK@"

    def get(self):
        out = run("wpctl", "get-volume", self.target)
        m = re.search(r"([0-9]*\.?[0-9]+)", out)
        pct = round(float(m.group(1)) * 100) if m else 0
        return min(pct, self.hi), "MUTED" in out

    def set(self, pct):
        spawn("wpctl", "set-volume", self.target, f"{pct}%")

    def toggle_mute(self):
        run("wpctl", "set-mute", self.target, "toggle")


class Source(Sink):
    name = "mic"
    title = "Microphone"
    icon = "\U000f036c"
    icon_muted = "\U000f036d"
    accent = "#c5b4ff"
    target = "@DEFAULT_AUDIO_SOURCE@"


BACKENDS = {"brightness": Brightness, "volume": Sink, "mic": Source}

CSS = b"""
window { background: transparent; }
#card {
    background: rgba(18, 20, 24, 0.97);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 11px;
    padding: 12px 14px;
}
#card, #card * {
    font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", sans-serif;
    font-size: 12px;
    font-weight: 600;
    color: rgba(244, 247, 250, 0.92);
}
#glyph { font-size: 17px; padding-right: 4px; }
#title { color: rgba(190, 199, 208, 0.62); font-weight: 500; }
scale { padding: 0; min-height: 20px; }
scale trough {
    background: rgba(255, 255, 255, 0.10);
    border: none;
    border-radius: 5px;
    min-height: 8px;
}
scale highlight { border-radius: 5px; }
scale slider {
    background: #f4f7fa;
    border: none;
    border-radius: 50%;
    min-width: 14px;
    min-height: 14px;
    margin: -4px;
}
entry {
    background: rgba(255, 255, 255, 0.07);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 6px;
    padding: 2px 6px;
    min-height: 22px;
    caret-color: rgba(244, 247, 250, 0.92);
}
entry:focus { border-color: rgba(255, 255, 255, 0.28); }
button {
    background: rgba(255, 255, 255, 0.07);
    border: none;
    border-radius: 6px;
    padding: 2px 9px;
    min-height: 22px;
}
button:hover { background: rgba(255, 255, 255, 0.13); }
"""


class Popup:
    def __init__(self, backend):
        self.be = backend
        self.pending = None
        self.timer = None
        self.inside = False
        self.syncing = False
        self.ready = False

        value, self.muted = self.be.get()

        self.win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.win.set_size_request(WIDTH, -1)
        GtkLayerShell.init_for_window(self.win)
        GtkLayerShell.set_layer(self.win, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(
            self.win, GtkLayerShell.KeyboardMode.ON_DEMAND
        )
        self.place()

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.set_name("card")

        head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.glyph = Gtk.Label()
        self.glyph.set_name("glyph")
        title = Gtk.Label(label=self.be.title, xalign=0)
        title.set_name("title")
        head.pack_start(self.glyph, False, False, 0)
        head.pack_start(title, True, True, 0)

        if self.be.mutable:
            self.mute_btn = Gtk.Button()
            self.mute_btn.connect("clicked", self.on_mute)
            head.pack_end(self.mute_btn, False, False, 0)

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.scale = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, self.be.lo, self.be.hi, 1
        )
        self.scale.set_draw_value(False)
        self.scale.set_value(value)
        self.scale.connect("value-changed", self.on_slide)

        self.entry = Gtk.Entry()
        self.entry.set_width_chars(3)
        self.entry.set_max_length(3)
        self.entry.set_alignment(1.0)
        self.entry.set_text(str(value))
        self.entry.connect("activate", self.on_entry)
        pct = Gtk.Label(label="%")

        row.pack_start(self.scale, True, True, 0)
        row.pack_start(self.entry, False, False, 0)
        row.pack_start(pct, False, False, 0)

        card.pack_start(head, False, False, 0)
        card.pack_start(row, False, False, 0)
        self.win.add(card)

        prov = Gtk.CssProvider()
        prov.load_from_data(
            CSS + f"scale highlight {{ background: {self.be.accent}; }}".encode()
        )
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), prov,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        self.win.add_events(
            Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK
        )
        self.win.connect("enter-notify-event", self.on_enter)
        self.win.connect("leave-notify-event", self.on_leave)
        self.win.connect("focus-in-event", self.on_focus_in)
        self.win.connect("focus-out-event", self.on_focus_out)
        self.win.connect("key-press-event", self.on_key)
        self.win.connect("destroy", Gtk.main_quit)

        self.refresh_glyph()
        self.win.show_all()
        self.scale.grab_focus()
        self.bump()
        GLib.timeout_add(FOCUS_GRACE_MS, self.arm)

    # --- placement --------------------------------------------------------

    def place(self):
        """Anchor top-left, nudged so the card sits centred under the cursor."""
        # -1 lets the card overlap the bar's exclusive zone, so the top
        # margin is measured from the screen edge, not from below the bar.
        GtkLayerShell.set_exclusive_zone(self.win, -1)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.TOP, BAR_OFFSET)

        cur = run("hyprctl", "cursorpos")
        mons = run("hyprctl", "-j", "monitors")
        left = EDGE_PAD
        try:
            import json

            cx, cy = (int(v) for v in cur.split(","))
            for m in json.loads(mons):
                mw = m["width"] / m["scale"]
                mh = m["height"] / m["scale"]
                if m["x"] <= cx < m["x"] + mw and m["y"] <= cy < m["y"] + mh:
                    left = min(
                        max(cx - m["x"] - WIDTH // 2, EDGE_PAD),
                        int(mw) - WIDTH - EDGE_PAD,
                    )
                    self.bind_monitor(m["x"], m["y"])
                    break
        except (ValueError, KeyError, TypeError, json.JSONDecodeError):
            pass
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.LEFT, max(left, 0))

    def bind_monitor(self, mx, my):
        display = Gdk.Display.get_default()
        for i in range(display.get_n_monitors()):
            mon = display.get_monitor(i)
            geo = mon.get_geometry()
            if geo.x == mx and geo.y == my:
                GtkLayerShell.set_monitor(self.win, mon)
                return

    # --- behaviour --------------------------------------------------------

    def arm(self):
        self.ready = True
        return False

    def bump(self):
        if self.timer:
            GLib.source_remove(self.timer)
        self.timer = GLib.timeout_add(AUTOCLOSE_MS, self.maybe_close)

    def maybe_close(self):
        self.timer = None
        if self.inside:
            self.bump()
            return False
        self.close()
        return False

    def on_enter(self, _w, event):
        if event.detail != Gdk.NotifyType.INFERIOR:
            self.inside = True
        self.bump()

    def on_leave(self, _w, event):
        if event.detail != Gdk.NotifyType.INFERIOR:
            self.inside = False
        self.bump()

    def on_focus_in(self, *_):
        self.bump()

    def on_focus_out(self, *_):
        # Hyprland hands focus back to the previously focused window just after
        # a layer surface maps, so focus-out is only a real dismissal signal
        # once that settling period has passed.
        if self.ready:
            self.close()

    def on_key(self, _w, event):
        key = event.keyval
        if key in (Gdk.KEY_Escape, Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            self.close()
            return True
        if key == Gdk.KEY_m and self.be.mutable:
            self.on_mute(None)
            return True
        self.bump()
        return False

    def on_slide(self, scale):
        value = int(round(scale.get_value()))
        if not self.syncing:
            self.syncing = True
            self.entry.set_text(str(value))
            self.syncing = False
        self.bump()
        self.pending = value
        GLib.timeout_add(APPLY_THROTTLE_MS, self.flush)

    def flush(self):
        if self.pending is not None:
            self.be.set(self.pending)
            self.pending = None
        return False

    def on_entry(self, entry):
        try:
            value = int(entry.get_text().strip())
        except ValueError:
            value, _ = self.be.get()
        value = max(self.be.lo, min(self.be.hi, value))
        entry.set_text(str(value))
        self.scale.set_value(value)
        self.flush()
        self.close()

    def on_mute(self, _btn):
        self.be.toggle_mute()
        _, self.muted = self.be.get()
        self.refresh_glyph()
        self.bump()

    def refresh_glyph(self):
        if self.be.mutable and self.muted:
            self.glyph.set_markup(
                f'<span foreground="#ff9b85">{self.be.icon_muted}</span>'
            )
            self.mute_btn.set_label("Unmute")
        else:
            self.glyph.set_markup(
                f'<span foreground="{self.be.accent}">{self.be.icon}</span>'
            )
            if self.be.mutable:
                self.mute_btn.set_label("Mute")

    def close(self):
        self.flush()
        Gtk.main_quit()


# --- single-instance toggle ----------------------------------------------


def toggle_guard(name):
    """Return the pidfile path, or exit after closing an already-open popup."""
    path = os.path.join(
        os.environ.get("XDG_RUNTIME_DIR", "/tmp"), f"waybar-slider-{name}.pid"
    )
    try:
        with open(path) as fh:
            pid = int(fh.read().strip())
        # Confirm the pid is really our popup before signalling it; pids get
        # recycled, and a stale file must not take out an unrelated process.
        with open(f"/proc/{pid}/cmdline", "rb") as fh:
            live = b"slider-popup.py" in fh.read()
        if live:
            os.kill(pid, signal.SIGTERM)
            sys.exit(0)
    except (OSError, ValueError):
        pass
    with open(path, "w") as fh:
        fh.write(str(os.getpid()))
    return path


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "volume"
    if mode not in BACKENDS:
        sys.exit(f"usage: {sys.argv[0]} {{{'|'.join(BACKENDS)}}}")

    pidfile = toggle_guard(mode)
    try:
        Popup(BACKENDS[mode]())
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, Gtk.main_quit)
        Gtk.main()
    finally:
        try:
            os.unlink(pidfile)
        except OSError:
            pass


if __name__ == "__main__":
    main()
