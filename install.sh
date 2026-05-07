#!/bin/bash
# Install packages for Areej's Sway environment
# Usage: ./install.sh
set -e

echo "==================================================="
echo "  Areej's Environment — Package Installation"
echo "==================================================="
echo ""

# Base packages (official repos)
BASE=(
    sway
    swaylock
    waybar
    neovim
    rofi-wayland
    foot
    mako
    imv
    mpv
    grim
    slurp
    wl-clipboard
    xdg-user-dirs
    polkit-gnome
    brightnessctl
    playerctl
    noto-fonts
    noto-fonts-emoji
    ttf-jetbrains-mono
    ttf-font-awesome
    papirus-icon-theme
    curl
    git
)

# PipeWire audio
AUDIO=(
    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber
)

echo "[1/3] Installing base packages..."
sudo pacman -S --needed --noconfirm "${BASE[@]}"

echo ""
echo "[2/3] Installing PipeWire (audio)..."
sudo pacman -S --needed --noconfirm "${AUDIO[@]}"

echo ""
echo "[3/3] Enabling PipeWire..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || \
    echo "  (PipeWire already running or user session not started yet — that's fine)"

echo ""
echo "==================================================="
echo "  Done! Now run: ./setup.sh"
echo "==================================================="
