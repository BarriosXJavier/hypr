#!/usr/bin/env bash

set -u

SPECIAL_WS="special:scratchpad"
BROWSER_CLASS_PATTERN='^brave-.*-Default$'

STATE_FILE="/tmp/nvim-docs-state"
ADDR_FILE="/tmp/nvim-docs-address"

clients() {
    hyprctl clients -j 2>/dev/null
}

valid_address() {
    local addr="${1:-}"

    [[ -n "$addr" ]] || return 1

    clients |
        jq -e \
            --arg addr "$addr" \
            --arg pattern "$BROWSER_CLASS_PATTERN" '
            any(.[]?;
                .address == $addr and
                (.class // "" | test($pattern; "i"))
            )
        ' >/dev/null
}

stored_address() {
    local addr

    addr="$(cat "$ADDR_FILE" 2>/dev/null || true)"

    if valid_address "$addr"; then
        printf '%s' "$addr"
    else
        rm -f "$ADDR_FILE"
    fi
}

current_workspace() {
    hyprctl activeworkspace -j 2>/dev/null |
        jq -r '.id // empty'
}

move_to_workspace() {
    local workspace="$1"
    local addr="$2"

    hyprctl dispatch movetoworkspacesilent \
        "$workspace,address:$addr" >/dev/null
}

find_new_browser() {
    local before="$1"

    clients |
        jq -r \
            --argjson before "$(jq -c '[.[].address]' <<< "$before")" \
            --arg pattern "$BROWSER_CLASS_PATTERN" '
            [
                .[]
                | select(
                    (.class // "") | test($pattern; "i")
                )
                | select(
                    .address as $addr
                    | ($before | index($addr))
                    | not
                )
                | .address
            ][0] // empty
        '
}

show() {
    local addr="$1"
    local workspace

    workspace="$(current_workspace)"

    [[ "$workspace" =~ ^-?[0-9]+$ ]] || return 1
    valid_address "$addr" || return 1

    move_to_workspace "$workspace" "$addr"

    echo shown > "$STATE_FILE"
}

hide() {
    local addr="$1"

    if ! valid_address "$addr"; then
        rm -f "$ADDR_FILE"
        echo hidden > "$STATE_FILE"
        return 0
    fi

    move_to_workspace "$SPECIAL_WS" "$addr"

    echo hidden > "$STATE_FILE"
}

create_browser() {
    local url="$1"
    local before
    local addr=""

    before="$(clients)"

    brave-browser \
        --user-data-dir="$HOME/.config/brave/nvim-docs" \
        --new-window \
        --app="$url" \
        --no-first-run \
        --no-default-browser-check \
        >/dev/null 2>&1 &

    for _ in {1..50}; do
        addr="$(find_new_browser "$before")"

        if [[ -n "$addr" ]]; then
            break
        fi

        sleep 0.1
    done

    [[ -n "$addr" ]] || return 1

    printf '%s' "$addr" > "$ADDR_FILE"

    printf '%s' "$addr"
}

close_browser() {
    local addr="$1"

    if valid_address "$addr"; then
        hyprctl dispatch closewindow \
            "address:$addr" >/dev/null 2>&1 || true
    fi

    rm -f "$ADDR_FILE"
    echo hidden > "$STATE_FILE"
}

notify_failure() {
    notify-send \
        -u normal \
        "Nvim docs" \
        "$1" \
        2>/dev/null || true
}


# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

addr="$(stored_address)"
url="${1:-}"

# No URL: toggle existing popup.
if [[ -z "$url" ]]; then
    [[ -n "$addr" ]] || exit 0

    state="$(cat "$STATE_FILE" 2>/dev/null || true)"

    if [[ "$state" == "shown" ]]; then
        hide "$addr"
    else
        show "$addr"
    fi

    exit 0
fi


# URL supplied: create a new app window.
old_addr="$addr"

addr="$(create_browser "$url")" || {
    notify_failure "Could not find the new Brave window"
    exit 1
}

# Only destroy the old popup after the new one was
# successfully detected.
if [[ -n "$old_addr" ]]; then
    close_browser "$old_addr"
fi

show "$addr"
