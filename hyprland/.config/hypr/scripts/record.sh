#!/bin/bash
# Usage: record.sh <command> [audio]
#   command: region | output | stop | toggle
#   audio:   mic | system   (optional, ignored for stop/toggle)
#
# Records the screen with wf-recorder. Only one recording runs at a time,
# tracked via a pidfile so any "stop"/menu invocation can end it cleanly.

OUTDIR="$HOME/videos/recordings"
PIDFILE="/tmp/wf-recorder.pid"
FILEREF="/tmp/wf-recorder.file"
# Published to the Quickshell bar (RecordState.qml watches this file).
STATEDIR="$HOME/.local/state/screen-rec"
STATEFILE="$STATEDIR/state.json"

# Hardware encoding: NVENC on the RTX 2060 (offloads the CPU). Set USE_HWENC=0
# to force software x264. The script also auto-falls-back to x264 if NVENC
# fails to start for any reason (driver hiccup, format mismatch, etc).
USE_HWENC=${USE_HWENC:-1}
HWENC_ARGS=(-c h264_nvenc -x yuv420p -p preset=p5 -p rc=vbr -p cq=23)

mkdir -p "$OUTDIR" "$STATEDIR"

is_running() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

# Publish recording state for the bar indicator. Uses caller's locals when on.
write_state() {
    if [ "$1" = "on" ]; then
        printf '{"recording":true,"start":%s,"encoder":"%s","audio":"%s","file":"%s"}\n' \
            "$START_EPOCH" "$encoder" "${audio:-}" "$file" > "$STATEFILE"
    else
        printf '{"recording":false}\n' > "$STATEFILE"
    fi
}

stop_recording() {
    if ! is_running; then
        notify-send "Recording" "Nothing is recording" --expire-time=3000
        rm -f "$PIDFILE" "$FILEREF"
        write_state off
        exit 0
    fi
    PID=$(cat "$PIDFILE")
    FILE=$(cat "$FILEREF" 2>/dev/null)
    # SIGINT lets wf-recorder flush and finalise the container
    kill -INT "$PID"
    for _ in $(seq 1 50); do kill -0 "$PID" 2>/dev/null || break; sleep 0.1; done
    rm -f "$PIDFILE" "$FILEREF"
    write_state off

    if [ -n "$FILE" ] && [ -f "$FILE" ]; then
        ACTION=$(notify-send "Recording saved" "$(basename "$FILE")" \
            -A "open=Open" -A "folder=Open folder" --expire-time=8000 2>/dev/null)
        case "$ACTION" in
            open)   xdg-open "$FILE" & ;;
            folder) xdg-open "$OUTDIR" & ;;
        esac
    else
        notify-send "Recording stopped" "Saved to $OUTDIR" --expire-time=4000
    fi
}

start_recording() {
    if is_running; then
        notify-send "Recording" "Already recording — stop it first" --expire-time=3000
        exit 0
    fi

    local mode="$1" audio="${2:-}"
    local ts file
    ts=$(date +%Y%m%d_%H%M%S)
    file="$OUTDIR/recording_${ts}.mp4"

    local args=(-f "$file")
    case "$mode" in
        region)
            local geo
            geo=$(slurp) || exit 0          # cancelled selection → bail
            args+=(-g "$geo")
            ;;
        output)
            local mon
            mon=$(hyprctl activeworkspace -j | jq -r '.monitor')
            args+=(-o "$mon")
            ;;
        *)
            notify-send "Recording" "Unknown mode: $mode" --expire-time=3000
            exit 1
            ;;
    esac

    case "$audio" in
        mic)    args+=(--audio) ;;
        system) args+=(--audio="$(pactl get-default-sink).monitor") ;;
    esac

    # Try hardware (NVENC) first, then fall back to software x264.
    local encoder pid="" START_EPOCH
    START_EPOCH=$(date +%s)
    if [ "$USE_HWENC" = "1" ] && try_launch "${args[@]}" "${HWENC_ARGS[@]}"; then
        encoder="NVENC"
        pid=$WF_PID
    elif try_launch "${args[@]}"; then
        encoder="x264"
        pid=$WF_PID
    fi

    if [ -z "$pid" ]; then
        rm -f "$PIDFILE" "$FILEREF"
        write_state off
        notify-send "Recording failed" "$(tail -n1 /tmp/wf-recorder.log)" --expire-time=6000
        exit 1
    fi

    echo "$pid"  > "$PIDFILE"
    echo "$file" > "$FILEREF"
    # Feedback lives in the bar (RecordWidget), NOT an on-screen toast — a toast
    # here would be captured into the recording. The red "REC mm:ss" chip appears
    # instead; click it or press Super+Shift+R to stop.
    write_state on
}

# Launch wf-recorder in the background and confirm it survived startup.
# Sets WF_PID on success; returns non-zero if it died (e.g. encoder rejected).
try_launch() {
    wf-recorder "$@" >/tmp/wf-recorder.log 2>&1 &
    WF_PID=$!
    sleep 0.5
    kill -0 "$WF_PID" 2>/dev/null
}

case "${1:-}" in
    stop)   stop_recording ;;
    toggle) if is_running; then stop_recording; else start_recording output "${2:-}"; fi ;;
    region|output) start_recording "$1" "${2:-}" ;;
    *) echo "usage: $0 {region|output|stop|toggle} [mic|system]" >&2; exit 1 ;;
esac
