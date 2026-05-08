#!/bin/bash
# Waybar start menu — curated launcher panel via rofi -dmenu.
# Bound to the leftmost icon button on the bar.

THEME="$HOME/.config/rofi/theme.rasi"

# dmenu icon protocol: "<label>\0icon\x1f<icon-name>"
entry() { printf '%s\0icon\x1f%s\n' "$1" "$2"; }

choice=$({
    entry "Browser"    "chromium"
    entry "Files"      "system-file-manager"
    entry "Terminal"   "utilities-terminal"
    entry "Editor"     "accessories-text-editor"
    entry "Screenshot" "camera-photo"
    entry "All Apps"   "view-app-grid-symbolic"
    entry "Lock"       "system-lock-screen"
    entry "Logout"     "system-log-out"
    entry "Reboot"     "system-reboot"
    entry "Shutdown"   "system-shutdown"
} | rofi -dmenu -i -show-icons -p "Launch" -theme "$THEME")

case "$choice" in
    Browser)    exec chromium ;;
    Files)      exec thunar ;;
    Terminal)   exec foot ;;
    Editor)     exec foot -e nvim ;;
    Screenshot) exec grim "$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png" ;;
    "All Apps") exec rofi -show drun -show-icons -theme "$THEME" ;;
    Lock)       exec "$HOME/.config/sway/lock.sh" ;;
    Logout)     exec swaymsg exit ;;
    Reboot)     exec systemctl reboot ;;
    Shutdown)   exec systemctl poweroff ;;
esac
