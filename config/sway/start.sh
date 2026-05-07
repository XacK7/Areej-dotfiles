#!/bin/bash
# Restarts bar and notifications — safe to run on sway reload
pkill -x waybar 2>/dev/null; sleep 0.1
pkill -x mako   2>/dev/null; sleep 0.1
waybar &
mako &
