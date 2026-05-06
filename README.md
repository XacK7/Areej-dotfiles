# Areej Linux Config

Environnement Sway minimal, theme rose et vert, pour Arch Linux.
Concu pour un PC modeste (Pentium Dual Core, 4 Go de RAM) et une debutante.

## Installation rapide

```bash
git clone https://github.com/<TON_COMPTE>/areej.git ~/linux-config
cd ~/linux-config
chmod +x install.sh setup.sh
./install.sh    # installe les paquets (necessite sudo)
./setup.sh      # cree les liens et telecharge le fond d'ecran
```

Ensuite relancer la session — Sway demarrera automatiquement.

## Raccourcis clavier

| Touche | Action |
|--------|--------|
| Super + Entree | Ouvrir le terminal |
| Super + D | Lancer une application |
| Super + Maj + F | Gestionnaire de fichiers |
| Super + Maj + B | Navigateur web |
| Super + Maj + M | Lecteur multimedia (mpv) |
| Super + Maj + Q | Fermer la fenetre |
| Super + F | Plein ecran |
| Super + Fleches | Changer de fenetre |
| Super + 1 a 6 | Changer d'espace de travail |
| Super + Maj + 1 a 6 | Deplacer fenetre vers cet espace |
| Impr. Ecran | Capture d'une zone (clic-glisse) |
| Super + Impr. Ecran | Capture d'ecran complet |
| Super + Maj + L | Verrouiller l'ecran |
| Super + Maj + R | Recharger la configuration |
| Super + Maj + E | Quitter |

## Lecteurs multimedia

- **Images** : `imv photo.jpg` ou ouvrir depuis Thunar
- **Videos / Musique** : `mpv fichier.mp4` ou Super + Maj + M

## Mise a jour de la config

```bash
cd ~/linux-config
git pull
./setup.sh   # re-applique les liens si besoin
# puis Super + Maj + R dans Sway pour recharger
```

## Structure

```
linux-config/
├── install.sh        # installe les paquets Arch
├── setup.sh          # cree les symlinks + wallpaper
└── config/
    ├── sway/         # config principale + scripts lock/start
    ├── waybar/       # barre du haut (config + style)
    ├── rofi/         # lanceur d'applications
    ├── foot/         # terminal
    └── mako/         # notifications
```
