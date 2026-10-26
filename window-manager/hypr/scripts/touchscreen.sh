#!/usr/bin/env bash
# =============================================================================
# touchscreen.sh — what the digitizer costs, and how to see it.
# =============================================================================
# THIS IS NOW A DIAGNOSTICS AND DOCUMENTATION FILE. It used to be installed to
# /usr/local/lib/hypr/touchscreen and called via `sudo -n` to do the privileged
# bind/unbind; hypr-digitizerd does that itself now, so the actions here
# delegate to it and only the unprivileged ones (`status`, `detect`, and the
# live interrupt rate) still do any work.
#
# It is kept, rather than deleted with the rest of the old chain, because the
# measurements below are the entire justification for the feature and are not
# written down anywhere else.
#
#     ~/.config/hypr/scripts/touchscreen.sh status   state + live IRQ rate
#     ~/.config/hypr/scripts/touchscreen.sh detect    every HID-over-i2c device
#
# The mechanism now lives in ~/.config/hypr/daemons/hypr-digitizerd.c.
#
# ---------------------------------------------------------------------------
# WHY A LAPTOP WOULD EVER WANT ITS TOUCHSCREEN TURNED OFF
#
# Measured on this machine (HP OmniBook X Flip 14-fm0xxx, kernel 7.0.0-38):
#
#   i2c_designware.2 (IRQ 20)   41,601 interrupts/sec, SUSTAINED, with nothing
#                               touching the screen. 2.06 billion of them in
#                               13.8 h of uptime -- the lifetime average
#                               (41,678/s) matches the live rate, so this is
#                               constant from boot, not triggered by use.
#
# For scale, the Synaptics touchpad on the adjacent bus (i2c_designware.3) had
# logged 12 M against the touchscreen bus's 2.06 B. This is specific to the
# ELAN digitizer, not to i2c or to HID generally.
#
# WHERE THE COST LANDS -- the CPU percentage is the smaller half:
#
#   IRQ 20 is serviced by cpu2. Measured there: it enters C1, the SHALLOWEST
#   idle state, 31,975 times per second, and reaches the deep states
#   essentially never -- C2 3/sec, C3 2/sec. cpu0 over the same window was
#   healthy: C1 792/s, C2 813/s, C3 231/s.
#
#   So one of eight cores was permanently held out of deep idle. Unbinding took
#   IRQ 20 from 41,601/sec to 0/sec and cpu2's C3 entries from 2/sec to 226/sec
#   -- i.e. straight back to cpu0's profile. That is the whole justification for
#   this script, and it is a measurement, not a theory.
#
# ---------------------------------------------------------------------------
# WHAT IS ACTUALLY WRONG (as far as it can be established from outside)
#
# The two interrupt counters tell different halves of the story:
#
#   ELAN2514:00        30,700,974 over 49,512 s  =    620 /sec
#   i2c_designware.2    2.06 billion             = 41,601 /sec
#
# 2.06e9 / 30.7e6 = 67 controller interrupts per HID report. That is the
# designware controller raising a FIFO interrupt several dozen times while
# clocking out one report -- unremarkable in itself.
#
# The real number is the other one: 620 HID reports per second with nobody
# touching the panel. The digitizer is STREAMING input reports, not emitting
# spurious interrupts. So this is not the i2c_hid BOGUS_IRQ quirk, and no
# quirk-based fix applies (i2c_hid exposes no module parameters anyway --
# `modinfo i2c_hid` lists none, so nothing here is tunable at runtime).
#
# The likely mechanism: i2c-hid only sends the device SET_POWER(SLEEP) when the
# HID device runtime-suspends, and runtime suspend requires that NOTHING holds
# an input or hidraw node open. libinput -- so, Hyprland -- opens every input
# device it finds and keeps it open for the life of the session. The digitizer
# therefore never sleeps and never stops scanning. That is consistent with every
# observation: perfectly uniform rate, present from boot, stops the instant the
# driver is unbound.
#
# IF THAT IS RIGHT, THERE IS NO SOFTWARE SETTING THAT FIXES IT. Touch input
# requires the node open; the node being open is what keeps the device awake.
# Hence a toggle rather than a tunable.
#
# WORTH CHECKING ONCE, while bound (needs root or membership of `input`):
#
#     sudo evtest /dev/input/eventN     # the ELAN2514 touchscreen node
#
# If events stream past with nothing touching the screen, there is a phantom
# contact -- a stuck or mis-calibrated digitizer -- which is a different and
# more fixable problem (and would also mean stray input is reaching windows).
# If it is silent while the interrupt counter climbs, it is the sleep issue
# above and this toggle is the answer.
#
# ---------------------------------------------------------------------------
# WHY BIND/UNBIND AND NOT ONE OF THE GENTLER OPTIONS
#
#   power/control = auto      Already the case, and it changes nothing: see the
#                             runtime-suspend reasoning above. The device cannot
#                             suspend while libinput holds it open.
#   LIBINPUT_IGNORE_DEVICE    Stops libinput USING the device, which is not the
#                             same as stopping the kernel servicing it. The
#                             interrupts continue. Worse than useless here: it
#                             costs the same and loses touch as well.
#   blacklisting i2c_hid_acpi Takes the TOUCHPAD out too -- same driver.
#   udev rule on the device   Can only unbind at boot, so there is no way back
#                             without a reboot.
#
# Unbinding the single i2c device leaves the touchpad (also i2c_hid_acpi, on a
# different bus) completely untouched, and is reversible in both directions with
# no reboot. That is why it is what this does.
# =============================================================================

set -euo pipefail

