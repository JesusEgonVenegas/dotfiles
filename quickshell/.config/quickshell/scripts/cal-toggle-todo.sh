#!/bin/sh
# Flip the "- [ ]" / "- [x]" checkbox on a given 1-based line of a markdown file.
# Used by CalendarState.toggleTodo() so todos in the panel are actually checkable.
#   usage: cal-toggle-todo.sh <file> <line-number>
file="$1"; line="$2"
[ -f "$file" ] || exit 1
awk -v ln="$line" 'NR==ln {
  if ($0 ~ /\[[xX]\]/)      sub(/\[[xX]\]/, "[ ]")
  else if ($0 ~ /\[ \]/)    sub(/\[ \]/,   "[x]")
}
{ print }
' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
