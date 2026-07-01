#!/usr/bin/env bash
# Toggle the secondary monitor on/off *in Hyprland*.
#
# Run this when you physically power the AOC (HDMI-A-1) off or on. Powering the
# monitor off with its button keeps the HDMI hotplug signal asserted, so the GPU
# still reports it as "connected" and Hyprland keeps its layout region + its
# workspaces alive. That's why the cursor escapes left into the dead monitor and
# the bar keeps drawing the 6th workspace cell.
#
# Disabling it here releases the region (cursor can't leave the live monitor) and
# relocates its workspaces, so both symptoms go away. Re-running re-enables it.

set -euo pipefail

MON="HDMI-A-1"
MODE="1920x1080@144,0x0,1"   # mode,position,scale — must match hyprland.conf
WS_MIN=6                     # first workspace owned by the secondary monitor

disabled=$(hyprctl monitors all -j | jq -r --arg m "$MON" \
    '.[] | select(.name==$m) | .disabled')

if [ "$disabled" = "false" ]; then
    hyprctl keyword monitor "$MON, disable"

    # Disabling relocates the secondary's workspaces (6-10) onto the primary but
    # keeps them as hidden workspaces, so their windows (e.g. Discord) would be
    # stranded out of reach. Pull them onto the workspace you're currently on.
    focused=$(hyprctl activeworkspace -j | jq -r '.id')
    for addr in $(hyprctl clients -j | jq -r --argjson min "$WS_MIN" \
            '.[] | select(.workspace.id >= $min) | .address'); do
        hyprctl dispatch movetoworkspacesilent "$focused,address:$addr"
    done

    notify-send -a monitor -i video-display \
        "Secondary monitor off" "$MON disabled; its windows moved here"
else
    # Covers "true" (disabled) and "" (already dropped) — bring it back.
    hyprctl keyword monitor "$MON,$MODE"
    notify-send -a monitor -i video-display \
        "Secondary monitor on" "$MON enabled in Hyprland"
fi
