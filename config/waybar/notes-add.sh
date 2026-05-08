#!/bin/bash
# Waybar notes — right-click handler. Prompts for a new note title.

NOTES_DIR="$HOME/.local/share/waybar-notes"
mkdir -p "$NOTES_DIR"

# The shared rofi theme disables inputbar and excludes it from mainbox.
# Override locally so this prompt actually shows a text entry.
THEME_OVERRIDE='
inputbar { enabled: true; children: [ prompt, entry ]; padding: 8px 12px; background-color: @bg-alt; border-radius: 8px; spacing: 8px; }
prompt { text-color: @pink; }
entry { placeholder: "Type your note..."; placeholder-color: @muted; }
mainbox { children: [ inputbar ]; }
listview { lines: 0; }
'

input=$(rofi -dmenu -p "New note" -lines 0 -theme-str "$THEME_OVERRIDE" < /dev/null)
[ -z "$input" ] && exit 0

filename="$NOTES_DIR/$(date +%Y-%m-%d-%H%M%S).txt"
printf '%s\n' "$input" > "$filename"
