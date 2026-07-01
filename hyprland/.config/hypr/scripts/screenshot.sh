#!/bin/bash
# Unified screenshot tool. Every capture both SAVES to disk and COPIES to the
# clipboard. Region capture opens the satty annotation editor by default.
#
# Usage: screenshot.sh <mode>
#   region        region select → satty editor → save + copy
#   region-quick  region select → save + copy (no editor)
#   window        active window  → save + copy
#   output        active monitor → save + copy
#   output-delay  3s countdown → active monitor → save + copy
#   ocr           region select → extract text → clipboard
#   color         pick a pixel  → hex code → clipboard

MODE="$1"
OUTDIR="$HOME/pictures/screenshots"
mkdir -p "$OUTDIR"
FILE="$OUTDIR/screenshot_$(date +%Y%m%d_%H%M%S).png"

# Notification with quick actions: Open the file, or re-open it in satty to edit.
notify_saved() {
    local f="$1"
    local action
    action=$(notify-send "Screenshot saved & copied" "$(basename "$f")" \
        --hint="string:image-path:file://$f" \
        -A "open=Open" -A "edit=Edit" --expire-time=6000 2>/dev/null)
    case "$action" in
        open) xdg-open "$f" & ;;
        edit) satty --filename "$f" --output-filename "$f" --copy-command wl-copy \
                    --actions-on-enter save-to-file \
                    --actions-on-enter save-to-clipboard \
                    --actions-on-enter exit & ;;
    esac
}

# Reads a PNG on stdin, saves it to $FILE and copies it to the clipboard.
save_copy_notify() {
    tee "$FILE" | wl-copy --type image/png
    if [ -s "$FILE" ]; then
        notify_saved "$FILE"
    else
        notify-send "Screenshot" "Capture cancelled or failed" --expire-time=3000
    fi
}

# Open satty on a PNG read from stdin. Enter = save-to-file + copy + exit (one
# keypress); Esc cancels. satty's crop tool makes this ideal for trimming a
# fullscreen grab down to e.g. a hover tooltip you couldn't region-select.
SATTY_ENTER=(--actions-on-enter save-to-file --actions-on-enter save-to-clipboard --actions-on-enter exit)
annotate() {
    satty --filename - --output-filename "$FILE" --copy-command wl-copy "${SATTY_ENTER[@]}"
    [ -f "$FILE" ] && notify_saved "$FILE"
}

case "$MODE" in
    region)
        GEO=$(slurp) || exit 0
        grim -g "$GEO" - | annotate
        ;;
    output-annotate)
        # Fullscreen grab → satty (crop + annotate). Best for hover-only content:
        # hover the element, hit the keybind (mouse never moves), crop in satty.
        MON=$(hyprctl activeworkspace -j | jq -r '.monitor')
        grim -o "$MON" - | annotate
        ;;
    region-quick)
        GEO=$(slurp) || exit 0
        grim -g "$GEO" - | save_copy_notify
        ;;
    region-copy)
        GEO=$(slurp) || exit 0
        grim -g "$GEO" - | wl-copy --type image/png
        notify-send "Screenshot copied" "Region → clipboard (not saved)" --expire-time=3000
        ;;
    output-copy)
        MON=$(hyprctl activeworkspace -j | jq -r '.monitor')
        grim -o "$MON" - | wl-copy --type image/png
        notify-send "Screenshot copied" "Fullscreen → clipboard (not saved)" --expire-time=3000
        ;;
    window)
        GEO=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        [ "$GEO" = "," ] && exit 0
        grim -g "$GEO" - | save_copy_notify
        ;;
    output)
        MON=$(hyprctl activeworkspace -j | jq -r '.monitor')
        grim -o "$MON" - | save_copy_notify
        ;;
    output-delay)
        notify-send "Screenshot" "Capturing fullscreen in 3s…" --expire-time=2500
        sleep 3
        MON=$(hyprctl activeworkspace -j | jq -r '.monitor')
        grim -o "$MON" - | save_copy_notify
        ;;
    ocr)
        if ! command -v tesseract >/dev/null; then
            notify-send "OCR" "tesseract is not installed" --expire-time=3000; exit 1
        fi
        GEO=$(slurp) || exit 0
        TXT=$(grim -g "$GEO" - | tesseract - - 2>/dev/null)
        # Trim trailing whitespace/newlines
        TXT="${TXT%"${TXT##*[![:space:]]}"}"
        if [ -n "$TXT" ]; then
            printf '%s' "$TXT" | wl-copy
            notify-send "OCR — text copied" "$TXT" --expire-time=5000
        else
            notify-send "OCR" "No text detected in selection" --expire-time=3000
        fi
        ;;
    color)
        if ! command -v hyprpicker >/dev/null; then
            notify-send "Color picker" "hyprpicker is not installed" --expire-time=3000; exit 1
        fi
        HEX=$(hyprpicker -a -f hex) || exit 0   # -a auto-copies to clipboard
        [ -n "$HEX" ] && notify-send "Color copied" "$HEX" --expire-time=5000
        ;;
    *)
        echo "usage: $0 {region|region-quick|region-copy|window|output|output-annotate|output-copy|output-delay|ocr|color}" >&2
        exit 1
        ;;
esac
