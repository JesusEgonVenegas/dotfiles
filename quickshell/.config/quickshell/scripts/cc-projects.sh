#!/usr/bin/env bash
# List recent Claude Code project directories, most-recent first, one per line.
# The dir names under ~/.claude/projects are munged/lossy, so the real cwd is
# recovered from each project's newest session .jsonl. Consumed by the "cc"
# launcher mode (LauncherState.qml).
set -uo pipefail
shopt -s nullglob

PROJ="$HOME/.claude/projects"
[ -d "$PROJ" ] || exit 0

for d in "$PROJ"/*/; do
    newest=""; newest_t=0
    for f in "$d"*.jsonl; do
        t=$(stat -c %Y "$f" 2>/dev/null || echo 0)
        (( t > newest_t )) && { newest_t=$t; newest="$f"; }
    done
    [ -n "$newest" ] || continue
    cwd="$(head -5 "$newest" | jq -r 'select(.cwd)|.cwd' 2>/dev/null | head -1)"
    [ -n "$cwd" ] && [ -d "$cwd" ] && printf '%s\t%s\n' "$newest_t" "$cwd"
done | sort -rn | awk -F'\t' '!seen[$2]++ {print $2}' | head -20
