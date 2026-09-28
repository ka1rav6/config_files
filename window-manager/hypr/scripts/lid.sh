#!/usr/bin/env bash
# =============================================================================
# lid.sh — what closing the laptop lid does.
# =============================================================================
# Called by ~/.config/hypr/lid.lua, which binds Hyprland's native switch keys:
#
#     switch:on:Lid Switch   -> lid.sh close
#     switch:off:Lid Switch  -> lid.sh open
#     hyprland.start         -> lid.sh reconcile
#     monitor added/removed  -> lid.sh reconcile
#
# ---------------------------------------------------------------------------
# WHY THIS EXISTS AT ALL, GIVEN logind IS SET TO `ignore`
#
# /etc/systemd/logind.conf.d/10-lid-ignore.conf sets all three
# HandleLidSwitch* keys to `ignore`. That is correct and stays: it is what stops
# logind suspending the machine out from under a build or a download.
#
# But `ignore` means logind does NOTHING, and nothing is not the same as the
# right thing. With the lid physically shut and no other policy in place,
# Hyprland happily keeps eDP-1 enabled and scanning out: windows stay laid out
# on a panel nobody can see, hyprlock draws its prompt into the hinge, and the
# camera keeps working. Everything `ignore` leaves undone is what lives here.
#
# ---------------------------------------------------------------------------
# EVERY ACTION IS DERIVED FROM STATE, NOT FROM THE EVENT
#
# `close`, `open` and `reconcile` all run the same function. The script reads
# the lid's actual position out of sysfs and the actual monitor list out of
# Hyprland, then makes the world match. It never assumes the event it was told
# about is still true.
#
# That is what makes the five required scenarios one code path rather than five:
#
#   lid open,   no external      -> internal on
#   lid open,   external(s)      -> internal on, externals on
#   lid closed, external(s)      -> internal OFF, session continues out there
#   lid closed, several externals-> same; nothing here counts them
#   lid closed, no external      -> internal blanked, session locked, NOT
#                                   disabled (see the safety rule below)
#
# It is also what makes it correct under a flapping lid, a lid closed while
# Hyprland was starting (no switch event is ever emitted for a state that was
# already true), and -- the one that would otherwise lose a session -- an
# external monitor unplugged while the lid is already shut. That last case is why
# lid.lua also calls `reconcile` on monitor.added/removed.
#
# ---------------------------------------------------------------------------
# THE SAFETY RULE: NEVER DISABLE THE LAST OUTPUT
#
# `hl.monitor({ disabled = true })` releases the output. With an external
# monitor attached that is exactly right and is what moves the whole session
# out there. With no external attached it would leave Hyprland with ZERO
# outputs, and there is then no screen to get back to -- so with no external the
# internal panel is only DPMS-blanked, never disabled.
#
# INTERNAL_OFF_MODE below picks between DPMS and backlight for that case.
# Read its comment before changing it: there is a live aquamarine bug here.
#
# ---------------------------------------------------------------------------
# Usage:
#   lid.sh close | open | reconcile | status
# =============================================================================

set -uo pipefail

SETTINGS="$HOME/.config/quickshell/settings.json"
SCRIPTS="$HOME/.config/hypr/scripts"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"

STATE_DIR="$RUNTIME/hypr-lid"
LOCK="$RUNTIME/hypr-lid.lock"
LOG="$RUNTIME/hypr-lid.log"

CAMERA_GUARD="/usr/local/lib/hypr/camera-guard"

# How the internal panel is switched off when it is the ONLY output.
#
#   dpms       Real DPMS off: the connector is disabled and the CRTC released,
#              so the panel stops scanning out entirely. This is the correct
#              answer and the one that actually satisfies "stop rendering".
#
#   backlight  brightnessctl to 0, restored on open. The panel keeps scanning
#              out (a static locked screen, so Hyprland repaints on damage only
#              -- the cost is close to nothing) but there is no modeset at all.
#
# WHY THIS IS A KNOB AND NOT JUST `dpms`
#   aquamarine 0.15.0 can hang re-enabling an output it previously disabled --
#   the whole reason ~/.config/hypr/defaults.lua pins AQ_NO_ATOMIC=1, and the
#   reason the DPMS-off listener was removed from hypridle.conf. A DPMS off/on
#   cycle on eDP-1 was tested on the legacy interface after AQ_NO_ATOMIC took
#   effect: hyprctl stayed responsive and reported dpmsStatus back to true, and
#   the panel recovered. If a future aquamarine regresses that, `backlight` is
#   the escape hatch that needs no DRM transition, and it is one word here.
#
#   Note that the EXTERNAL-monitor case has no such escape hatch: consolidating
#   the session onto the external genuinely requires disabling the internal
#   output, and there is no way to do that without the same DRM transition.
INTERNAL_OFF_MODE="dpms"

