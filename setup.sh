#!/bin/bash
# Configure l'environnement Areej : symlinks + wallpaper
# Usage: ./setup.sh
set -e

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HOME/.config"

echo "==================================================="
echo "  Configuration de l'environnement Areej"
echo "==================================================="
echo ""

# ── Wallpaper ────────────────────────────────────────────
echo "[1/3] Fond d'ecran..."
mkdir -p "$HOME/wallpapers"
if [ ! -f "$HOME/wallpapers/wallpaper.jpg" ]; then
    curl -L --progress-bar \
        "https://w.wallhaven.cc/full/yq/wallhaven-yqg6r7.jpg" \
        -o "$HOME/wallpapers/wallpaper.jpg"
    echo "  Telecharge !"
else
    echo "  Deja present, rien a faire."
fi

# ── XDG directories ──────────────────────────────────────
echo ""
echo "[2/3] Dossiers utilisateur (Images, Musique...)..."
xdg-user-dirs-update
mkdir -p "$HOME/Images"

# ── Symlinks ─────────────────────────────────────────────
echo ""
echo "[3/3] Creation des liens de configuration..."

link_config() {
    local name="$1"
    local src="$REPO/config/$name"
    local dest="$CFG/$name"

    # Back up existing real directory
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "${dest}.bak"
        echo "  Sauvegarde : ${dest}.bak"
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

# Make shell scripts executable
chmod +x "$REPO/config/sway/start.sh"
chmod +x "$REPO/config/sway/lock.sh"

echo ""
echo "==================================================="
echo "  Configuration terminee !"
echo ""
echo "  Lance 'sway' dans le terminal pour demarrer."
echo "  (ou redemarrer ta session si l'autologin est actif)"
echo "==================================================="
