#!/bin/bash
# Restarts bar, notifications, and clipboard watcher — safe to run on sway reload
pkill -x waybar      2>/dev/null; sleep 0.1
pkill -x mako        2>/dev/null; sleep 0.1
pkill -f "wl-paste.*cliphist" 2>/dev/null; sleep 0.1
waybar &
mako &
# Clipboard history watcher (text + images)
wl-paste --type text  --watch cliphist store &
wl-paste --type image --watch cliphist store &
