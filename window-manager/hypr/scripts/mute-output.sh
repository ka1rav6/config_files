#!/bin/sh
# Toggle mute on the default output, then copy that state onto EVERY output.
#
# Muting only @DEFAULT_AUDIO_SINK@ is not enough here: with the quickshell
# Equalizer on, the default is the virtual "Equalizer" sink (qs_eq_sink), but
# an app can pin its stream straight to the real device (Chrome does this with
# Bluetooth headphones) and bypass it -- so the default goes mute while the
# headphones keep playing. Mirroring the mute onto every real sink closes that.

wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED; then
    state=1
else
    state=0
fi

pactl list short sinks | cut -f2 | while read -r sink; do
    pactl set-sink-mute "$sink" "$state"
done
