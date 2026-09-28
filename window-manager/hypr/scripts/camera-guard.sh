#!/usr/bin/env bash
# =============================================================================
# camera-guard — enable/disable the internal camera. RUNS AS ROOT.
# =============================================================================
# This file is the PAYLOAD. It is not called from here: install-camera-guard.sh
# copies it to /usr/local/lib/hypr/camera-guard, root-owned and not writable by
# anyone else, and installs a sudoers drop-in allowing exactly these three
# invocations without a password. lid.sh then calls
#
#     sudo -n /usr/local/lib/hypr/camera-guard off|on
#
# WHY ROOT IS UNAVOIDABLE
#   /dev/video* are root:video 0660 and the user IS in `video`, so reading the
#   camera needs no privilege -- which is the whole problem. Making it
#   UNREADABLE does: every mechanism (USB authorization, driver unbind, chmod on
#   the device node, unloading uvcvideo) writes somewhere only root can write.
#   There is no unprivileged way to take a capability away from yourself.
#
# WHY USB DEAUTHORIZATION AND NOT THE ALTERNATIVES
#   `echo 0 > /sys/bus/usb/devices/<dev>/authorized` makes the kernel drop the
#   device: its interfaces unbind, /dev/video* for it disappear, and an
#   application that tries to open it gets ENOENT rather than a black frame.
#   Writing 1 brings it back exactly as it was, with no module reload and no
#   reboot. It is a runtime flag -- nothing is changed persistently, nothing is
#   blown, and a power cycle forgets it ever happened.
#
#   Rejected alternatives, for the record:
#     unbind uvcvideo   Leaves the device authorized and re-binds on any rescan.
#     rmmod uvcvideo    Global, not per-device, and fails outright while any
#                       camera is in use.
#     chmod /dev/video* Undone by udev on the next event, and races with it.
#
# THE DEVICE IS DISCOVERED, NOT HARDCODED
#   This machine's camera happens to be an "HP 5MP Camera" at USB 3-5
#   (04f2:b7fe), but none of that is written down here. The device is found by
#   asking which USB device owns an interface bound to the uvcvideo driver, which
#   is true of any UVC webcam on any machine.
#
# Usage (as root):
#   camera-guard off | on | status
# =============================================================================

set -uo pipefail

LOG_TAG="camera-guard"

log() { logger -t "$LOG_TAG" -- "$*" 2>/dev/null || printf '%s: %s\n' "$LOG_TAG" "$*"; }

