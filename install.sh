#!/bin/bash
# Installation des paquets pour l'environnement Sway d'Areej
# Usage: ./install.sh
set -e

echo "==================================================="
echo "  Installation de l'environnement Areej"
echo "==================================================="
echo ""

# Base packages (official repos)
BASE=(
    sway
    swaylock
    swayidle
    waybar
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

echo "[1/3] Installation des paquets de base..."
sudo pacman -S --needed --noconfirm "${BASE[@]}"

echo ""
echo "[2/3] Installation de PipeWire (audio)..."
sudo pacman -S --needed --noconfirm "${AUDIO[@]}"

echo ""
echo "[3/3] Activation de PipeWire..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || \
    echo "  (PipeWire deja actif ou session pas encore demarree — ok)"

echo ""
echo "==================================================="
echo "  Installation terminee !"
echo "  Lance maintenant : ./setup.sh"
echo "==================================================="
