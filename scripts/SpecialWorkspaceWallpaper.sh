#!/usr/bin/env bash
set -euo pipefail

# Select and display a wallpaper in a Hyprland special workspace. Unlike awww
# or swww, the mpv window belongs to the special workspace only.
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
SCRIPT_DIR="$CONFIG_DIR/scripts"
STATE_DIR="$CONFIG_DIR/special_wallpapers"
WALLPAPER_DIR="$(xdg-user-dir PICTURES 2>/dev/null || printf '%s' "$HOME/Pictures")/wallpapers"

mkdir -p "$STATE_DIR"

select_workspace() {
  printf '%s\n' all special secondary tertiary |
    rofi -dmenu -i -p 'Special workspace' -matching fuzzy
}

select_wallpaper() {
  find -L "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) -print0 |
    while IFS= read -r -d '' image; do
      printf '%s\x00icon\x1f%s\n' "$(basename "$image")" "$image"
    done | rofi -dmenu -i -p 'Special wallpaper' -show-icons -matching fuzzy
}

start_wallpaper() {
  local workspace="$1" image="$2" title="HyprSpecialWallpaper:$workspace"
  pkill -f -- "$title" 2>/dev/null || true
  local command
  printf -v command 'mpv --no-audio --no-osc --no-osd-bar --force-window=immediate --image-display-duration=inf --loop-file=inf --keep-open=yes --title=%q --class=special-wallpaper-%q --fullscreen %q' "$title" "$workspace" "$image"
  hyprctl dispatch exec "[workspace special:$workspace silent] $command" >/dev/null
}

choose() {
  local workspace image selected
  workspace="$(select_workspace)"; [ -n "$workspace" ] || exit 0
  image="$(select_wallpaper)"; [ -n "$image" ] || exit 0
  selected="$(find -L "$WALLPAPER_DIR" -type f -name "$image" -print -quit)"
  [ -f "$selected" ] || exit 1

  if [ "$workspace" = all ]; then
    printf '%s\n' "$selected" > "$STATE_DIR/special"
    printf '%s\n' "$selected" > "$STATE_DIR/secondary"
    printf '%s\n' "$selected" > "$STATE_DIR/tertiary"
    start_wallpaper special "$selected"
    start_wallpaper secondary "$selected"
    start_wallpaper tertiary "$selected"
  else
    printf '%s\n' "$selected" > "$STATE_DIR/$workspace"
    start_wallpaper "$workspace" "$selected"
  fi
}

restore() {
  local workspace image_file image
  for workspace in special secondary tertiary; do
    image_file="$STATE_DIR/$workspace"
    if [ -f "$image_file" ]; then
      image="$(<"$image_file")"
      [ -f "$image" ] && start_wallpaper "$workspace" "$image"
    fi
  done
}

case "${1:-select}" in
  select) choose ;;
  restore) restore ;;
  *) printf 'Usage: %s [select|restore]\n' "$0" >&2; exit 2 ;;
esac
