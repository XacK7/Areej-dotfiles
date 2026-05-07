#!/bin/bash
# Pull latest config from origin and re-apply it.
# Run this on the Areej machine after pushing changes from elsewhere.
# Usage: ./update.sh
set -e

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

echo "==================================================="
echo "  Areej's Environment — Update"
echo "==================================================="

# Refuse to clobber local edits silently
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
echo "[1/3] Fetching from origin..."
git fetch --quiet origin

NEW_HEAD="$(git rev-parse origin/master)"
if [ "$OLD_HEAD" = "$NEW_HEAD" ]; then
    echo "  Already up to date ($OLD_HEAD)."
else
    git merge --ff-only origin/master
    echo "  Pulled $(git rev-list --count "$OLD_HEAD..$NEW_HEAD") commit(s)."

    # Warn if install.sh changed — user may need to install new packages
    if ! git diff --quiet "$OLD_HEAD" "$NEW_HEAD" -- install.sh; then
        echo ""
        echo "  ⚠  install.sh changed — run ./install.sh to install new packages."
    fi
fi

echo ""
echo "[2/3] Re-applying symlinks..."
./setup.sh > /dev/null
echo "  Done."

echo ""
echo "[3/3] Reloading Sway (if running)..."
# Locate sway's IPC socket — needed when running over SSH where SWAYSOCK is unset
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
