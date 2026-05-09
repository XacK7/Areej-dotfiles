#!/bin/bash
# Set up Areej's environment.
# - App configs (sway/waybar/rofi/foot/mako/nvim) are *copied* into ~/.config so
#   host-side edits and runtime writes (control panel themes, wallpapers, etc.)
#   stay local and don't pollute the git working tree.
# - control-panel itself stays *symlinked* — it's our code, follows the repo.
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
echo "[2/3] Creating user directories..."
xdg-user-dirs-update
mkdir -p "$HOME/Pictures"
mkdir -p "$HOME/.local/share/waybar-notes"
mkdir -p "$HOME/.local/state/control-panel"
mkdir -p "$HOME/.cache/control-panel"

# ── App configs: copy from repo (host-local after install) ────────
echo ""
echo "[3/3] Installing configs..."

copy_config() {
    local name="$1"
    local src="$REPO/config/$name"
    local dest="$CFG/$name"

    # Convert legacy symlink (old setup) to a real copy
    if [ -L "$dest" ]; then
        rm "$dest"
    fi

    if [ -e "$dest" ]; then
        echo "  $dest already exists — leaving alone"
        echo "    (delete it and rerun ./setup.sh to redeploy from repo)"
        return
    fi

    mkdir -p "$(dirname "$dest")"
    cp -r "$src" "$dest"
    echo "  $dest <- $src (copy)"
}

link_config() {
    local name="$1"
    local src="$REPO/config/$name"
    local dest="$CFG/$name"

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "${dest}.bak"
        echo "  Backed up: ${dest}.bak"
    fi

    [ -L "$dest" ] && rm "$dest"

    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
    echo "  $dest -> $src (symlink)"
}

# App configs: real copies, host owns them after first install
copy_config "sway"
copy_config "waybar"
copy_config "rofi"
copy_config "foot"
copy_config "mako"
copy_config "nvim"

# Control panel: symlink so code edits in the repo apply immediately
link_config "control-panel"

echo ""
echo "==================================================="
echo "  All done!"
echo ""
echo "  Run 'sway' in a terminal to start,"
echo "  or restart your session if autologin is active."
echo "==================================================="
