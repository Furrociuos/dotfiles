#!/bin/bash

eww_overview_bar="overview-bar-name" # Name of your Eww window for the overview

# Start by ensuring the bar is closed
niri msg --json event-stream | while read -r line; do
  # Parse the JSON line to check for overview events
  # This is simplified; you'd use a tool like jq for robust parsing
  if echo "$line" | grep -q '{"OverviewOpenedOrClosed":{"is_open":true}}'; then
    echo "Overview activated, opening Eww bar..."
    pkill -SIGUSR1 waybar && eww open $eww_overview_bar  
  elif echo "$line" | grep -q '{"OverviewOpenedOrClosed":{"is_open":false}}'; then
    echo "Overview deactivated, closing Eww bar..."
    pkill -SIGUSR1 waybar && eww close $eww_overview_bar 
  fi
done