mkdir -p "$STATE_DIR"

ts() { date +'%H:%M:%S.%3N'; }
log() { printf '%s lid: %s\n' "$(ts)" "$*" >>"$LOG"; }

# ---------------------------------------------------------------------------
# Settings
#
# Read straight out of settings.json, which is the single source of truth the
# Settings GUI writes. No push, no cache, no reload: the policy is re-read on
# every lid event, so a toggle flipped in Settings > Windows takes effect on the
# very next close.
#
# Every read carries a default, so a missing file, a missing key or a settings.json
# that is mid-write cannot make the lid do something surprising -- it falls back
# to the behaviour documented in config/Settings.qml.
# ---------------------------------------------------------------------------
# NO `// fallback` IN THE jq EXPRESSION. THIS IS THE WHOLE POINT OF THE FUNCTION.
#
# jq's `//` is an alternative operator, not a null-coalesce: it takes the
# right-hand side whenever the left is null OR FALSE. So
#
#     jq -r '.lid.lockOnClose // empty'
#
# returns empty for `false` exactly as it does for a missing key -- and this
# function would then substitute the default, which for every key here is `true`.
# The result was that EVERY BOOLEAN IN THIS SECTION WAS UNTURNABLE-OFF: setting
# lockOnClose to false in Settings still locked the session, silently, and the
# log said it was doing it.
#
# Caught by a forced lid test with lockOnClose deliberately false, which locked
# the session anyway. Ask for the raw value and test for absence in the shell,
# where `false` is just a string.
setting() {
    local path="$1" fallback="$2" value
    value=$(jq -r "$path" "$SETTINGS" 2>/dev/null) || value="null"
    [[ -z "$value" || "$value" == "null" ]] && value="$fallback"
    printf '%s\n' "$value"
}

# ---------------------------------------------------------------------------
# Hardware and compositor state
# ---------------------------------------------------------------------------

