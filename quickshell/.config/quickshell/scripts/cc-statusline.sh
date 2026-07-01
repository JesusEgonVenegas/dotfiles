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

# Account-wide 5h rate-limit usage, cached by the bar's cc-usage.sh (too heavy
# to recompute here every render). Replaces the flat-rate $ figure: on a Max
# plan what matters is block consumption + when it resets. Colored against your
# own peak block so it self-calibrates; segment is omitted when idle/no cache.
useg=""
ucache="${XDG_STATE_HOME:-$HOME/.local/state}/cc-bar/usage.json"
if [ -f "$ucache" ]; then
    read -r uwin ureset upeak < <(jq -r '"\(.win // 0) \(.reset // 0) \(.peak // 0)"' "$ucache" 2>/dev/null)
    [[ "$uwin"   =~ ^[0-9]+$ ]] || uwin=0
    [[ "$ureset" =~ ^[0-9]+$ ]] || ureset=0
    [[ "$upeak"  =~ ^[0-9]+$ ]] || upeak=0
    if [ "$uwin" -gt 0 ]; then
        uwinf="$(awk -v n="$uwin" 'BEGIN{ if(n>=1e6) printf "%.1fM",n/1e6; else if(n>=1000) printf "%dk",int(n/1000+0.5); else printf "%d",n }')"
        uc="$D"
        if [ "$upeak" -gt 0 ]; then
            if   [ "$uwin" -ge $(( upeak * 95 / 100 )) ]; then uc="$Rd"
            elif [ "$uwin" -ge $(( upeak * 3 / 4 )) ];    then uc="$A"; fi
        fi
        rseg=""
        if [ "$ureset" -gt 0 ]; then
            left=$(( ureset - $(date +%s) ))
            if [ "$left" -gt 0 ]; then
                rh=$(( left / 3600 )); rm=$(( (left % 3600) / 60 ))
                if [ "$rh" -gt 0 ]; then rseg="$(printf ' ↻%dh%02dm' "$rh" "$rm")"
                else                     rseg="$(printf ' ↻%dm' "$rm")"; fi
            fi
        fi
        useg="${uc}5h ${uwinf}${R}${D}${rseg}${R}"
    fi
fi

line="${G}${proj}${R}"
[ -n "$branch" ] && line="$line  ${D} ${branch}${R}"
line="$line  ${D}${model}${R}"
[ -n "$useg" ] && line="$line  $useg"
line="$line  ${ctxc}ctx ${ctxk}k${R}"
[ "${dur_min:-0}" -gt 0 ] && line="$line  ${D}⧗ ${dur_min}m${R}"
if [ "${lines_add:-0}" -gt 0 ] || [ "${lines_rem:-0}" -gt 0 ]; then
    line="$line  ${G}+${lines_add}${R} ${Rd}-${lines_rem}${R}"
fi
line="$line$hint"
printf '%s\n' "$line"