# ---------------------------------------------------------------------------
# Find the internal camera's USB device directory.
#
# A UVC webcam presents one or more USB *interfaces* (e.g. 3-5:1.0) whose driver
# symlink points at uvcvideo. `authorized` lives on the DEVICE (3-5), not on the
# interface.
#
# /sys/bus/usb/devices is a FLAT directory of symlinks, so the device is the
# interface's SIBLING, not its parent -- the interface name with everything from
# the ":" onwards removed. `dirname` here yields /sys/bus/usb/devices itself,
# which silently made every field read empty and the whole guard a no-op.
#
# INTERNAL vs EXTERNAL: a laptop's built-in camera hangs off a root hub port
# that is marked non-removable. `removable` reads "fixed" for it and
# "removable" for a plugged-in USB webcam. That is what stops this
# deauthorizing an external camera the user deliberately attached -- with the
# lid shut, an external webcam is the one that might legitimately still be
# wanted.
#
# If the kernel does not say (removable = "unknown"), the device is treated as
# internal: on a laptop with the lid shut that is the safer guess, and the
# operation is reversible either way.
# ---------------------------------------------------------------------------
find_camera() {
    local iface device removable found=""

    for iface in /sys/bus/usb/devices/*:*; do
        [[ -L "$iface/driver" ]] || continue
        [[ "$(basename "$(readlink -f "$iface/driver")")" == "uvcvideo" ]] || continue

        device="$(dirname "$iface")/$(basename "$iface")"
        device="${device%%:*}"
        [[ -e "$device/authorized" ]] || continue

        removable=$(cat "$device/removable" 2>/dev/null || printf 'unknown\n')
        case "$removable" in
        removable)
            # An external webcam. Skip it.
            continue
            ;;
        esac

        found="$device"
        break
    done

    [[ -n "$found" ]] && printf '%s\n' "$found"
}

describe() {
    local device="$1"
    printf '%s (%s:%s, %s)' \
        "$(basename "$device")" \
        "$(cat "$device/idVendor" 2>/dev/null || printf '????')" \
        "$(cat "$device/idProduct" 2>/dev/null || printf '????')" \
        "$(cat "$device/product" 2>/dev/null || printf 'unknown product')"
}

# The lid's actual position, as a safety interlock.
#
# `off` refuses to run while the lid is OPEN. The only caller is lid.sh, which
# should never ask for that -- so if it happens, something has gone wrong
# (a stale event, a hand-run command, a flap mid-transition) and the failure
# mode of guessing wrong is a camera that silently does not work with the laptop
# open. Refusing is the recoverable direction.
lid_is_closed() {
    local file

    # Mirrors lid.sh's own override, so a forced test is coherent across both
    # halves. See the note there for why this is a permanent affordance.
    case "${HYPR_LID_FORCE:-}" in
    closed) return 0 ;;
    open) return 1 ;;
    esac
    for file in /proc/acpi/button/lid/*/state; do
        [[ -r "$file" ]] || continue
        grep -qi closed "$file" && return 0
        return 1
    done
    # No lid switch: nothing to interlock against, so do not stand in the way.
    return 0
}

action="${1:-status}"

device=$(find_camera)

if [[ -z "$device" ]]; then
    # Safe if the hardware is absent: a machine with no UVC camera, or one whose
    # camera is already deauthorized and so no longer has a bound interface.
    case "$action" in
    on)
        # Re-authorize anything that is currently deauthorized and looks like it
        # could be the camera. A deauthorized device has NO bound interfaces, so
        # find_camera cannot see it -- which would otherwise make `on`
        # permanently unable to undo `off`. This is the one path that must not
        # depend on the driver being bound.
        restored=0
        for candidate in /sys/bus/usb/devices/*; do
            [[ -e "$candidate/authorized" ]] || continue
            [[ "$(cat "$candidate/authorized" 2>/dev/null)" == "0" ]] || continue
            [[ "$(cat "$candidate/removable" 2>/dev/null)" == "removable" ]] && continue
            printf '1\n' >"$candidate/authorized" 2>/dev/null || continue
            log "re-authorized $(describe "$candidate")"
            restored=$((restored + 1))
        done
        [[ "$restored" -eq 0 ]] && log "no deauthorized internal USB device to restore"
        exit 0
        ;;
    status)
        printf 'no UVC camera bound\n'
        exit 0
        ;;
    *)
        log "no UVC camera found, nothing to do"
        exit 0
        ;;
    esac
fi

case "$action" in
off)
    if ! lid_is_closed; then
        log "refusing to disable the camera: the lid is open"
        exit 1
    fi
    if [[ "$(cat "$device/authorized" 2>/dev/null)" == "0" ]]; then
        exit 0
    fi
    printf '0\n' >"$device/authorized"
    log "disabled $(describe "$device")"
    ;;
on)
    if [[ "$(cat "$device/authorized" 2>/dev/null)" == "1" ]]; then
        exit 0
    fi
    printf '1\n' >"$device/authorized"
    log "enabled $(describe "$device")"
    ;;
status)
    printf '%s authorized=%s\n' "$(describe "$device")" \
        "$(cat "$device/authorized" 2>/dev/null || printf '?')"
    ;;
*)
    printf 'Usage: %s [off|on|status]\n' "$0" >&2
    exit 2
    ;;
esac
