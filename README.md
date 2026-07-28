# my-jasmine-rice.dot

My Arch Linux + Hyprland rice, hand-built rather than installer-generated.

## What's here

- `.config/hypr/` — Hyprland config (`hyprland.lua`; the old `hyprland.conf` is
  dead and not used), lock/idle/paper themes, and the wallpaper-rotation
  scripts.
- `.config/quickshell/` — a custom status bar built from scratch in QML
  (Quickshell), replacing waybar. Workspaces, media (MPRIS), a system tray
  implementing the StatusNotifierItem spec directly, notifications
  implementing the freedesktop.org Notifications spec directly, bluetooth,
  network, volume, power, and a Google Calendar popup.
- `.config/kitty/`, `.config/btop/`, `.config/gtk-3.0/`, `.config/gtk-4.0/`,
  `.config/fastfetch/` — supporting app configs.
- `.bashrc`, `.bash_profile`, `.gitconfig` — shell/git setup.
- `.config/wallpapers/` — every wallpaper actually used: `archimg-dark/` (the
  150-image DP-1 rotation pool, sourced from archimg.cc and filtered by
  top-crop brightness so bar text stays legible), plus the `catppuccin`,
  `transparent`, and `ultradark` theme sets referenced by
  `hypr/themes/hyprpaper/*/hyprpaper.conf`.

## Notes

- Display manager is SDDM; the login theme itself (`ml4w` SilentSDDM fork)
  lives in `/usr/share/sddm/themes/` and isn't tracked here since it's
  system-owned, not a user dotfile.
- Not included: downloaded wallpaper assets, and anything holding
  credentials (e.g. `gcalcli`'s OAuth config).
