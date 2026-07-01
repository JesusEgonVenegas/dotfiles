#!/usr/bin/env bash
# AOC follow — make the secondary monitor's Hyprland state track its physical
# power button, with no manual Super+P needed.
#
# Why this exists: the AOC (HDMI-A-1) holds the HDMI hotplug line asserted and
# keeps answering EDID even when powered off, so Hyprland literally cannot see
# it turn on/off (verified three ways). BUT the kernel still emits a DRM
# "change" hotplug pulse on each *physical* power press. DPMS/idle-wake does
# NOT emit these pulses (verified), so screen blanking won't misfire this.
#
# We watch those pulses in the user session (udev's own RUN= can't reach
# hyprctl — no session env), debounce the burst, and run the existing toggle.
# Each physical press => one debounced toggle => Hyprland follows. Super+P
# still works as a manual override if they ever drift out of sync.
set -uo pipefail

TOGGLE="$HOME/.config/hypr/scripts/toggle-secondary.sh"
DEBOUNCE=3   # seconds; collapses the multi-event burst from one power press

# Single-instance guard (exec-once may fire on every config reload).
LOCK="${XDG_RUNTIME_DIR:-/tmp}/aoc-hotplug.lock"
exec 9>"$LOCK" || exit 0
flock -n 9 || exit 0

last=0
stdbuf -oL udevadm monitor --udev --subsystem-match=drm 2>/dev/null | \
while read -r line; do
    case "$line" in
        *change*card1*)
            now=$(date +%s)
            if (( now - last >= DEBOUNCE )); then
                last=$now
                "$TOGGLE" >/dev/null 2>&1 || true
            fi
            ;;
    esac
done
