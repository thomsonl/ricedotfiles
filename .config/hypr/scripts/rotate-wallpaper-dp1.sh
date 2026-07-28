#!/bin/sh
# Picks a random image from the dark-topped archimg pool and sets it as the
# DP-1 (Dell) wallpaper. Run once per Hyprland session start (login).
#
# hyprpaper is started asynchronously in the same autostart batch, so its
# IPC socket may not exist yet -- poll for it instead of racing it.

POOL="$HOME/.config/wallpapers/archimg-dark"
SOCK_GLOB="$XDG_RUNTIME_DIR/hypr/*/.hyprpaper.sock"

for _ in $(seq 1 50); do
    # shellcheck disable=SC2086
    [ -S $SOCK_GLOB ] 2>/dev/null && break
    sleep 0.2
done

image=$(find "$POOL" -maxdepth 1 -type f | shuf -n 1)
[ -z "$image" ] && exit 0

hyprctl hyprpaper wallpaper "DP-1,$image"

# Tint the hyprtasking overview backdrop to match the wallpaper just picked.
# hyprtasking only supports a solid colour, so average the image down to one
# pixel and darken it, otherwise the workspace thumbnails wash out against it.
# `hyprctl keyword` does not work on a Lua config -- it must go through eval.
tint=$(magick "$image" -resize 1x1! -modulate 55 -colorspace sRGB \
           -format "%[hex:p{0,0}]" info: 2>/dev/null)

if [ -n "$tint" ]; then
    # The plugin loads via `hyprpm reload` in the same autostart batch, so it
    # may not be registered yet. Retry briefly, then give up quietly -- the
    # fallback bg_color in hyprland.lua is perfectly usable on its own.
    for _ in $(seq 1 25); do
        if hyprctl plugin list 2>/dev/null | grep -qi hyprtasking; then
            hyprctl eval \
                "hl.config({ plugin = { hyprtasking = { bg_color = 0xff${tint} } } })" \
                >/dev/null 2>&1
            break
        fi
        sleep 0.2
    done
fi
