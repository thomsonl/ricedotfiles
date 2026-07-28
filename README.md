# my-jasmine-rice.dot

A hand-built Arch Linux + Hyprland desktop.

## Features

- **Custom status bar** written from scratch in QML with [Quickshell](https://quickshell.org/),
  replacing waybar entirely:
  - Live workspace indicators per monitor
  - Media widget with MPRIS controls (play/pause/skip, seek bar, volume, album art)
  - A system tray implemented directly against the StatusNotifierItem spec
  - A notification center implemented directly against the freedesktop.org
    Notifications spec, with toasts and a dropdown history
  - Bluetooth, network, volume, and power menus
  - A calendar popup backed by Google Calendar
- **Hyprland** configured in Lua, with multiple swappable themes
  (catppuccin, transparent, ultradark) covering the compositor, lock screen,
  idle behavior, and wallpaper
- **Workspace overview** via the `hyprtasking` plugin — a live grid of every
  workspace with drag-and-drop windows between them
- **Rotating wallpaper pool** on the primary monitor, curated for contrast so
  bar text stays legible over any wallpaper
- Terminal and system-info styling to match (kitty, btop, fastfetch, GTK theme)

## Layout

```
.config/hypr/         Hyprland config, themes, wallpaper scripts
.config/quickshell/    the status bar (QML)
.config/kitty/         terminal
.config/btop/          system monitor
.config/gtk-3.0/, gtk-4.0/   GTK theming
.config/fastfetch/     system info banner
.config/wallpapers/    wallpaper sets used by the themes above
.bashrc, .bash_profile, .gitconfig
```
