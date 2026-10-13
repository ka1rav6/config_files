#!/usr/bin/env bash
# =============================================================================
# install-touchscreen.sh — one-time root install for the touchscreen toggle.
# =============================================================================
# Run it once, by hand:
#
#     sudo ~/.config/hypr/scripts/install-touchscreen.sh
#
# and once more with --uninstall to take it all back out again.
#
# This is the second privileged thing in this config, after the lid camera
# guard, and for the same kind of reason: binding and unbinding a driver means
# writing to /sys, and /sys is root's. There is no unprivileged mechanism for
# detaching a driver from a device. See the header of touchscreen.sh for the
# measurements that justify wanting to, and for the gentler options that were
# tried first and do not work.
#
# WHAT IT INSTALLS -- exactly two files, both listed here so uninstalling is not
# an act of faith:
#
#   /usr/local/lib/hypr/touchscreen        root:root 0755, a copy of
#                                          ~/.config/hypr/scripts/touchscreen.sh
#   /etc/sudoers.d/61-hypr-touchscreen     0440, five NOPASSWD entries
#
# The number is 61 because 60 is the camera guard's. They are independent; both
# can be installed, and uninstalling one leaves the other alone.
#
# WHY A SUDOERS DROP-IN AND NOT A SYSTEMD SERVICE
#   Same answer as the camera guard: a system service would need polkit rules to
#   let a user start it, which is more moving parts and a broader grant than
#   this needs. The drop-in below permits five fixed command lines and nothing
#   else -- no wildcards, no arguments the caller chooses, no shell.
#
# WHY THE SCRIPT IS COPIED RATHER THAN POINTED AT IN $HOME
#   A sudoers NOPASSWD entry pointing at a file the invoking user can WRITE is a
#   root shell with extra steps: edit the script, run it, own the machine. The
#   copy lives somewhere only root can write, which is what makes the grant
#   meaningful. The corollary is that editing touchscreen.sh in ~/.config does
#   NOT take effect until this installer is run again -- which the installer says
#   out loud when it finishes.
# =============================================================================

set -euo pipefail

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/touchscreen.sh"
TARGET_DIR="/usr/local/lib/hypr"
TARGET="$TARGET_DIR/touchscreen"
SUDOERS="/etc/sudoers.d/61-hypr-touchscreen"

if [[ "${1:-}" == "--uninstall" ]]; then
    [[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
    # Leave the touchscreen BOUND on the way out. Removing the helper while the
    # device is unbound would strand it off with nothing left on the machine
    # able to turn it back on short of a reboot.
    if [[ -x "$TARGET" ]]; then
        "$TARGET" on >/dev/null 2>&1 || true
        echo "Re-bound the touchscreen so it is not left off with no way back."
    fi
    rm -f "$SUDOERS" "$TARGET"
    # Shared with the camera guard, so only remove it if it is now empty.
    rmdir "$TARGET_DIR" 2>/dev/null || true
    echo "Removed $TARGET and $SUDOERS."
    echo "Also remove the dofile line for touchscreen.lua from hyprland.lua."
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
# Installed by ~/.config/hypr/scripts/install-touchscreen.sh
#
# Lets the desktop session attach and detach the touchscreen digitizer, which
# costs ~41,600 interrupts/sec while attached and holds one CPU core out of deep
# idle. Called from ~/.config/hypr/touchscreen.lua via:
#   sudo -n $TARGET on|off|toggle|status
#
# Five exact command lines, no wildcards and no caller-supplied arguments. The
# target is root-owned and not writable by $TARGET_USER, which is what stops this
# being an arbitrary-root-command grant.
$TARGET_USER ALL=(root) NOPASSWD: $TARGET on
$TARGET_USER ALL=(root) NOPASSWD: $TARGET off
$TARGET_USER ALL=(root) NOPASSWD: $TARGET toggle
$TARGET_USER ALL=(root) NOPASSWD: $TARGET status
$TARGET_USER ALL=(root) NOPASSWD: $TARGET detect
EOF

if ! visudo -cqf "$tmp"; then
    echo "The generated sudoers file did not validate. NOTHING was installed into /etc/sudoers.d." >&2
    echo "Left the helper at $TARGET; remove it with: sudo $0 --uninstall" >&2
    exit 1
fi

install -o root -g root -m 0440 "$tmp" "$SUDOERS"
echo "Installed $SUDOERS (validated with visudo -c)"

echo
echo "Devices it can see:"
"$TARGET" detect || true
echo "Current state:"
"$TARGET" status || true

echo
echo "Next, add this line to ~/.config/hypr/hyprland.lua (before bindings.lua):"
echo '  dofile(os.getenv("HOME") .. "/.config/hypr/touchscreen.lua")'
echo "then: hyprctl reload"
echo
echo "NOTE: $TARGET is a COPY. If you edit"
echo "      $SOURCE"
echo "      re-run this installer for the change to take effect."
