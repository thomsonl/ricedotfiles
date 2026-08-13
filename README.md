# ricedotfiles

A hand-built Arch Linux + Hyprland desktop.

## Features

**Status bar** - written from scratch in QML with [Quickshell](https://quickshell.org/), replacing waybar entirely:
- Live workspace indicators, aware of both monitors
- Media widget with MPRIS controls (play/pause/skip, seek bar, volume, album art)
- System stats pill (CPU/GPU/RAM) with a temperature breakdown on click
- Download speed indicator
- Current weather conditions (Open-Meteo, no API key required)
- Calendar/clock popup backed by Google Calendar (via `gcalcli`)
- Notification center implemented directly against the freedesktop.org Notifications
  spec, with toasts and a dropdown history, replacing swaync
- System tray implemented directly against the StatusNotifierItem spec
- Bluetooth, network, volume, and power menus
- Consistent dropdown behavior across both monitors - a full-screen click-catcher on
  the non-bar display closes any open dropdown regardless of which screen you click

**Hyprland**, configured entirely in Lua, with multiple swappable themes (catppuccin,
transparent, ultradark) covering the compositor, lock screen, idle behavior, and
wallpaper

**Workspace overview** via the `hyprtasking` plugin - a live grid of every workspace
with drag-and-drop windows between them

**Rotating wallpaper pool** on the primary monitor, curated for contrast so bar text
stays legible over any wallpaper

**Terminal and system tooling** styled to match:
- kitty, with a startup session that launches yazi, btop, Claude Code, and a plain
  shell across separate tabs
- btop, fastfetch, GTK theming

**Music**: Spotify re-themed via Spicetify (catppuccin), `cava` audio visualizer

## Layout

```
.config/hypr/         Hyprland config, themes, wallpaper scripts
.config/quickshell/    the status bar (QML)
.config/kitty/         terminal
.config/btop/          system monitor
.config/gtk-4.0/       GTK theming
.config/fastfetch/     system info banner
.config/spicetify/     Spotify theming
.config/cava/          audio visualizer
.config/wallpapers/    wallpaper sets used by the themes above
.bashrc, .bash_profile, .gitconfig
```
