# Areej Linux Config

Minimal Sway environment with a pink and green theme, built for Arch Linux.
Designed for a low-end machine (Pentium Dual Core, 4 GB RAM, 1920x1080).

## Quick install

```bash
git clone https://github.com/<YOUR_GITHUB>/areej.git ~/linux-config
cd ~/linux-config
chmod +x install.sh setup.sh
./install.sh    # installs packages (requires sudo)
./setup.sh      # creates symlinks and downloads the wallpaper
```

Then restart your session — Sway will start automatically via autologin.

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| Super + Enter | Open terminal |
| Super + D | Launch an app |
| Super + Shift + F | File manager |
| Super + Shift + B | Web browser |
| Super + Shift + M | Media player (mpv) |
| Super + Shift + Q | Close window |
| Super + F | Fullscreen |
| Super + Arrows | Move focus |
| Super + 1 to 6 | Switch workspace |
| Super + Shift + 1 to 6 | Move window to workspace |
| Print Screen | Capture a region (click and drag) |
| Super + Print Screen | Full screenshot |
| Super + Shift + L | Lock screen |
| Super + Shift + R | Reload config |
| Super + Shift + E | Quit Sway |

## Media

- **Images**: `imv photo.jpg` or open from Thunar
- **Video / Music**: `mpv file.mp4` or Super + Shift + M

## Updating the config

```bash
cd ~/linux-config
git pull
./setup.sh   # re-applies symlinks if needed
# then Super + Shift + R in Sway to reload
```

## Structure

```
linux-config/
├── install.sh        # installs Arch packages
├── setup.sh          # symlinks configs + downloads wallpaper
└── config/
    ├── sway/         # main config + lock and start scripts
    ├── waybar/       # top bar (config + stylesheet)
    ├── rofi/         # app launcher
    ├── foot/         # terminal
    ├── mako/         # notifications
    └── nvim/         # Neovim (lazy.nvim, LSP, telescope, neotree)
```