# The i2c device name, which is BOTH the directory under /sys/bus/i2c/devices
# and the string written to the driver's bind/unbind files.
#
# Hardcoded deliberately. This config already encodes machine specifics where it
# has to (eDP-1 in monitors.lua, AQ_NO_ATOMIC in autostart.lua) and a wrong
# guess here is worse than no guess -- unbinding the touchpad would take the
# pointer out mid-session. Re-derive it on other hardware with:
#
#     /usr/local/lib/hypr/touchscreen detect
#
# which lists every HID-over-i2c device (ACPI PNP0C50) with its bound state, so
# the right name can be read off rather than guessed at.
DEVICE="${HYPR_TOUCHSCREEN_DEVICE:-ELAN2514:00}"

DRIVER_DIR="/sys/bus/i2c/drivers/i2c_hid_acpi"
DEVICE_DIR="/sys/bus/i2c/devices/i2c-${DEVICE}"

# --- Helpers -----------------------------------------------------------------

# Present means "the i2c device exists at all", which is true whether or not a
# driver is bound to it -- unbinding removes the `driver` symlink and the input
# nodes, but leaves the device itself on the bus. That distinction is the whole
# basis of the state check below.
is_present() { [[ -d "$DEVICE_DIR" ]]; }

# Bound means "a driver is attached", i.e. the touchscreen works and is costing
# interrupts. Tested by the symlink rather than by looking for input nodes,
# because the symlink appears and disappears atomically with the bind.
is_bound() { [[ -e "$DEVICE_DIR/driver" ]]; }

# The controller IRQ this device's bus sits on, so `status` can report the live
# rate rather than asserting anything. Derived, not hardcoded: the bus number
# comes from the device's own sysfs path, and the IRQ from /proc/interrupts.
irq_number() {
    local bus controller
    # .../i2c_designware.2/i2c-2/i2c-ELAN2514:00 -> i2c_designware.2
    bus=$(readlink -f "$DEVICE_DIR" 2>/dev/null) || return 1
    controller=$(printf '%s\n' "$bus" | grep -oE 'i2c_designware\.[0-9]+' | head -1) || return 1
    [[ -n "$controller" ]] || return 1
    awk -v c="$controller" '$NF==c { gsub(":","",$1); print $1; exit }' /proc/interrupts
}

# Interrupts/sec on that IRQ, sampled over $1 seconds. Summed across all CPUs,
# because the affinity is 0-7 even though one CPU ends up doing the work.
irq_rate() {
    local secs="${1:-2}" irq a b
    irq=$(irq_number) || { echo "?"; return 0; }
    [[ -n "$irq" ]] || { echo "?"; return 0; }
    read_irq() {
        awk -v n="${irq}:" '$1==n { s=0; for (i=2; i<=NF-2; i++) s+=$i; print s; exit }' \
            /proc/interrupts
    }
    a=$(read_irq); sleep "$secs"; b=$(read_irq)
    [[ -n "$a" && -n "$b" ]] || { echo "?"; return 0; }
    echo $(( (b - a) / secs ))
}

# --- Actions -----------------------------------------------------------------

# on / off / toggle are the daemon's job now.
#
# Writing to `bind` makes the driver probe the device, which recreates the HID
# device and its input nodes; libinput picks them up through udev on its own,
# so Hyprland needs no reload. That write is root's, and hypr-digitizerd is
# the root service that owns it -- doing it from here would mean a second
# writer racing the daemon's own state, which is exactly the race the daemon
# was written to remove.
delegate() {
    if ! command -v hypr-digitizer-ctl >/dev/null 2>&1; then
        echo "touchscreen: hypr-digitizer-ctl is not installed." >&2
        echo "  sudo ~/.config/hypr/scripts/install-touchscreen.sh" >&2
        exit 1
    fi
    exec hypr-digitizer-ctl "$1"
}

do_status() {
    if ! is_present; then
        echo "absent"
        return 0
    fi
    if is_bound; then
        echo "on (IRQ $(irq_number 2>/dev/null || echo '?'): $(irq_rate 2)/sec)"
    else
        echo "off (IRQ $(irq_number 2>/dev/null || echo '?'): $(irq_rate 2)/sec)"
    fi
}

# Lists every HID-over-i2c device on the machine. PNP0C50 is the ACPI ID for
# "HID over I2C", so this finds touchscreens and touchpads alike without
# matching on vendor names -- the same reasoning as lid.lua reading capability
# bitmaps instead of device names.
do_detect() {
    local dev name modalias state
    printf '%-22s %-10s %s\n' DEVICE STATE MODALIAS
    for dev in /sys/bus/i2c/devices/i2c-*; do
        [[ -r "$dev/modalias" ]] || continue
        modalias=$(cat "$dev/modalias" 2>/dev/null) || continue
        [[ "$modalias" == *PNP0C50* ]] || continue
        name=$(basename "$dev"); name="${name#i2c-}"
        if [[ -e "$dev/driver" ]]; then state="bound"; else state="unbound"; fi
        printf '%-22s %-10s %s\n' "$name" "$state" "$modalias"
    done
    echo
    echo "The touchscreen is the one that is NOT the touchpad. While it is bound,"
    echo "confirm with:  grep -A6 '<name>' /proc/bus/input/devices"
    echo "A touchscreen's input node has INPUT_PROP_DIRECT (bit 1 of properties)"
    echo "set; a touchpad has INPUT_PROP_POINTER (bit 0) instead."
}

case "${1:-}" in
    on|off|toggle) delegate "$1" ;;
    status) do_status ;;
    detect) do_detect ;;
    *)
        echo "usage: ${0##*/} on|off|toggle|status|detect" >&2
        exit 2
        ;;
esac
