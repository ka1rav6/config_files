#!/usr/bin/env bash
# Snapshot the sioyek databases (highlights, bookmarks, portals, marks).
# Keeps the 20 most recent snapshots.
# Usage: backup.sh <sioyek_path> <local_db> <shared_db>
set -uo pipefail
SIOYEK="$1"; LOCAL_DB="$2"; SHARED_DB="$3"
DEST="$HOME/.local/share/sioyek/backups"
STAMP=$(date +%Y%m%d-%H%M%S)

status() { "$SIOYEK" --execute-command set_status_string --execute-command-data "$1" >/dev/null 2>&1 || true; }

mkdir -p "$DEST/$STAMP"
# sqlite backup API -> consistent copy even while sioyek holds the file open
python3 - "$LOCAL_DB" "$SHARED_DB" "$DEST/$STAMP" <<'PY'
import sqlite3, sys, os, shutil
for src in sys.argv[1:3]:
    dst = os.path.join(sys.argv[3], os.path.basename(src))
    try:
        s = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
        d = sqlite3.connect(dst)
        s.backup(d); d.close(); s.close()
    except Exception:
        shutil.copy2(src, dst)
PY

# prune
ls -1dt "$DEST"/*/ 2>/dev/null | tail -n +21 | xargs -r rm -rf

COUNT=$(python3 -c "
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
print(sum(c.execute(f'select count(*) from {t}').fetchone()[0] for t in ('highlights','bookmarks','links','marks')))
" "$DEST/$STAMP/$(basename "$SHARED_DB")" 2>/dev/null || echo "?")

status "  backed up $COUNT annotations -> $STAMP"
