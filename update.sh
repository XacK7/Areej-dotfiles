#!/bin/bash
# Pull latest from origin. Code that's symlinked into ~/.config (control-panel)
# picks up changes automatically. App configs (sway/waybar/etc.) are real
# copies and stay host-local — to redeploy them from the repo, delete the
# corresponding ~/.config/<name> dir and rerun ./setup.sh.
# Usage: ./update.sh
set -e

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

echo "==================================================="
echo "  Areej's Environment — Update"
echo "==================================================="

if ! git diff-index --quiet HEAD --; then
    echo ""
    echo "  Working tree has uncommitted changes:"
    git status --short
    echo ""
    echo "  Commit, stash, or discard them before running update.sh."
    exit 1
fi

OLD_HEAD="$(git rev-parse HEAD)"

echo ""
echo "[1/2] Fetching from origin..."
git fetch --quiet origin

NEW_HEAD="$(git rev-parse origin/master)"
if [ "$OLD_HEAD" = "$NEW_HEAD" ]; then
    echo "  Already up to date ($OLD_HEAD)."
else
    git merge --ff-only origin/master
    echo "  Pulled $(git rev-list --count "$OLD_HEAD..$NEW_HEAD") commit(s)."

    if ! git diff --quiet "$OLD_HEAD" "$NEW_HEAD" -- install.sh; then
        echo ""
        echo "  ⚠  install.sh changed — run ./install.sh for new packages."
    fi

    # Hint when app configs changed in the repo — host copies don't auto-update
    changed_app_cfg="$(git diff --name-only "$OLD_HEAD" "$NEW_HEAD" -- \
        config/sway config/waybar config/rofi config/foot config/mako config/nvim)"
    if [ -n "$changed_app_cfg" ]; then
        echo ""
        echo "  ℹ  Repo app configs changed (sway/waybar/etc.). Host copies are"
        echo "     independent. To adopt repo changes for one of them:"
        echo "       rm -rf ~/.config/<name> && ./setup.sh"
    fi
fi

echo ""
echo "[2/2] Reloading Sway (if running)..."
if [ -z "$SWAYSOCK" ]; then
    SWAYSOCK="$(ls /run/user/"$(id -u)"/sway-ipc.*.sock 2>/dev/null | head -1)"
fi
if [ -S "$SWAYSOCK" ]; then
    SWAYSOCK="$SWAYSOCK" swaymsg reload > /dev/null && echo "  Reloaded."
else
    echo "  Sway not running, skipping."
fi

echo ""
echo "==================================================="
echo "  Update complete."
echo "==================================================="
