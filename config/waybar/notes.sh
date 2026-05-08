#!/bin/bash
# Waybar custom module: rotating notes.
# Cycles through one-file-per-note in ~/.local/share/waybar-notes/, advancing
# every tick. Title (first line of file) shown on bar; body shown in tooltip.

NOTES_DIR="$HOME/.local/share/waybar-notes"
INDEX_FILE="$HOME/.cache/waybar-notes-index"
MAX_TITLE=30

mkdir -p "$NOTES_DIR" "$(dirname "$INDEX_FILE")"

# Collect notes sorted alphabetically (= chronological by timestamped name)
mapfile -t notes < <(find "$NOTES_DIR" -maxdepth 1 -type f -name '*.txt' | sort)
count=${#notes[@]}

if [ "$count" -eq 0 ]; then
    printf '{"text":"📝 (no notes)","tooltip":"Right-click to add a note"}\n'
    exit 0
fi

# Read + clamp current index
idx=0
[ -f "$INDEX_FILE" ] && idx=$(cat "$INDEX_FILE" 2>/dev/null || echo 0)
case "$idx" in
    ''|*[!0-9]*) idx=0 ;;
esac
[ "$idx" -ge "$count" ] && idx=0

file="${notes[$idx]}"
title=$(head -n 1 "$file")
body=$(tail -n +2 "$file")
[ -z "$body" ] && body="No body"
[ -z "$title" ] && title="(untitled)"

# Truncate title
if [ "${#title}" -gt "$MAX_TITLE" ]; then
    title="${title:0:$MAX_TITLE}…"
fi

# Escape JSON
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/}"
    printf '%s' "$s"
}

title_esc=$(json_escape "$title")
body_esc=$(json_escape "$body")

printf '{"text":"📝 %s","tooltip":"%s","class":"notes"}\n' "$title_esc" "$body_esc"

# Advance index
echo $(( (idx + 1) % count )) > "$INDEX_FILE"
