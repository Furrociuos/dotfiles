import subprocess
import json
import signal
import sys
import time

# --- Configuration ---
# Replace 'waybar' with the actual process name if it's different.
# You might need to adjust this based on how you start Waybar.
WAYBAR_PROCESS_NAME = "waybar"
# If Waybar is run as a systemd service (e.g., 'waybar.service'), provide its service name.
# This will make the script use 'systemctl kill' instead of direct 'kill <pid>'.
WAYBAR_SERVICE_NAME = "waybar.service"
# --- End Configuration ---

def is_waybar_service_active():
    """
    Checks if the Waybar systemd service is active.
    Returns True if active, False otherwise.
    """
    try:
        subprocess.run(
            ["systemctl", "is-active", WAYBAR_SERVICE_NAME],
            check=True,
            capture_output=True
        )
        print(f"Waybar service '{WAYBAR_SERVICE_NAME}' is active.")
        return True
    except subprocess.CalledProcessError:
        print(f"Waybar service '{WAYBAR_SERVICE_NAME}' is not active or not found.")
        return False
    except Exception as e:
        print(f"An error occurred while checking Waybar service status: {e}")
        return False

def toggle_waybar_visibility(hide):
    """
    Sends the appropriate SIGUSR signal to Waybar via systemctl to toggle its visibility.
    SIGUSR1 typically hides Waybar, SIGUSR2 shows it.
    """
    sig = signal.SIGUSR1 if hide else signal.SIGUSR2
    action = "hiding" if hide else "showing"
    try:
        print(f"Sending signal {sig.name} to Waybar service '{WAYBAR_SERVICE_NAME}' for {action}.")
        # Use systemctl kill to send the signal to the service
        subprocess.run(
            ["systemctl", "kill", f"--signal={sig.name}", WAYBAR_SERVICE_NAME],
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Error sending signal to Waybar service: {e}")
        print(f"Stderr: {e.stderr}")
    except Exception as e:
        print(f"An unexpected error occurred while toggling Waybar: {e}")

def main():
    """
    Main function to listen to Niri events and toggle Waybar.
    """
    if not is_waybar_service_active():
        print("Waybar service is not active. Exiting.")
        sys.exit(1)

    # State variables
    waybar_hidden = False
    has_visible_windows = False

    print("Starting Niri event stream listener...")
    try:
        # Start the niri event-stream subprocess
        # text=True decodes stdout/stderr as text
        # bufsize=1 (line buffered) is good for streaming output
        process = subprocess.Popen(
            ["niri", "msg", "event-stream"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )

        for line in process.stdout:
            try:
                event = json.loads(line)
                event_type = event.get("type")

                # We are interested in "output_state" and "window_state" events
                # A more robust approach would be to periodically check `niri msg dump-state`
                # or to accumulate window information from events.
                
                # Check for `window_state` events and then re-evaluate.
                if event_type == "window_state" or event_type == "output_state" or event_type == "workspace_focus_changed":
                    # Re-query the full state to be sure
                    dump_state_process = subprocess.run(
                        ["niri", "msg", "dump-state"],
                        capture_output=True,
                        text=True,
                        check=True
                    )
                    niri_state = json.loads(dump_state_process.stdout)
                    
                    current_has_visible_windows = False
                    for output in niri_state.get("outputs", []):
                        # For each output, check if its currently focused workspace has windows
                        focused_workspace_id = output.get("focused_workspace_id")
                        if focused_workspace_id:
                            workspace = niri_state.get("workspaces", {}).get(str(focused_workspace_id))
                            if workspace and workspace.get("windows"):
                                current_has_visible_windows = True
                                break # Found windows on a focused workspace, no need to check further outputs
                        # Also check if any *other* workspace on this output has windows,
                        # in case a window is on a hidden workspace but still exists
                        for ws_id in output.get("workspace_ids", []):
                            workspace = niri_state.get("workspaces", {}).get(str(ws_id))
                            if workspace and workspace.get("windows"):
                                current_has_visible_windows = True
                                break # Found windows on some workspace
                        if current_has_visible_windows:
                            break


                    
                    if current_has_visible_windows and not has_visible_windows:
                        # Windows just became visible
                        print("Detected visible windows. Hiding Waybar.")
                        toggle_waybar_visibility(hide=True)
                        waybar_hidden = True
                        has_visible_windows = True
                    elif not current_has_visible_windows and has_visible_windows:
                        # Windows just became not visible
                        print("No visible windows detected. Showing Waybar.")
                        toggle_waybar_visibility(hide=False)
                        waybar_hidden = False
                        has_visible_windows = False
                    
                    # Initial check if the script starts with windows already open/closed
                    # This block ensures Waybar's state is correct on script startup
                    elif not current_has_visible_windows and waybar_hidden:
                        # If no windows are visible on startup and Waybar is currently hidden, show it.
                        print("Initial state correction: No visible windows, Waybar was hidden. Showing Waybar.")
                        toggle_waybar_visibility(hide=False)
                        waybar_hidden = False
                        has_visible_windows = False
                    elif current_has_visible_windows and not waybar_hidden:
                        # If windows are visible on startup and Waybar is currently shown, hide it.
                        print("Initial state correction: Visible windows, Waybar was shown. Hiding Waybar.")
                        toggle_waybar_visibility(hide=True)
                        waybar_hidden = True
                        has_visible_windows = True

            except json.JSONDecodeError:
                print(f"Could not parse JSON: {line.strip()}")
            except Exception as e:
                print(f"An error occurred while processing event: {e}")

    except FileNotFoundError:
        print("Error: 'niri' command not found. Please ensure Niri is installed and in your PATH.")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error running 'niri msg event-stream': {e}")
        print(f"Stderr: {e.stderr}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nExiting listener.")
    finally:
        if 'process' in locals() and process.poll() is None: # Check if process was successfully started and is running
            process.terminate()
            process.wait()
        print("Niri event stream listener stopped.")

if __name__ == "__main__":
    main()

