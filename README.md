# Areej Linux Config

Minimal Sway environment with a pink and green theme, built for Arch Linux.
Designed for a low-end machine (Pentium Dual Core, 4 GB RAM, 1920x1080).

## Quick install

```bash
git clone https://github.com/XacK7/Areej-dotfiles.git ~/Areej-dotfiles
cd ~/Areej-dotfiles
./install.sh    # installs packages (requires sudo)
./setup.sh      # creates symlinks and downloads the wallpaper
```

Then restart your session — Sway will start automatically via autologin.

## Keyboard shortcuts

Bindings mirror xack's sway config (AZERTY).

| Key | Action |
|-----|--------|
| Super + Enter | Open terminal (foot) |
| Super + D | App launcher (rofi) |
| Super + Shift + W | Close window |
| Super + Shift + C | Reload config |
| Super + Shift + E | Quit Sway (with confirm dialog) |
| Super + H J K L / Arrows | Move focus |
| Super + Shift + H J K L / Arrows | Move window |
| Super + & é " ' ( - è _ ç à | Switch to workspace 1–10 (AZERTY top row) |
| Super + Shift + (same row) | Move window to workspace 1–10 |
| Super + Ctrl + L / H | Next / previous workspace |
| Super + B / V | Split horizontal / vertical |
| Super + S / W / E | Stacking / tabbed / toggle split layout |
| Super + F | Fullscreen |
| Super + Shift + Space | Toggle floating |
| Super + Space | Focus tiled ↔ floating |
| Super + A | Focus parent container |
| Super + R | Resize mode (then h/j/k/l or arrows; Esc / Enter to exit) |
| Super + Alt + - | Send window to scratchpad |
| Super + Ctrl + - | Show / cycle scratchpad |
| Print | Screenshot (full screen, via grim) |
| Volume / Mic / Brightness keys | Adjust via pactl / brightnessctl |

## Media

- **Images**: `imv photo.jpg` or open from Thunar
- **Video / Music**: `mpv file.mp4` or Super + Shift + M

## Updating the config

**On the Areej machine** — pull, re-apply symlinks, and reload Sway in one step:

```bash
cd ~/Areej-dotfiles
./update.sh
```

`update.sh` refuses to run if there are uncommitted local changes (so personal
tweaks don't get clobbered silently). Commit, stash, or discard them first.

**From a remote machine** (e.g. the dev box where you edit configs) — push and
trigger the update over SSH in one step:

```bash
# bash / Git Bash / Linux
./deploy.sh
AREEJ_HOST=areej@otherhost ./deploy.sh

# Windows PowerShell
.\deploy.ps1
$env:AREEJ_HOST = "areej@otherhost"; .\deploy.ps1
```

`deploy.sh` / `deploy.ps1` runs `git push` then SSHes in and runs `update.sh`.
Requires SSH key auth to the host.

If `install.sh` changed (new packages added), `update.sh` will print a warning
— rerun `./install.sh` on the Areej machine to install them.

## Structure

```
linux-config/
├── install.sh        # installs Arch packages (sudo, run once)
├── setup.sh          # symlinks configs + downloads wallpaper
├── update.sh         # pull + re-apply + sway reload (run on the Areej machine)
├── deploy.sh         # push + remote update over SSH (bash / Git Bash / Linux)
├── deploy.ps1        # same, for native Windows PowerShell
└── config/
    ├── sway/         # main config + lock and start scripts
    ├── waybar/       # top bar (config + stylesheet)
    ├── rofi/         # app launcher
    ├── foot/         # terminal
    ├── mako/         # notifications
    └── nvim/         # Neovim (lazy.nvim, LSP, telescope, neotree)
```
