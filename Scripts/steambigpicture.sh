#!/bin/bash

TARGET_CLASS="steam"
TARGET_TITLE="Big Picture"

echo "[steam-fullscreen] Script started. Waiting for Steam Big Picture focus..."

while true; do
    hyprctl --batch 'sub focus' | while read -r _; do
        FOCUSED_WINDOW=$(hyprctl activewindow -j)

        CLASS=$(echo "$FOCUSED_WINDOW" | jq -r '.class')
        TITLE=$(echo "$FOCUSED_WINDOW" | jq -r '.title')
        ADDRESS=$(echo "$FOCUSED_WINDOW" | jq -r '.address')

        echo "[steam-fullscreen] Focus changed: class='$CLASS', title='$TITLE'"

        if [[ "$CLASS" =~ $TARGET_CLASS ]] && [[ "$TITLE" =~ $TARGET_TITLE ]]; then
            echo "[steam-fullscreen] Matching Big Picture window found at $ADDRESS — fullscreening."
            hyprctl dispatch fullscreen, address:$ADDRESS
        fi
    done

    echo "[steam-fullscreen] hyprctl subscription ended. Restarting in 1s..."
    sleep 1
done
