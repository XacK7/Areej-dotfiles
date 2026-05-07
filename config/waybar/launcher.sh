#!/bin/bash
# Waybar start menu — curated launcher panel via rofi -dmenu.
# Bound to the leftmost icon button on the bar.

THEME="$HOME/.config/rofi/theme.rasi"

choice=$(printf '%s\n' \
    "  Browser" \
    "  Files" \
    "  Terminal" \
    "  Editor" \
    "  Screenshot" \
    "  All Apps" \
    "  Lock" \
    "  Logout" \
    "  Reboot" \
    "  Shutdown" \
    | rofi -dmenu -i -p "Launch" -theme "$THEME")

case "$choice" in
    *Browser)    exec firefox ;;
    *Files)      exec thunar ;;
    *Terminal)   exec foot ;;
    *Editor)     exec foot -e nvim ;;
    *Screenshot) exec grim "$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png" ;;
    *"All Apps") exec rofi -show drun -show-icons -theme "$THEME" ;;
    *Lock)       exec "$HOME/.config/sway/lock.sh" ;;
    *Logout)     exec swaymsg exit ;;
    *Reboot)     exec systemctl reboot ;;
    *Shutdown)   exec systemctl poweroff ;;
esac
