#!/bin/bash

# --- Configuration ---
# The full command to launch Gamescope with Steam.
# Ensure 'prime-run' is correct for your setup if you use NVIDIA Optimus/Prime.
GAMESCOPE_LAUNCH_CMD="env SDL_VIDEODRIVER=x11 prime-run gamescope -f -e -w 1920 -h 1080 -r 165 --backend sdl --force-grab-cursor --mangoapp -- steam-native -gamepadui"

# The regular expression pattern to find in Steam's logs.
# It captures the following groups:
# 1: Time (e.g., 1750763264.528895)
# 2: Sender ID (e.g., 1.11)
# 3: Destination ID (e.g., 1.1422)
# 4: Serial (e.g., 46)
# 5: Reply Serial (e.g., 2)
# The '\' before '.' and '+' are essential for correct regex matching in bash.
LOG_PATTERN="method return time=(\\d+\\.\\d+) sender=:(\\d+\\.\\d+) -> destination=:(\\d+\\.\\d+) serial=(\\d+) reply_serial=(\\d+)"

# --- Internal Variables (Do not modify) ---
LAST_TIME=""
LAST_SENDER_ID=""
LAST_DESTINATION_ID=""
LAST_SERIAL=""
LAST_REPLY_SERIAL=""
FIRST_MATCH=true # Flag to identify the first time the pattern is seen

# --- Script Logic ---

echo "Starting Gamescope with Steam..."
echo "Command: $GAMESCOPE_LAUNCH_CMD"

# Use `coproc` to run the gamescope command in the background and capture its stdout and stderr.
# `2>&1` redirects stderr (where many Steam/Gamescope logs go) to stdout.
# The output will be piped into the `while read` loop via the file descriptor "${COPROC[0]}".
coproc ($GAMESCOPE_LAUNCH_CMD 2>&1)

# Get the PID of the gamescope process launched by coproc.
# This PID refers to the shell's process that runs the `GAMESCOPE_LAUNCH_CMD`.
# We will use this PID to terminate the gamescope process.
GAMESCOPE_PROCESS_PID=$!

echo "Gamescope launched with PID: $GAMESCOPE_PROCESS_PID (this is the shell wrapper PID, not necessarily gamescope itself)"

# Give Gamescope a moment to start and establish its process.
# We'll also loop to check for the 'gamescope' process explicitly.
GAMESCOPE_FOUND=false
for i in {1..10}; do # Check for up to 10 seconds (10 * 1-second sleeps)
  if pgrep -x gamescope >/dev/null; then
    echo "Gamescope process detected after $((i - 1)) seconds."
    GAMESCOPE_FOUND=true
    break
  else
    echo "Waiting for gamescope process to appear... (attempt $i)"
    sleep 1
  fi
done

# If gamescope still isn't found after the loop, it's likely a launch failure.
if ! $GAMESCOPE_FOUND; then
  echo "Error: 'gamescope' process not found after multiple attempts."
  echo "Please check your '$GAMESCOPE_LAUNCH_CMD' command and ensure Gamescope is installed and working."
  # Attempt to kill the coproc subshell if gamescope itself didn't start but the subshell is stuck.
  kill "$GAMESCOPE_PROCESS_PID" 2>/dev/null
  exit 1
fi
echo "Gamescope appears to be running. Monitoring logs for pattern changes..."
echo "Monitoring pattern: '$LOG_PATTERN'"

# Loop indefinitely, reading output line by line from the coprocess.
# `IFS= read -r line` ensures lines are read raw, preserving spaces and backslashes.
# `<&"${COPROC[0]}"` reads from the coprocess's output file descriptor.
while IFS= read -r line <&"${COPROC[0]}"; do
  # Print the current log line for debugging (you can comment this out later)
  # echo "[LOG]: $line"

  # Check if the gamescope process is still alive.
  # This is important for the script to exit gracefully if Steam/Gamescope is closed normally.
  if ! pgrep -x gamescope >/dev/null; then
    echo "Gamescope process exited normally. Stopping log monitoring."
    break # Exit the while loop
  fi

  # Check if the current line matches our defined pattern using bash's regex matching.
  # `[[ "$line" =~ $LOG_PATTERN ]]` performs the regex match.
  # Captured groups are stored in the BASH_REMATCH array (BASH_REMATCH[0] is the whole match, [1] is the first group, etc.).
  if [[ "$line" =~ $LOG_PATTERN ]]; then
    current_time="${BASH_REMATCH[1]}"
    current_sender_id="${BASH_REMATCH[2]}"
    current_destination_id="${BASH_REMATCH[3]}"
    current_serial="${BASH_REMATCH[4]}"
    current_reply_serial="${BASH_REMATCH[5]}"

    echo "--- Pattern Match Found ---"
    echo "  Time:           $current_time"
    echo "  Sender ID:      $current_sender_id"
    echo "  Destination ID: $current_destination_id"
    echo "  Serial:         $current_serial"
    echo "  Reply Serial:   $current_reply_serial"

    # If this is the first time we've matched the pattern, store the values as our baseline.
    if $FIRST_MATCH; then
      LAST_TIME="$current_time"
      LAST_SENDER_ID="$current_sender_id"
      LAST_DESTINATION_ID="$current_destination_id"
      LAST_SERIAL="$current_serial"
      LAST_REPLY_SERIAL="$current_reply_serial"
      FIRST_MATCH=false
      echo "Baseline pattern recorded. Monitoring for changes..."
    else
      # If not the first match, compare current values with the stored baseline.
      if [[ "$current_time" != "$LAST_TIME" ||
        "$current_sender_id" != "$LAST_SENDER_ID" ||
        "$current_destination_id" != "$LAST_DESTINATION_ID" ||
        "$current_serial" != "$LAST_SERIAL" ||
        "$current_reply_serial" != "$LAST_REPLY_SERIAL" ]]; then
        echo "!!! DETECTED CHANGE IN NUMBERS !!!"
        echo "Current: Time=$current_time, Sender=$current_sender_id, Dest=$current_destination_id, Serial=$current_serial, Reply=$current_reply_serial"
        echo "Last:    Time=$LAST_TIME, Sender=$LAST_SENDER_ID, Dest=$LAST_DESTINATION_ID, Serial=$LAST_SERIAL, Reply=$LAST_REPLY_SERIAL"
        echo "Attempting to close Gamescope now by killing its launching process..."

        # Use `kill` with the PID of the coproc subshell.
        # This sends a SIGTERM signal, which should tell Gamescope to shut down.
        kill "$GAMESCOPE_PROCESS_PID"

        echo "Gamescope kill command issued."
        break # Exit the loop after attempting to kill Gamescope.
      else
        echo "Numbers are consistent. Continuing monitoring."
      fi
    fi
  fi
done

echo "Script finished."

# Wait for the background Gamescope process (which was launched by coproc) to fully terminate.
# `wait` will wait for the PID to exit. `2>/dev/null` suppresses "No such process" errors if it's already gone.
wait "$GAMESCOPE_PROCESS_PID" 2>/dev/null

echo "Monitor script terminated."