# "closed" | "open". sysfs is authoritative: it is the lid's ACTUAL position,
# not the event we happen to have been handed.
#
# HYPR_LID_FORCE overrides it, for testing. This is not scaffolding that should
# have been deleted -- it is the only way to exercise this script while watching
# what it does, because the states it is about are precisely the ones where you
# cannot see the screen or read a log. Closing the lid to test the lid is not a
# debugging strategy.
#
#     HYPR_LID_FORCE=closed ~/.config/hypr/scripts/lid.sh close
#     HYPR_LID_FORCE=open   ~/.config/hypr/scripts/lid.sh open
#
# It affects only this reading. Every action below still derives from it plus the
# real monitor list, so a forced run does exactly what a real one would.
lid_state() {
    local file

    case "${HYPR_LID_FORCE:-}" in
    closed | open)
        printf '%s\n' "$HYPR_LID_FORCE"
        return 0
        ;;
    esac
    for file in /proc/acpi/button/lid/*/state; do
        [[ -r "$file" ]] || continue
        if grep -qi closed "$file"; then
            printf 'closed\n'
        else
            printf 'open\n'
        fi
        return 0
    done
    # No lid switch on this machine. Reporting "open" means every branch below
    # reduces to "leave everything on", which is the right behaviour for a
    # desktop.
    printf 'open\n'
}

# The internal panel's output name, discovered rather than hardcoded.
#
# eDP is the modern laptop connector, LVDS the older one, DSI the ARM/tablet
# one. `hyprctl monitors all` rather than `monitors`, because a DISABLED output
# does not appear in the latter -- and finding the internal panel while it is
# disabled is the entire job on the way back up.
internal_output() {
    hyprctl monitors all -j 2>/dev/null |
        jq -r 'first(.[] | select(.name | test("^(eDP|LVDS|DSI)"; "i")) | .name) // empty'
}

# Names of every ENABLED output that is not the internal panel. `monitors`, not
# `monitors all`: an output that is present but disabled is not something the
# session can be handed over to.
#
# A mirroring monitor is absent from this list, which is correct -- see the note
# in sync-workspaces.sh. It has no independent workspace to consolidate onto.
external_outputs() {
    local internal="$1"
    hyprctl monitors -j 2>/dev/null |
        jq -r --arg int "$internal" '.[] | select(.name != $int) | .name'
}

# Same trap as setting() above, and it bit here too: `dpmsStatus` is a BOOLEAN,
# so `... // empty` turned a monitor that was genuinely DPMS-off into an empty
# string. internal_on_solo compared that against "false", the comparison failed,
# and opening the lid left the panel blanked -- the exact failure a forced lid
# cycle showed as `OPENED dpmsStatus:false`.
#
# `first()` over an empty stream already outputs nothing, so the alternative was
# never needed for the missing-monitor case either.
monitor_field() {
    local name="$1" field="$2"
    hyprctl monitors all -j 2>/dev/null |
        jq -r --arg n "$name" --arg f "$field" \
            'first(.[] | select(.name == $n) | .[$f])'
}

is_disabled() {
    [[ "$(monitor_field "$1" disabled)" == "true" ]]
}

# hyprctl eval exits 0 even on a Lua error -- it prints the error and reports
# success, which is how sync-workspaces.sh spent months applying nothing at all.
# Match the output instead of trusting the exit status.
ev() {
    local out
    out=$(hyprctl eval "$1" 2>&1)
    if [[ "$out" != "ok" ]]; then
        log "FAILED: $1 -> $out"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Remembering how to put the panel back
#
# The internal output's mode and scale are captured from the LIVE compositor
# before it is disabled, so restoring it needs no duplicate of the values in
# monitors.lua -- which is the copy that would silently rot. Position is
# deliberately NOT captured: it is a function of the monitor layout, which is
# exactly what changes while the panel is off, so it is restored as "auto" and
# then re-asserted by the settle step below.
# ---------------------------------------------------------------------------
remember_internal() {
    local name="$1" width height refresh scale
    width=$(monitor_field "$name" width)
    height=$(monitor_field "$name" height)
    refresh=$(monitor_field "$name" refreshRate)
    scale=$(monitor_field "$name" scale)

    [[ -z "$width" || -z "$height" ]] && return 0

    printf '%sx%s@%.2f\n' "$width" "$height" "${refresh:-60}" >"$STATE_DIR/internal-mode"
    printf '%s\n' "${scale:-1}" >"$STATE_DIR/internal-scale"
    log "remembered $name: $(cat "$STATE_DIR/internal-mode") scale $(cat "$STATE_DIR/internal-scale")"
}

recall_mode() {
    [[ -r "$STATE_DIR/internal-mode" ]] && cat "$STATE_DIR/internal-mode" || printf 'preferred\n'
}

recall_scale() {
    [[ -r "$STATE_DIR/internal-scale" ]] && cat "$STATE_DIR/internal-scale" || printf '1\n'
}

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

disable_internal_output() {
    local name="$1"
    is_disabled "$name" && return 0

    remember_internal "$name"
    log "disabling $name (external monitor present)"
    ev "hl.monitor({ output = \"$name\", disabled = true })" || return 1

    # Disabling an output emits monitor.removed, and the handlers in
    # monitors.lua already react to that -- sync-workspaces.sh moves the
    # workspaces off it and relayer.sh re-homes the layer surfaces. settle()
    # below re-asserts the first of those anyway, because both are idempotent
    # and a bar on the wrong output is worse than one redundant run.
    settle
}

enable_internal_output() {
    local name="$1"
    is_disabled "$name" || return 0

    log "enabling $name (mode $(recall_mode) scale $(recall_scale))"
    ev "hl.monitor({ output = \"$name\", disabled = false, mirror = \"none\", mode = \"$(recall_mode)\", position = \"auto\", scale = $(recall_scale) })" || return 1

    settle
}

# DPMS is per-output and the monitor MUST be named.
#
# `hl.dsp.dpms({ action = "on" })` with no monitor was tried and is not a
# no-arg convenience for "all outputs": it behaved as a toggle and switched a
# live panel off. Always pass the output.
dpms_internal() {
    local name="$1" action="$2"
    ev "hl.dispatch(hl.dsp.dpms({ action = \"$action\", monitor = \"$name\" }))"
}

# ---------------------------------------------------------------------------
# Backlight, used only when INTERNAL_OFF_MODE is `backlight`.
#
# THE MARKER IS NOT OPTIONAL. `brightnessctl -s` and `-r` share ONE saved value
# per device, and hypridle's 240 s dim listener already uses that same pair
# (`brightnessctl -s set 10%` / `brightnessctl -r`, see hypridle.conf). So an
# unconditional `-r` here does not mean "undo what I did" -- it means "restore
# whatever anything last saved", which on an open lid can be hypridle's 10% dim.
# Reconcile runs on monitor hotplug and at startup as well as on lid events, so
# that would have quietly darkened the panel at unrelated moments.
#
# The marker makes the restore conditional on this script having been the one to
# turn the backlight down.
# ---------------------------------------------------------------------------
backlight_off() {
    command -v brightnessctl >/dev/null 2>&1 || return 0
    [[ -e "$STATE_DIR/backlight" ]] && return 0
    : >"$STATE_DIR/backlight"
    brightnessctl -s set 0 >/dev/null 2>&1 || true
}

backlight_on() {
    command -v brightnessctl >/dev/null 2>&1 || return 0
    [[ -e "$STATE_DIR/backlight" ]] || return 0
    rm -f "$STATE_DIR/backlight"
    brightnessctl -r >/dev/null 2>&1 || true
}

internal_off_solo() {
    local name="$1"
    case "$INTERNAL_OFF_MODE" in
    backlight)
        log "blanking $name via backlight (sole output)"
        backlight_off
        ;;
    *)
        log "blanking $name via DPMS (sole output)"
        dpms_internal "$name" off
        ;;
    esac
}

internal_on_solo() {
    local name="$1"
    backlight_on

    # Only if it is actually off. `hyprctl monitors` reports dpmsStatus, so this
    # is a read rather than a guess -- and it keeps reconcile (which also runs on
    # every monitor hotplug) from issuing a pointless modeset each time.
    if [[ "$(monitor_field "$name" dpmsStatus)" == "false" ]]; then
        log "waking $name from DPMS"
        dpms_internal "$name" on
    fi
}

# Re-establish everything that depends on the monitor layout.
#
# The same two repair scripts display-layout.sh runs, behind the same lock, so a
# lid event and a SUPER+SHIFT+X cannot stack overlapping repairs. flock -n means
# a second run simply skips -- the one already in flight re-reads the monitor
# list after sleeping, so it observes the final layout anyway.
settle() {
    (
        exec 8>"$RUNTIME/hypr-display-settle.lock"
        flock -n 8 || exit 0

        # Enabling or disabling an output is not atomic. Let Hyprland finish
        # before asking it anything.
        sleep 1.2

        "$SCRIPTS/sync-workspaces.sh" >/dev/null 2>&1
        "$SCRIPTS/waybar-ensure.sh" >/dev/null 2>&1
    ) 9>&- &
}

lock_session() {
    # Once per close. Without the marker, a lid that flaps -- or a `reconcile`
    # fired by a monitor event while the lid is still shut -- would call the
    # locker again. lock-session holds its own flock so a second call is safe
    # rather than catastrophic, but "safe" is not a reason to do it.
    [[ -e "$STATE_DIR/locked" ]] && return 0
    : >"$STATE_DIR/locked"

    log "locking session"
    setsid --fork "$HOME/.local/bin/lock-session" >/dev/null 2>&1 </dev/null 9>&- || true
}

camera() {
    local action="$1"
    [[ "$(setting '.lid.disableCamera' true)" == "true" ]] || return 0

    if [[ ! -x "$CAMERA_GUARD" ]]; then
        # Not an error. The helper needs root to install and the feature is
        # explicitly optional; saying so once per event in the log is enough.
        log "camera guard not installed, skipping ($CAMERA_GUARD)"
        return 0
    fi

    # NO ENVIRONMENT IS PASSED THROUGH sudo HERE, DELIBERATELY.
    #
    # The sudoers grant installed by install-camera-guard.sh matches three EXACT
    # command lines. Adding `HYPR_LID_FORCE=...` in front would stop matching it,
    # and the only ways to make it match again are a wildcard or SETENV: -- both
    # of which trade the whole security property of the grant for the
    # convenience of a test.
    #
    # The consequence is that HYPR_LID_FORCE exercises the DISPLAY half only: the
    # guard reads the real lid from sysfs and correctly refuses to disable the
    # camera while the lid is open. That refusal is the interlock doing its job,
    # not a gap. To test the camera half, close the lid for real, or run the
    # helper directly:  sudo HYPR_LID_FORCE=closed /usr/local/lib/hypr/camera-guard off
    if sudo -n "$CAMERA_GUARD" "$action" >>"$LOG" 2>&1; then
        log "camera $action"
    else
        log "camera $action FAILED -- is the sudoers drop-in installed?"
    fi
}

# ---------------------------------------------------------------------------
# The policy
# ---------------------------------------------------------------------------
reconcile() {
    local lid internal externals external_count

    lid=$(lid_state)

    if [[ "$(setting '.lid.enabled' true)" != "true" ]]; then
        log "disabled in settings (lid is $lid) -- nothing to do"
        return 0
    fi

    internal=$(internal_output)
    if [[ -z "$internal" ]]; then
        log "no internal panel found -- nothing to do"
        return 0
    fi

    externals=$(external_outputs "$internal")
    external_count=$(printf '%s' "$externals" | grep -c . || true)

    log "lid=$lid internal=$internal externals=${external_count} [$(printf '%s' "$externals" | tr '\n' ' ')]"

    if [[ "$lid" == "open" ]]; then
        # Undo everything, in the order that gets a picture back soonest.
        rm -f "$STATE_DIR/locked"
        enable_internal_output "$internal"
        internal_on_solo "$internal"
        camera on
        return 0
    fi

    # --- lid closed --------------------------------------------------------
    camera off

    if ((external_count > 0)) && [[ "$(setting '.lid.keepSessionOnExternal' true)" == "true" ]]; then
        # THE IMPORTANT CASE. Hand the session to the external monitor and keep
        # everything running: windows, workspaces, and hyprlock if the session
        # is locked, all of which follow the enabled outputs.
        #
        # Deliberately NOT locking here. The laptop is shut but the desktop is
        # in front of you on the external, and locking it would be a strange
        # thing to do to a session you are looking at.
        if [[ "$(setting '.lid.disableInternal' true)" == "true" ]]; then
            disable_internal_output "$internal"
        else
            log "disableInternal is off -- leaving $internal enabled"
        fi
        return 0
    fi

    # --- lid closed, no external ------------------------------------------
    #
    # Behave like a closed laptop. The session keeps running -- that is the
    # whole point of logind's `ignore`, and a build or a download must not die
    # because the lid moved -- but nothing renders to a panel inside the hinge.
    #
    # The internal output is NOT disabled here. See the safety rule in the
    # header: it is the only output, and disabling it leaves no screen to come
    # back to.
    # Make sure there IS a panel before blanking it. A no-op in the common case,
    # and the thing that saves the session in the uncommon one: if the external
    # monitor was unplugged while the lid was already shut, the internal output
    # is disabled right now and the session has nowhere at all to draw. This is
    # the branch monitor.removed -> `reconcile` exists to reach.
    enable_internal_output "$internal"

    if [[ "$(setting '.lid.lockOnClose' true)" == "true" ]]; then
        lock_session
    fi

    if [[ "$(setting '.lid.disableInternal' true)" == "true" ]]; then
        internal_off_solo "$internal"
    fi
}

# ---------------------------------------------------------------------------
# Entry point
#
# All three verbs run the same function: the script derives what to do from the
# world rather than from the verb, so `close` arriving while the lid is already
# open (a flap, a delayed exec) does the right thing rather than the named
# thing. The verb is kept only because it makes the log readable.
#
# Serialised on one lock. A lid can flap faster than a modeset completes, and
# two overlapping runs would race to enable and disable the same output.
# Blocking rather than -n: the second run must observe the final state, and
# skipping it is how the session would be left mid-transition.
# ---------------------------------------------------------------------------
case "${1:-reconcile}" in
close | open | reconcile)
    exec 9>"$LOCK"
    flock 9
    log "--- ${1:-reconcile} ---"
    reconcile
    ;;
status)
    internal=$(internal_output)
    printf 'lid:       %s\n' "$(lid_state)"
    printf 'internal:  %s%s\n' "${internal:-none}" \
        "$([[ -n "$internal" ]] && is_disabled "$internal" && printf ' (disabled)')"
    printf 'externals: %s\n' "$(external_outputs "${internal:-}" | tr '\n' ' ')"
    printf 'off mode:  %s\n' "$INTERNAL_OFF_MODE"
    printf 'camera:    %s\n' \
        "$([[ -x "$CAMERA_GUARD" ]] && printf 'guard installed' || printf 'guard NOT installed')"
    printf 'settings:  enabled=%s keepOnExternal=%s disableInternal=%s lock=%s camera=%s\n' \
        "$(setting '.lid.enabled' true)" \
        "$(setting '.lid.keepSessionOnExternal' true)" \
        "$(setting '.lid.disableInternal' true)" \
        "$(setting '.lid.lockOnClose' true)" \
        "$(setting '.lid.disableCamera' true)"
    printf 'log:       %s\n' "$LOG"
    ;;
*)
    printf 'Usage: %s [close|open|reconcile|status]\n' "$0" >&2
    exit 2
    ;;
esac
