#!/bin/sh
# Sets the fixed portrait wallpaper for DP-2 (BenQ, rotated to portrait).
#
# hyprpaper's config-driven `wallpaper =` lines don't reliably take effect on
# this system (reproduced: even a minimal config with absolute paths leaves
# DP-2 with "no target"), so set it explicitly via IPC once hyprpaper's
# socket is up -- same pattern as rotate-wallpaper-dp1.sh.

IMAGE="$HOME/.config/wallpapers/transparent/bgr2.png"
SOCK_GLOB="$XDG_RUNTIME_DIR/hypr/*/.hyprpaper.sock"

for _ in $(seq 1 50); do
    # shellcheck disable=SC2086
    [ -S $SOCK_GLOB ] 2>/dev/null && break
    sleep 0.2
done

hyprctl hyprpaper preload "$IMAGE"
hyprctl hyprpaper wallpaper "DP-2,$IMAGE"
