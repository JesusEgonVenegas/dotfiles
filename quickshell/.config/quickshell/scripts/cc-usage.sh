#!/usr/bin/env bash
# Sum Claude "effective token" consumption over a rolling 5h window and since
# local midnight, across recent transcripts. Cache reads are weighted x0.1 (as
# in pricing) so long cached sessions don't wildly inflate the number.
# Output: {"win":<tokens_5h>,"day":<tokens_today>}. Consumed by ClaudeState.qml.
set -uo pipefail
shopt -s nullglob

now=$(date +%s)
cut5h=$(( now - 18000 ))
midnight=$(date -d 'today 00:00:00' +%s 2>/dev/null || echo "$cut5h")
oldest=$cut5h; [ "$midnight" -lt "$oldest" ] && oldest=$midnight

win=0; day=0
for f in "$HOME/.claude/projects"/*/*.jsonl; do
    mt=$(stat -c %Y "$f" 2>/dev/null || echo 0)
    [ "$mt" -lt "$oldest" ] && continue
    while IFS=$'\t' read -r ts tok; do
        [ -z "${ts:-}" ] && continue
        (( ts >= cut5h ))    && win=$(( win + tok ))
        (( ts >= midnight )) && day=$(( day + tok ))
    done < <(jq -r '
        select(.message.usage and .timestamp)
        | [ ((.timestamp | sub("\\.[0-9]+Z$";"Z")) | fromdateiso8601),
            (.message.usage
             | (.input_tokens + .output_tokens
                + (.cache_creation_input_tokens // 0)
                + ((.cache_read_input_tokens // 0) / 10 | floor))) ]
        | @tsv' "$f" 2>/dev/null)
done
printf '{"win":%d,"day":%d}\n' "$win" "$day"
