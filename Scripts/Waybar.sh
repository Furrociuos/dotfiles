#!/usr/bin/env bash

VISIBLE_WINDOW_COUNT=0
WAYBAR_VISIBLE=1

toggle_waybar() {
    pkill -SIGUSR2 waybar
    WAYBAR_VISIBLE=$((1 - WAYBAR_VISIBLE))
    echo "Toggled Waybar. Now visible: $WAYBAR_VISIBLE"
}

cleanup() {
    if [ "$WAYBAR_VISIBLE" -eq 0 ]; then
        pkill -SIGUSR2 waybar
    fi
    echo "Cleaning up. Forcing Waybar visible."
    exit 0
}
trap cleanup SIGINT SIGTERM

niri msg event-stream | while read -r line; do
    if [[ "$line" == "Window opened or changed:"* ]]; then
        ((VISIBLE_WINDOW_COUNT++))
        echo "Window opened. Count: $VISIBLE_WINDOW_COUNT"
    elif [[ "$line" == "Window closed:"* ]]; then
        ((VISIBLE_WINDOW_COUNT--))
        ((VISIBLE_WINDOW_COUNT < 0)) && VISIBLE_WINDOW_COUNT=0
        echo "Window closed. Count: $VISIBLE_WINDOW_COUNT"
    fi

    if ((VISIBLE_WINDOW_COUNT > 0)) && [ "$WAYBAR_VISIBLE" -eq 1 ]; then
        toggle_waybar  # Hide
    elif ((VISIBLE_WINDOW_COUNT == 0)) && [ "$WAYBAR_VISIBLE" -eq 0 ]; then
        toggle_waybar  # Show
    fi
done

