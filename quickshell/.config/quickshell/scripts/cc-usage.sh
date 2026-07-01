#!/usr/bin/env bash
# Effective-token consumption for Claude Code, tuned for a Max plan: cost is
# flat, so the number that matters is rate-limit pressure. Anthropic meters in
# fixed ~5h blocks — a block opens on your first message and resets exactly 5h
# later — so we reconstruct those blocks instead of a naive trailing sum.
#
# Emits JSON consumed by ClaudeState.qml:
#   win   effective tokens in the current *open* 5h block (0 when idle)
#   reset epoch when the open block resets (0 when no block is open)
#   day   effective tokens since local midnight
#   week  effective tokens over the last 7 days
#   peak  largest *closed* 5h block ever seen — self-calibrates the warn/crit
#         thresholds so we don't rely on guessed limits (0 until one closes)
#
# Cache reads are weighted x0.1 (as in pricing) so long cached sessions don't
# wildly inflate the totals.
set -uo pipefail
shopt -s nullglob

now=$(date +%s)
week_cut=$(( now - 604800 ))                                   # 7 days
midnight=$(date -d 'today 00:00:00' +%s 2>/dev/null || echo "$week_cut")

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

# (epoch, effective_tokens, model_family) for every usage-bearing message in
# the last 7 days. Family buckets the long model id into opus/sonnet/haiku so
# the current block can be split by model (Opus burns the Max limit fastest).
for f in "$HOME/.claude/projects"/*/*.jsonl; do
    mt=$(stat -c %Y "$f" 2>/dev/null || echo 0)
    [ "$mt" -lt "$week_cut" ] && continue
    jq -r '
        select(.message.usage and .timestamp)
        | (.message.model // "") as $m
        | [ ((.timestamp | sub("\\.[0-9]+Z$";"Z")) | fromdateiso8601),
            (.message.usage
             | (.input_tokens + .output_tokens
                + (.cache_creation_input_tokens // 0)
                + ((.cache_read_input_tokens // 0) / 10 | floor))),
            (if   ($m | test("opus"))   then "opus"
             elif ($m | test("sonnet")) then "sonnet"
             elif ($m | test("haiku"))  then "haiku"
             else "other" end) ]
        | @tsv' "$f" 2>/dev/null
done > "$tmp"

# Fold the time-sorted stream into 5h blocks. day/week are simple rollups; the
# block walk yields the current open block (win/reset) and the peak closed block.
result="$(sort -k1,1n "$tmp" | awk -v now="$now" -v mid="$midnight" -v wk="$week_cut" '
    BEGIN { FS="\t"; blk=18000; bstart=0; bsum=0; peak=0 }
    {
        ts=$1; tok=$2; fam=$3; if (ts=="") next
        if (ts>=mid) day+=tok
        if (ts>=wk)  week+=tok
        # New block when none is open or this message lands past the 5h reset.
        if (bstart==0 || ts>=bstart+blk) {
            if (bstart>0 && bsum>peak) peak=bsum   # close previous block
            bstart=ts; bsum=0; delete bfam         # reset per-model tallies
        }
        bsum+=tok
        if (fam != "") bfam[fam]+=tok
    }
    END {
        win=0; reset=0; op=0; so=0; ha=0
        if (bstart>0 && now < bstart+blk) {        # still open
            win=bsum; reset=bstart+blk
            op=bfam["opus"]+0; so=bfam["sonnet"]+0; ha=bfam["haiku"]+0
        } else if (bsum>peak) peak=bsum            # last block closed
        printf "{\"win\":%d,\"reset\":%d,\"day\":%d,\"week\":%d,\"peak\":%d," \
               "\"opus\":%d,\"sonnet\":%d,\"haiku\":%d}\n", \
               win, reset, day, week, peak, op, so, ha
    }
')"

# Cache the result so cheap, high-frequency readers (the terminal statusLine)
# can show 5h usage without paying the full transcript scan on every render.
cache="${XDG_STATE_HOME:-$HOME/.local/state}/cc-bar/usage.json"
mkdir -p "${cache%/*}"
if printf '%s\n' "$result" > "$cache.tmp.$$" 2>/dev/null; then
    mv -f "$cache.tmp.$$" "$cache"
else
    rm -f "$cache.tmp.$$"
fi

printf '%s\n' "$result"
