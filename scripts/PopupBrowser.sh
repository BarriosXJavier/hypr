#!/usr/bin/env bash
set -u

SPECIAL_WS="special:scratchpad"
WIDTH_PERCENT=65
HEIGHT_PERCENT=65
Y_PERCENT=10
STATE_FILE="/tmp/popup_browser_state"
ADDR_FILE="/tmp/popup_browser_addr"

clients() { hyprctl clients -j 2>/dev/null; }
valid_address() {
  local addr="${1:-}"
  [[ -n "$addr" ]] && clients | jq -e --arg addr "$addr" 'any(.[]; .address == $addr)' >/dev/null
}
stored_address() {
  local addr
  addr="$(cat "$ADDR_FILE" 2>/dev/null || true)"
  valid_address "$addr" && printf '%s' "$addr"
}
new_address() {
  local before="$1" after candidate
  after="$(clients)"
  candidate=$(comm -13 <(jq -r '.[].address' <<< "$before" | sort) <(jq -r '.[].address' <<< "$after" | sort) | head -n 1)
  printf '%s' "$candidate"
}
monitor_geometry() {
  hyprctl monitors -j 2>/dev/null | jq -r \
    'map(select(.focused == true)) | .[0] | "\(.x) \(.y) \(.width) \(.height) \(.scale)"'
}
configure_window() {
  local addr="$1" geometry mon_x mon_y mon_w mon_h scale width height x y
  geometry="$(monitor_geometry)"
  read -r mon_x mon_y mon_w mon_h scale <<< "$geometry"
  [[ "$mon_w" =~ ^[0-9]+$ && "$mon_h" =~ ^[0-9]+$ ]] || return 1
  [[ "$scale" =~ ^[0-9]+([.][0-9]+)?$ ]] || scale=1
  width=$(awk -v w="$mon_w" -v s="$scale" -v p="$WIDTH_PERCENT" 'BEGIN { printf "%d", w/s*p/100 }')
  height=$(awk -v h="$mon_h" -v s="$scale" -v p="$HEIGHT_PERCENT" 'BEGIN { printf "%d", h/s*p/100 }')
  x=$((mon_x + (mon_w - width) / 2))
  y=$((mon_y + (mon_h - height) * Y_PERCENT / 100))
  hyprctl dispatch setfloating "address:$addr" >/dev/null
  hyprctl dispatch resizewindowpixel "exact $width $height,address:$addr" >/dev/null
  hyprctl dispatch movewindowpixel "exact $x $y,address:$addr" >/dev/null
  hyprctl dispatch setprop "address:$addr" alpha 0.94 >/dev/null 2>&1 || true
}
show() {
  local addr="$1" current_workspace
  current_workspace="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty')"
  [[ "$current_workspace" =~ ^-?[0-9]+$ ]] || return 1
  hyprctl dispatch movetoworkspacesilent "$current_workspace,address:$addr" >/dev/null
  configure_window "$addr"
  hyprctl dispatch focuswindow "address:$addr" >/dev/null
  echo shown > "$STATE_FILE"
}

addr="$(stored_address)"
url="${1:-}"
if [[ -z "$url" ]]; then
  [[ -n "$addr" ]] || exit 0
  if [[ "$(cat "$STATE_FILE" 2>/dev/null || true)" == shown ]]; then
    hyprctl dispatch movetoworkspacesilent "$SPECIAL_WS,address:$addr" >/dev/null
    echo hidden > "$STATE_FILE"
  else
    show "$addr"
  fi
  exit 0
fi

before="$(clients)"
if [[ -n "$addr" ]]; then
  # One popup only: replace the previous app window with the newly requested URL.
  hyprctl dispatch closewindow "address:$addr" >/dev/null 2>&1 || true
  rm -f "$ADDR_FILE"
  echo hidden > "$STATE_FILE"
fi
before="$(clients)"
brave-browser --new-window --app="$url" >/dev/null 2>&1 &
for _ in {1..40}; do
  addr="$(new_address "$before")"
  [[ -n "$addr" ]] && break
  sleep 0.1
done
if [[ -n "$addr" ]]; then
  echo "$addr" > "$ADDR_FILE"
  hyprctl dispatch movetoworkspacesilent "$SPECIAL_WS,address:$addr" >/dev/null
  show "$addr"
else
  notify-send -u normal "Popup browser" "Could not find the new Brave window" 2>/dev/null || true
fi
