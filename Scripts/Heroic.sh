#!/bin/bash

# Function to check if a process is running
is_running() {
  pgrep -x "$1" >/dev/null
}

# Close Steam if it's running
if is_running "steam"; then
  echo "Closing Steam..."
  pkill -x steam
fi

# Launch Heroic Games Launcher
echo "Launching Heroic Games Launcher..."
heroic &

# Get the PID of the last process run in background
HEROIC_PID=$!

# Wait for Heroic to close
echo "Waiting for Heroic to close..."
wait $HEROIC_PID

# Re-launch Steam silently
echo "Re-launching Steam with -silent option..."
steam-native -silent &
