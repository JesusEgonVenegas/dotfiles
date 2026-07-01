#!/usr/bin/env bash
# Claude Code statusLine. Prints a compact, Lain-themed status line for the
# terminal UI, AND records this session's cost + context size to the cc-bar
# state so the Quickshell bar can show total live spend.
#
# stdin: the statusLine JSON payload from Claude Code.
set -uo pipefail

in="$(cat)"
get() { jq -r "$1 // empty" <<<"$in" 2>/dev/null; }

sid="$(get '.session_id')"
model="$(get '.model.display_name')"; [ -z "$model" ] && model="$(get '.model.id')"
cwd="$(get '.workspace.current_dir')"; [ -z "$cwd" ] && cwd="$(get '.cwd')"
cost="$(jq -r '.cost.total_cost_usd // 0' <<<"$in" 2>/dev/null)"
tpath="$(get '.transcript_path')"
proj="$(basename "${cwd:-?}")"

# Context size = the most recent message's total input tokens (live context use).
ctx=0
if [ -n "$tpath" ] && [ -f "$tpath" ]; then
    v="$(tac "$tpath" 2>/dev/null | jq -r 'select(.message.usage) | .message.usage
         | (.input_tokens + (.cache_read_input_tokens//0) + (.cache_creation_input_tokens//0))' \
         2>/dev/null | head -1)"
    [ -n "$v" ] && ctx="$v"
fi
ctxk=$(( ctx / 1000 ))

# --- record cost/context for the bar (per-session file the widget aggregates) ---
COST_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cc-bar/cost"
mkdir -p "$COST_DIR"
if [ -n "$sid" ]; then
    tmp="$COST_DIR/$sid.json.tmp.$$"
    if jq -nc --arg id "$sid" --argjson cost "${cost:-0}" \
              --argjson ctx "${ctx:-0}" --argjson ts "$(date +%s)" \
              '{session_id:$id, cost:$cost, ctx:$ctx, ts:$ts}' > "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$COST_DIR/$sid.json"
    else
        rm -f "$tmp"
    fi
fi

# --- print the status line (truecolor ANSI: phosphor green / amber / muted) ---
G=$'\e[38;2;71;245;91m'; A=$'\e[38;2;250;178;56m'; D=$'\e[38;2;130;130;130m'; R=$'\e[0m'
printf '%s%s%s  %s%s%s  %s$%.2f%s  %sctx %dk%s\n' \
    "$G" "$proj" "$R"  "$D" "$model" "$R"  "$A" "$cost" "$R"  "$D" "$ctxk" "$R"
