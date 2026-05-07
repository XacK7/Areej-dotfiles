#!/bin/bash
# Push current branch to origin, then trigger update on the Areej machine.
# Usage: ./deploy.sh                       # push master, update default host
#        AREEJ_HOST=user@host ./deploy.sh  # custom host
set -e

HOST="${AREEJ_HOST:-areej@192.168.1.9}"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "==================================================="
echo "  Deploy: pushing '$BRANCH' to origin, then updating $HOST"
echo "==================================================="
echo ""

if ! git diff-index --quiet HEAD --; then
    echo "  Working tree has uncommitted changes. Commit first."
    git status --short
    exit 1
fi

echo "[1/2] git push origin $BRANCH"
git push origin "$BRANCH"

echo ""
echo "[2/2] ssh $HOST './Areej-dotfiles/update.sh'"
ssh "$HOST" 'cd ~/Areej-dotfiles && ./update.sh'

echo ""
echo "==================================================="
echo "  Deployed."
echo "==================================================="
