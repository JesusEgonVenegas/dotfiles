#!/usr/bin/env bash
# Claude Code -> Quickshell bar bridge.
#
# Invoked from Claude Code hooks. Reads the hook JSON payload on stdin and an
# event keyword as $1, then maintains per-session state under
# ~/.local/state/cc-bar/sessions/ plus an aggregate state.json that the bar
# (ClaudeState.qml) watches.
#
# Events (state stored in the session file):
#   notify   -> Notification hook; classified into "action" (permission prompt,
#               must be answered) or "done" (idle / your turn) by the message
#   done     -> Stop hook; Claude finished its turn -> state "done"
#   busy     -> Claude is actively working -> state "busy" (clears waiting)
#   ack      -> acknowledged from the bar -> state "busy" ($2 = session id)
#   end      -> session ended, forget it
#
# "action" stays until real activity (PreToolUse/UserPromptSubmit) or an ack.
# "done" additionally auto-clears when you visit its workspace (handled in the bar).
set -euo pipefail

EVENT="${1:-busy}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cc-bar"
SESS_DIR="$STATE_DIR/sessions"
AGG="$STATE_DIR/state.json"
LOCK="$STATE_DIR/.lock"
mkdir -p "$SESS_DIR"

# Recompute the aggregate array the bar watches, atomically. Prune session
# files older than 12h so a crashed session that never sent "end" disappears.
rebuild_aggregate() {
    (
        flock 9
        find "$SESS_DIR" -name '*.json' -mmin +720 -delete 2>/dev/null || true
        if ! jq -s '.' "$SESS_DIR"/*.json > "$AGG.tmp" 2>/dev/null; then
            printf '[]' > "$AGG.tmp"
        fi
        mv -f "$AGG.tmp" "$AGG"
    ) 9>"$LOCK"
}

# Walk up the process tree from this hook to the terminal window and echo the
# Hyprland workspace id that window currently lives on. Empty if not found.
detect_ws() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    local clients pid ws stat rest
    clients="$(hyprctl clients -j 2>/dev/null)" || return 0
    pid=$PPID
    for _ in $(seq 1 12); do
        [ "${pid:-0}" -le 1 ] && break
        ws="$(printf '%s' "$clients" \
            | jq -r --argjson p "$pid" '.[] | select(.pid==$p) | .workspace.id' \
              2>/dev/null | head -n1)"
        [ -n "$ws" ] && { printf '%s' "$ws"; return 0; }
        # robust PPID read (comm may contain spaces/parens)
        stat="$(cat "/proc/$pid/stat" 2>/dev/null)" || break
        rest="${stat#*) }"
        # shellcheck disable=SC2086
        set -- $rest
        pid="$2"
    done
    return 0
}

# Acknowledge from the bar (clicking the chip). No stdin payload; the session
# id is passed as $2. Clears the "waiting" flag without ending the session.
if [ "$EVENT" = "ack" ]; then
    session_id="${2:-}"
    [ -z "$session_id" ] && exit 0
    sess_file="$SESS_DIR/$session_id.json"
    if [ -f "$sess_file" ]; then
        tmp="$sess_file.tmp.$$"
        jq '.state = "busy"' "$sess_file" > "$tmp" && mv -f "$tmp" "$sess_file"
    fi
    rebuild_aggregate
    exit 0
fi

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"
message="$(printf '%s' "$input" | jq -r '.message // empty' 2>/dev/null || true)"
[ -z "$session_id" ] && exit 0

sess_file="$SESS_DIR/$session_id.json"

# Forget the session.
if [ "$EVENT" = "end" ]; then
    rm -f "$sess_file"
    rebuild_aggregate
    exit 0
fi

# Map the event to a stored state.
case "$EVENT" in
    busy) state="busy" ;;
    done) state="done" ;;
    notify)
        # Permission prompts demand an answer ("action"); idle / "your turn"
        # notifications are just informational ("done", clears on visiting).
        if printf '%s' "$message" | grep -qi 'permission'; then
            state="action"
        else
            state="done"
        fi
        ;;
    *) state="busy" ;;
esac

# Fast path: reaffirming "busy" while already busy (PreToolUse fires on every
# tool call) — nothing to do.
if [ "$state" = "busy" ] && [ -f "$sess_file" ] \
    && grep -q '"state":"busy"' "$sess_file" 2>/dev/null; then
    exit 0
fi

ws="$(detect_ws)"
ts="$(date +%s)"

tmp="$sess_file.tmp.$$"
jq -nc \
    --arg id "$session_id" \
    --arg st "$state" \
    --arg cwd "$cwd" \
    --argjson ws "${ws:-null}" \
    --argjson ts "$ts" \
    '{session_id:$id, state:$st, ws:$ws, cwd:$cwd, ts:$ts}' > "$tmp"
mv -f "$tmp" "$sess_file"

rebuild_aggregate
