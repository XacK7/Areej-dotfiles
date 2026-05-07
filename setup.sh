#!/bin/bash
# Set up Areej's environment: symlinks + wallpaper download
# Usage: ./setup.sh
set -e

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HOME/.config"

echo "==================================================="
echo "  Areej's Environment — Setup"
echo "==================================================="
echo ""

# ── Wallpaper ────────────────────────────────────────────
echo "[1/3] Wallpaper..."
mkdir -p "$HOME/wallpapers"
if [ ! -f "$HOME/wallpapers/wallpaper.jpg" ]; then
    curl -L --progress-bar \
        "https://w.wallhaven.cc/full/yq/wallhaven-yqg6r7.jpg" \
        -o "$HOME/wallpapers/wallpaper.jpg"
    echo "  Downloaded!"
else
    echo "  Already present, skipping."
fi

# ── XDG directories ──────────────────────────────────────
echo ""
echo "[2/3] Creating user directories (Pictures, Music...)..."
xdg-user-dirs-update
mkdir -p "$HOME/Pictures"

# ── Symlinks ─────────────────────────────────────────────
echo ""
echo "[3/3] Linking config files..."

link_config() {
    local name="$1"
    local src="$REPO/config/$name"
    local dest="$CFG/$name"

    # Back up existing real directory
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "${dest}.bak"
        echo "  Backed up: ${dest}.bak"
    fi

    # Remove stale symlink
    [ -L "$dest" ] && rm "$dest"

    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
    echo "  $dest -> $src"
}

link_config "sway"
link_config "waybar"
link_config "rofi"
link_config "foot"
link_config "mako"
link_config "nvim"

echo ""
echo "==================================================="
echo "  All done!"
echo ""
echo "  Run 'sway' in a terminal to start,"
echo "  or restart your session if autologin is active."
echo "==================================================="
