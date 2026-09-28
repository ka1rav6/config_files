#!/usr/bin/env bash
# =============================================================================
# install-camera-guard.sh — one-time root install for the lid camera feature.
# =============================================================================
# Run it once, by hand:
#
#     sudo ~/.config/hypr/scripts/install-camera-guard.sh
#
# and once more with --uninstall to take it all back out again.
#
# EVERYTHING ELSE IN THIS CONFIG IS UNPRIVILEGED. This is the one exception, and
# it is worth being explicit about why: making a camera UNREADABLE requires
# writing to /sys, and /sys is root's. There is no unprivileged mechanism for
# taking a capability away from yourself -- see the header of camera-guard.sh for
# the alternatives that were considered and why each is worse.
#
# WHAT IT INSTALLS -- exactly two files, both listed here so uninstalling is not
# an act of faith:
#
#   /usr/local/lib/hypr/camera-guard          root:root 0755, a copy of
#                                             ~/.config/hypr/scripts/camera-guard.sh
#   /etc/sudoers.d/60-hypr-camera-guard       0440, three NOPASSWD entries
#
# WHY A SUDOERS DROP-IN AND NOT A SYSTEMD SERVICE
#   A system service would need polkit rules to let a user start it, which is
#   more moving parts and a broader grant than this needs. The drop-in below
#   permits three fixed command lines and nothing else -- no wildcards, no
#   arguments the caller chooses, no shell.
#
# WHY THE SCRIPT IS COPIED RATHER THAN POINTED AT IN $HOME
#   A sudoers NOPASSWD entry pointing at a file the invoking user can WRITE is a
#   root shell with extra steps: edit the script, run it, own the machine. The
#   copy lives somewhere only root can write, which is what makes the grant
#   meaningful. The corollary is that editing camera-guard.sh in ~/.config does
#   NOT take effect until this installer is run again -- which the installer says
#   out loud when it finishes.
# =============================================================================

set -euo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/camera-guard.sh"
TARGET_DIR="/usr/local/lib/hypr"
TARGET="$TARGET_DIR/camera-guard"
SUDOERS="/etc/sudoers.d/60-hypr-camera-guard"

if [[ "${1:-}" == "--uninstall" ]]; then
    [[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
    rm -f "$SUDOERS" "$TARGET"
    rmdir "$TARGET_DIR" 2>/dev/null || true
    echo "Removed $TARGET and $SUDOERS."
    echo "Nothing else was changed. The camera itself was never modified persistently."
    exit 0
fi

[[ "$(id -u)" -eq 0 ]] || {
    echo "This installs a root-owned helper and a sudoers drop-in, so it needs sudo:" >&2
    echo "  sudo $0" >&2
    exit 1
}

[[ -r "$SOURCE" ]] || { echo "Cannot read $SOURCE" >&2; exit 1; }

# Who the NOPASSWD grant is for: the user who invoked sudo, not root.
TARGET_USER="${SUDO_USER:-}"
[[ -n "$TARGET_USER" ]] || { echo "Could not determine the invoking user (SUDO_USER unset)." >&2; exit 1; }

install -d -o root -g root -m 0755 "$TARGET_DIR"
install -o root -g root -m 0755 "$SOURCE" "$TARGET"
echo "Installed $TARGET"

# Write the drop-in to a temp file and VALIDATE IT before putting it in place.
#
# This is the load-bearing line of the whole script. A syntactically invalid
# file in /etc/sudoers.d breaks sudo ENTIRELY -- not just this entry -- and the
# way out of that is a root shell you no longer have. `visudo -c` on the
# candidate file is what makes this safe to run.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

cat >"$tmp" <<EOF
# Installed by ~/.config/hypr/scripts/install-camera-guard.sh
#
# Lets the desktop session disable the internal camera while the laptop lid is
# shut, and enable it again when the lid opens. Called from
# ~/.config/hypr/scripts/lid.sh via: sudo -n $TARGET off|on
#
# Three exact command lines, no wildcards and no caller-supplied arguments. The
# target is root-owned and not writable by $TARGET_USER, which is what stops this
# being an arbitrary-root-command grant.
$TARGET_USER ALL=(root) NOPASSWD: $TARGET off
$TARGET_USER ALL=(root) NOPASSWD: $TARGET on
$TARGET_USER ALL=(root) NOPASSWD: $TARGET status
EOF

if ! visudo -cqf "$tmp"; then
    echo "The generated sudoers file did not validate. NOTHING was installed into /etc/sudoers.d." >&2
    echo "Left the helper at $TARGET; remove it with: sudo $0 --uninstall" >&2
    exit 1
fi

install -o root -g root -m 0440 "$tmp" "$SUDOERS"
echo "Installed $SUDOERS (validated with visudo -c)"

echo
echo "Checking it works:"
"$TARGET" status || true
echo
echo "Done. Turn the feature on in Settings > Windows > Laptop lid, or:"
echo "  jq '.lid.disableCamera = true' ~/.config/quickshell/settings.json"
echo
echo "NOTE: $TARGET is a COPY. If you edit"
echo "      $SOURCE"
echo "      re-run this installer for the change to take effect."
