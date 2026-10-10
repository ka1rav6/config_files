#!/usr/bin/env python3
"""Type-aware opener for yazi's `o` bind (~/.config/yazi/keymap.toml).

All of the policy -- which extension goes to which app -- lives in
~/.config/yazi/openers.toml. This file is only the mechanism, and should not
need editing to add or change an app.

The config is read on every invocation, so edits take effect on the next `o`
with nothing to reload.

---------------------------------------------------------------------------
Why this script exists at all, rather than a bare `ghostty -e nvim <file>`:

yazi normally runs inside the SUPER+E scratchpad, and Hyprland maps a newly
created window onto the *active* workspace -- which, while a special workspace
is showing, is that special workspace. Anything launched from the scratchpad
therefore opened hidden, tiled beside yazi, and vanished again on the next
toggle. Dismissing the scratchpad first hands focus back to the real
workspace, so the app lands where you are actually looking.

hyprctl eval is a synchronous IPC round-trip, so the switch has already
happened before any app is started -- no race with the new window mapping.
scratchpads.dismiss_active() is a no-op when no scratchpad is involved (the
tiled yazi on SUPER+ALT+E, or yazi in any ordinary terminal), so this stays
correct there too.

Why Python rather than the POSIX sh this replaces: tomllib is in the standard
library, so reading real TOML -- with comments, lists and nesting -- costs no
dependency, and shlex gives correct argv splitting for the `run` templates
that sh's word splitting could not do safely.
"""

import fnmatch
import os
import re
import shlex
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

CONFIG = (
    Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    / "yazi"
    / "openers.toml"
)

# Used when openers.toml is missing or unparseable, so a syntax error while
# editing it leaves `o` working rather than dead.
FALLBACK_DEFAULT = {
    "run": "ghostty --working-directory=%d -e ${EDITOR:-nvim} %f",
    "batch": True,
}

ENV_REF = re.compile(r"\$\{(\w+)(?::-([^}]*))?\}")


def warn(message):
    """Report a config problem both to stderr and to the desktop.

    yazi runs this with `--orphan`, which sends stderr to /dev/null, so a
    notification is the only channel the user will actually see.
    """
    print(f"open-file: {message}", file=sys.stderr)
    if shutil.which("notify-send"):
        spawn(["notify-send", "--app-name=yazi", "openers.toml", message])


def spawn(argv):
    """Start a program fully detached, so it survives this script and yazi."""
    try:
        subprocess.Popen(
            argv,
            start_new_session=True,  # setsid: new session, no controlling tty
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError as exc:
        warn(f"could not run {argv[0]!r}: {exc}")


def load_config():
    try:
        with open(CONFIG, "rb") as handle:
            config = tomllib.load(handle)
    except FileNotFoundError:
        warn(f"{CONFIG} not found — falling back to the editor")
        return [], FALLBACK_DEFAULT
    except (tomllib.TOMLDecodeError, OSError) as exc:
        warn(f"{CONFIG.name}: {exc} — falling back to the editor")
        return [], FALLBACK_DEFAULT

    rules = config.get("rules") or []
    default = config.get("default") or FALLBACK_DEFAULT
    if not default.get("run"):
        warn("[default] has no `run` — falling back to the editor")
        default = FALLBACK_DEFAULT
    return rules, default


def expand_env(text):
    """Expand ${VAR} and ${VAR:-fallback}, matching sh's :- semantics."""
    return ENV_REF.sub(
        lambda m: os.environ.get(m.group(1)) or (m.group(2) or ""), text
    )


def build_argv(template, files, cwd):
    """Turn a `run` template plus its files into an argv list.

    A token holding %f or %p repeats once per file, so `vlc %f` on three files
    is one VLC with three arguments. A template naming no file placeholder at
    all gets the paths appended, which is what makes a bare `run = "zathura"`
    work.
    """
    argv = []
    saw_file = False
    for token in shlex.split(expand_env(template)):
        token = token.replace("%d", cwd)
        if "%f" in token or "%p" in token:
            saw_file = True
            for path in files:
                argv.append(
                    token.replace("%f", path).replace("%p", os.path.abspath(path))
                )
        else:
            argv.append(token)
    if not saw_file:
        argv.extend(files)
    return argv


def mime_of(path, cache):
    """`file --mime-type` for one path, memoised — it is a per-file fork."""
    if path not in cache:
        try:
            cache[path] = subprocess.run(
                ["file", "-bL", "--mime-type", path],
                capture_output=True,
                text=True,
                timeout=5,
            ).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            cache[path] = ""
    return cache[path]


def program_of(rule):
    """The executable a rule would run, for the is-it-installed check."""
    argv = shlex.split(expand_env(rule.get("run", "")))
    return argv[0] if argv else ""


def rule_for(path, rules, mime_cache, missing):
    """First rule claiming this path, or None to mean [default].

    A rule that matches on name but whose program is absent is skipped rather
    than obeyed, so an uninstalled app or a typo'd `run` degrades to the editor
    instead of silently doing nothing.
    """
    name = os.path.basename(path).lower()
    for rule in rules:
        extensions = rule.get("ext") or []
        if not any(name.endswith("." + str(e).lower().lstrip(".")) for e in extensions):
            continue

        globs = rule.get("mime")
        if globs:
            mime = mime_of(path, mime_cache)
            if not any(fnmatch.fnmatch(mime, g) for g in globs):
                continue

        program = program_of(rule)
        if not program:
            warn(f"rule for .{extensions[0]} has no `run`")
            continue
        if not shutil.which(program):
            missing.add((program, extensions[0]))
            continue

        return rule
    return None


def main():
    files = sys.argv[1:]
    if not files:
        return 0

    rules, default = load_config()
    mime_cache = {}
    missing = set()

    # Group each file under the rule that will open it, preserving both the
    # rule order and the order files were selected in.
    buckets = []  # list of (rule, [paths]) -- a list, since dicts need hashable keys
    for path in files:
        rule = rule_for(path, rules, mime_cache, missing) or default
        for existing_rule, paths in buckets:
            if existing_rule is rule:
                paths.append(path)
                break
        else:
            buckets.append((rule, [path]))

    for program, extension in sorted(missing):
        warn(f"{program!r} is not installed — .{extension} fell back to the editor")

    # Hand focus back to the real workspace before anything is launched. See
    # the module docstring for why this has to happen first, and synchronously.
    try:
        subprocess.run(
            ["hyprctl", "eval", "scratchpads.dismiss_active()"],
            capture_output=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        pass  # not on Hyprland, or no scratchpad plugin: nothing to dismiss

    # yazi runs this with the cwd already set to the directory being browsed,
    # so %d and an inherited cwd both point at the right place.
    cwd = os.getcwd()

    for rule, paths in buckets:
        template = rule.get("run", FALLBACK_DEFAULT["run"])
        if rule.get("batch", True):
            spawn(build_argv(template, paths, cwd))
        else:
            for path in paths:
                spawn(build_argv(template, [path], cwd))

    return 0


if __name__ == "__main__":
    sys.exit(main())
