#!/bin/bash
# Waybar notes — right-click handler. Prompts for a new note title.

NOTES_DIR="$HOME/.local/share/waybar-notes"
mkdir -p "$NOTES_DIR"

input=$(rofi -dmenu -p "New note" -lines 0 < /dev/null)
[ -z "$input" ] && exit 0

filename="$NOTES_DIR/$(date +%Y-%m-%d-%H%M%S).txt"
printf '%s\n' "$input" > "$filename"
