#!/bin/bash
# Waybar notes — left-click handler.
# Pick a note, then choose View / Edit / Delete via rofi.

NOTES_DIR="$HOME/.local/share/waybar-notes"
mkdir -p "$NOTES_DIR"

mapfile -t notes < <(find "$NOTES_DIR" -maxdepth 1 -type f -name '*.txt' | sort)
count=${#notes[@]}

if [ "$count" -eq 0 ]; then
    rofi -e "No notes yet. Right-click the 📝 to add one."
    exit 0
fi

# Build menu: line N corresponds to notes[N]
menu=""
for f in "${notes[@]}"; do
    title=$(head -n 1 "$f")
    [ -z "$title" ] && title="(untitled)"
    menu+="$title"$'\n'
done
menu="${menu%$'\n'}"

picked_idx=$(printf '%s' "$menu" | rofi -dmenu -i -p "Notes" -format i)
[ -z "$picked_idx" ] && exit 0

file="${notes[$picked_idx]}"
[ ! -f "$file" ] && exit 0

action=$(printf 'View\nEdit\nDelete' | rofi -dmenu -i -p "$(head -n 1 "$file")")

case "$action" in
    View)
        body=$(cat "$file")
        rofi -e "$body"
        ;;
    Edit)
        foot -e "${EDITOR:-nvim}" "$file"
        ;;
    Delete)
        confirm=$(printf 'No\nYes' | rofi -dmenu -i -p "Delete this note?")
        [ "$confirm" = "Yes" ] && rm -f "$file"
        ;;
esac
