#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# Toggle move active window to/from a special workspace,
# restoring the exact workspace the window came from.
# Usage: ./Toggle-Move-Special.sh [special_name]
#   special_name defaults to "special:special"
#   e.g. "special:special", "special:secondary", "special:tertiary"

name="${1:-special:special}"

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hypr"
STATE_FILE="$STATE_DIR/special_origin"
mkdir -p "$STATE_DIR"
touch "$STATE_FILE"

win_json="$(hyprctl activewindow -j)"
ws="$(jq -r '.workspace.name // empty' <<<"$win_json")"
ws_id="$(jq -r '.workspace.id // empty' <<<"$win_json")"
addr="$(jq -r '.address // empty' <<<"$win_json")"

if [[ "$ws" == "$name" ]]; then
  origin="$(awk -v a="$addr" '$1 == a {print $3; exit}' "$STATE_FILE")"
  if [[ -n "$origin" ]]; then
    hyprctl dispatch movetoworkspace "$origin"
  else
    hyprctl dispatch movetoworkspace previous
  fi
  sed -i "/^$addr /d" "$STATE_FILE"
  exit 0
fi

# moving in: remember where this window came from
sed -i "/^$addr /d" "$STATE_FILE"
echo "$addr $ws_id $ws" >> "$STATE_FILE"
hyprctl dispatch movetoworkspace "$name"
