#!/usr/bin/env bash
# Toggle the active window between a special workspace and its regular one.

set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_HOME/hypr"
if [[ -f "$HYPR_DIR/hyprland.lua" || -f "$CONFIG_HOME/hyprland.lua" ]]; then
  HYPR_CONFIG_MODE="lua"
else
  HYPR_CONFIG_MODE="conf"
fi

special_name="${1:-special}"
case "$special_name" in
  special) ;;
  special:*) ;;
  "") special_name="special" ;;
  *) special_name="special:${special_name}" ;;
esac

active_window="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
window_workspace_id="$(jq -r '.workspace.id // empty' <<<"$active_window")"

# Raw string dispatchers are rejected by the Lua config build
# ("hl.dispatch: expected a dispatcher"); use the Lua dispatcher API there.
move_window_to() {
  local target="$1"
  if [[ "$HYPR_CONFIG_MODE" == "lua" ]]; then
    if [[ "$target" =~ ^-?[0-9]+$ ]]; then
      hyprctl dispatch "hl.dsp.window.move({ workspace = ${target} })" >/dev/null 2>&1 || true
    else
      hyprctl dispatch "hl.dsp.window.move({ workspace = '${target}' })" >/dev/null 2>&1 || true
    fi
  else
    hyprctl dispatch movetoworkspace "$target" >/dev/null 2>&1 || true
  fi
}

# A negative workspace id always identifies a special workspace, which is
# more reliable than name matching (the unnamed special reports the same
# "special:special" name as identically named specials).
if [[ "$window_workspace_id" =~ ^-[0-9]+$ ]]; then
  monitor_id="$(jq -r '.monitor // empty' <<<"$active_window")"
  normal_workspace="$(hyprctl monitors -j 2>/dev/null |
    jq -r --argjson monitor_id "$monitor_id" \
      '.[] | select(.id == $monitor_id) | .activeWorkspace.id // empty' |
    head -n 1)"

  if [[ "$normal_workspace" =~ ^[0-9]+$ ]]; then
    move_window_to "$normal_workspace"
  fi
else
  move_window_to "$special_name"
fi
