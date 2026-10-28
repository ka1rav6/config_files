#!/usr/bin/env python3
"""First-boot restore: copy every tracked config out of this repo into place.

On a machine that already has ~/.local/share/config-backup/, use `just restore`
instead -- it diffs first, archives what it overwrites, and takes selectors.
That tool is not in this repo (see README, "Known gaps"), so a fresh machine
has only this: no diff, no undo, it just copies.

    python3 bootstrap.py --dry-run     # print source -> destination, touch nothing
    python3 bootstrap.py               # copy it all into place

Where each path belongs is NOT recorded in this repo as a plain list: it is
DEFAULT_BACKUP_PATHS inside custom-binaries/bin/config-backup (the backup tool,
captured by the backup itself) plus backup_paths.json. Both are read here so
there is one source of truth, not a copy of it that can drift.
"""

import importlib.util
import json
import shutil
import sys
from importlib.machinery import SourceFileLoader
from pathlib import Path

REPO = Path(__file__).resolve().parent


def entries():
    # The backup tool has no .py suffix in here (it is a copy of
    # ~/.local/bin/config-backup), so it needs an explicit source loader.
    # dont_write_bytecode keeps the import from dropping a __pycache__ into
    # the repo on every run.
    sys.dont_write_bytecode = True
    path = REPO / "custom-binaries/bin/config-backup"
    spec = importlib.util.spec_from_loader("cb", SourceFileLoader("cb", str(path)))
    cb = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cb)
    return cb.DEFAULT_BACKUP_PATHS + json.loads((REPO / "backup_paths.json").read_text())


def main(argv):
    dry = "--dry-run" in argv or "-n" in argv
    copied = skipped = 0

    for entry in entries():
        dest = Path(entry["path"])
        src = REPO / entry["category"] / dest.name
        if not src.exists():
            print(f"  skip (not in repo)  {src.relative_to(REPO)}")
            skipped += 1
            continue

        print(f"  {src.relative_to(REPO)}  ->  {dest}")
        copied += 1
        if dry:
            continue

        dest.parent.mkdir(parents=True, exist_ok=True)
        if src.is_dir():
            # Merge, don't mirror: the backup skips files over 2 MB, so a
            # mirror would delete every compiled binary in ~/.local/bin.
            shutil.copytree(src, dest, dirs_exist_ok=True, symlinks=True)
        else:
            shutil.copy2(src, dest)

    verb = "would copy" if dry else "copied"
    print(f"\n{verb} {copied} path(s), skipped {skipped}")
    if dry:
        print("Re-run without --dry-run to apply.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
