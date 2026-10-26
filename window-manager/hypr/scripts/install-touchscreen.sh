#!/usr/bin/env bash
# =============================================================================
# install-touchscreen.sh — one-time root install for the digitizer daemon.
# =============================================================================
# Run it once, by hand:
#
#     sudo ~/.config/hypr/scripts/install-touchscreen.sh
#
# and once more with --uninstall to take it all back out again.
#
# WHAT CHANGED, AND WHY
#   This used to install a root-owned copy of touchscreen.sh plus a sudoers
#   drop-in with five NOPASSWD entries, and the session drove it through
#   `sudo -n` on every fold. That chain was four processes per fold with no
#   lock anywhere in it, so two quick folds could race each other, and it could
#   not work on the FIRST fold of a session at all -- intel_hid registers the
#   tablet-mode switch lazily, so the device Hyprland needed to bind did not
#   exist when Hyprland parsed its config.
#
#   It now installs one root service, hypr-digitizerd, which reads the switch
#   itself and writes the sysfs bind/unbind itself. The full reasoning is at
#   the top of ~/.config/hypr/daemons/hypr-digitizerd.c; the measurements that
#   justify turning the digitizer off at all are still in scripts/touchscreen.sh,
#   which is kept for its documentation and its `detect` helper.
#
#   The sudoers drop-in is REMOVED by this installer, including when upgrading
#   from the old layout. The session's access is now a unix socket owned by the
#   desktop user that accepts four verbs -- narrower than a NOPASSWD entry on a
#   root-owned binary.
#
# WHAT IT INSTALLS -- exactly two files, both listed here so uninstalling is
# not an act of faith:
#
#   /usr/local/lib/hypr/hypr-digitizerd         root:root 0755
#   /etc/systemd/system/hypr-digitizerd.service root:root 0644
#
# and into the invoking user's ~/.local/bin, the client the keybind calls:
#
#   hypr-digitizer-ctl
# =============================================================================

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$HERE/../daemons" && pwd)"
# The Makefile builds into build/ so the nightly config backup skips the
# binaries -- see the comment on OBJDIR in that Makefile.
BUILD_DIR="$SRC_DIR/build"

TARGET_DIR="/usr/local/lib/hypr"
TARGET="$TARGET_DIR/hypr-digitizerd"
UNIT="/etc/systemd/system/hypr-digitizerd.service"

# The old layout, removed on install as well as on uninstall.
OLD_SUDOERS="/etc/sudoers.d/61-hypr-touchscreen"
OLD_HELPER="$TARGET_DIR/touchscreen"

[[ "$(id -u)" -eq 0 ]] || {
    echo "This installs a root service, so it needs sudo:" >&2
    echo "  sudo $0 ${1:-}" >&2
    exit 1
}

TARGET_USER="${SUDO_USER:-}"
[[ -n "$TARGET_USER" ]] || { echo "Could not determine the invoking user (SUDO_USER unset)." >&2; exit 1; }
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_GID="$(id -g "$TARGET_USER")"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
    systemctl disable --now hypr-digitizerd.service 2>/dev/null || true
    rm -f "$UNIT"
    systemctl daemon-reload 2>/dev/null || true

    # Leave the digitizer BOUND on the way out. Removing the daemon while the
    # device is unbound would strand touch off with nothing left on the machine
    # able to turn it back on short of a reboot. The daemon does this itself on
    # SIGTERM; this is the belt to that braces, for the case where it was
    # already dead.
    if [[ -d /sys/bus/i2c/devices/i2c-ELAN2514:00 ]] &&
       [[ ! -e /sys/bus/i2c/devices/i2c-ELAN2514:00/driver ]]; then
        echo "i2c-ELAN2514:00" > /sys/bus/i2c/drivers/i2c_hid_acpi/bind 2>/dev/null || true
        echo "Re-bound the touchscreen so it is not left off with no way back."
    fi

    rm -f "$TARGET" "$OLD_HELPER" "$OLD_SUDOERS"
    rm -f "$TARGET_HOME/.local/bin/hypr-digitizer-ctl"
    rmdir "$TARGET_DIR" 2>/dev/null || true

    echo "Removed $TARGET, $UNIT and the client."
    echo "Also remove the dofile line for touchscreen.lua from hyprland.lua."
    exit 0
fi

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------

# Build as the invoking user, not as root: the object files and binaries then
# belong to them, and a later `make` in that directory does not hit a
# root-owned artefact it cannot overwrite.
echo "Building..."
sudo -u "$TARGET_USER" make -C "$SRC_DIR" --no-print-directory

[[ -x "$BUILD_DIR/hypr-digitizerd" ]] || { echo "Build produced no hypr-digitizerd." >&2; exit 1; }

install -d -o root -g root -m 0755 "$TARGET_DIR"
install -o root -g root -m 0755 "$BUILD_DIR/hypr-digitizerd" "$TARGET"
echo "Installed $TARGET"

# The client the SUPER + SHIFT + D bind calls. Owned by the user, in the
# ~/.local/bin that autostart.lua already puts on Hyprland's PATH.
install -d -o "$TARGET_UID" -g "$TARGET_GID" -m 0755 "$TARGET_HOME/.local/bin"
install -o "$TARGET_UID" -g "$TARGET_GID" -m 0755 \
    "$BUILD_DIR/hypr-digitizer-ctl" "$TARGET_HOME/.local/bin/hypr-digitizer-ctl"
echo "Installed $TARGET_HOME/.local/bin/hypr-digitizer-ctl"

sed -e "s/@UID@/$TARGET_UID/g" -e "s/@GID@/$TARGET_GID/g" \
    "$SRC_DIR/hypr-digitizerd.service" > "$UNIT"
chown root:root "$UNIT"
chmod 0644 "$UNIT"
echo "Installed $UNIT (socket owner: $TARGET_USER, uid $TARGET_UID)"

# Retire the old layout. Done AFTER the new one is in place, so there is never
# a window with neither installed.
if [[ -e "$OLD_SUDOERS" || -e "$OLD_HELPER" ]]; then
    rm -f "$OLD_SUDOERS" "$OLD_HELPER"
    echo "Removed the old sudoers drop-in and root helper -- the daemon replaces both."
fi

systemctl daemon-reload
systemctl enable --now hypr-digitizerd.service
echo

systemctl --no-pager --lines=0 status hypr-digitizerd.service || true
echo
echo "What it found:"
journalctl -u hypr-digitizerd --no-pager --lines=20 -o cat || true

echo
echo "Check it any time with:"
echo "  systemctl status hypr-digitizerd"
echo "  journalctl -u hypr-digitizerd -f"
echo "  hypr-digitizer-ctl status"
echo
echo "NOTE: $TARGET is a COPY. If you edit the sources in"
echo "      $SRC_DIR"
echo "      re-run this installer for the change to take effect."
