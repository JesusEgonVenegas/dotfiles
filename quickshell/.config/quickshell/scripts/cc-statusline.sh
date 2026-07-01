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
lines_add="$(jq -r '.cost.total_lines_added // 0' <<<"$in" 2>/dev/null)"
lines_rem="$(jq -r '.cost.total_lines_removed // 0' <<<"$in" 2>/dev/null)"
dur_ms="$(jq -r '.cost.total_duration_ms // 0' <<<"$in" 2>/dev/null)"
dur_min=$(( ${dur_ms:-0} / 60000 ))

# Current git branch of the working dir (empty if not a repo).
branch="$(git -C "${cwd:-/}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
[ "$branch" = "HEAD" ] && branch="$(git -C "${cwd:-/}" rev-parse --short HEAD 2>/dev/null || true)"

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

# --- print the status line (truecolor ANSI: phosphor green / amber / red / muted) ---
G=$'\e[38;2;71;245;91m'; A=$'\e[38;2;250;178;56m'; Rd=$'\e[38;2;220;80;80m'
D=$'\e[38;2;130;130;130m'; R=$'\e[0m'

# Context pressure: color ctx and nudge toward a fresh session when it's large.
if   [ "${ctxk:-0}" -ge 170 ]; then ctxc="$Rd"; hint="  ${Rd}· /clear?${R}"
elif [ "${ctxk:-0}" -ge 120 ]; then ctxc="$A";  hint=""
else                                ctxc="$D";  hint=""; fi

line="${G}${proj}${R}"
[ -n "$branch" ] && line="$line  ${D} ${branch}${R}"
line="$line  ${D}${model}${R}  ${A}\$$(printf '%.2f' "${cost:-0}")${R}  ${ctxc}ctx ${ctxk}k${R}"
[ "${dur_min:-0}" -gt 0 ] && line="$line  ${D}⧗ ${dur_min}m${R}"
if [ "${lines_add:-0}" -gt 0 ] || [ "${lines_rem:-0}" -gt 0 ]; then
    line="$line  ${G}+${lines_add}${R} ${Rd}-${lines_rem}${R}"
fi
line="$line$hint"
printf '%s\n' "$line"
