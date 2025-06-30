#!/bin/bash

# Enhanced Network Module for Ironbar
# Provides comprehensive network monitoring with bandwidth, connection status, and IP info

# Configuration
INTERFACE="" # Leave empty for auto-detection, or specify like "wlan0" or "eth0"
UPDATE_INTERVAL=2
CACHE_DIR="/tmp/ironbar-network"
CACHE_FILE="$CACHE_DIR/network_cache"
BANDWIDTH_FILE="$CACHE_DIR/bandwidth"

# Display format options (can be overridden by environment variables)
SHOW_SSID="${SHOW_SSID:-false}"                    # Show WiFi SSID in main text
SHOW_BANDWIDTH="${SHOW_BANDWIDTH:-false}"          # Show bandwidth speeds
SHOW_IP="${SHOW_IP:-false}"                        # Show IP in main text
COMPACT_MODE="${COMPACT_MODE:-true}"               # Use compact format
BANDWIDTH_THRESHOLD="${BANDWIDTH_THRESHOLD:-1024}" # Minimum bytes/s to show bandwidth

# Create cache directory
mkdir -p "$CACHE_DIR"

# Colors and icons (Nerd Font compatible)
WIFI_ICONS=("󰤯" "󰤟" "󰤢" "󰤥" "󰤨") # Signal strength icons
ETH_ICON="󰈀"
DISCONNECTED_ICON="󰤮"

# Initialize bandwidth tracking
init_bandwidth_tracking() {
  local interface="$1"
  local rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo 0)
  local tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo 0)
  local timestamp=$(date +%s)

  echo "$timestamp $rx_bytes $tx_bytes" >"$BANDWIDTH_FILE"
}

# Calculate bandwidth
calculate_bandwidth() {
  local interface="$1"
  local current_rx=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo 0)
  local current_tx=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo 0)
  local current_time=$(date +%s)

  if [[ -f "$BANDWIDTH_FILE" ]]; then
    local prev_data=$(cat "$BANDWIDTH_FILE")
    local prev_time=$(echo "$prev_data" | cut -d' ' -f1)
    local prev_rx=$(echo "$prev_data" | cut -d' ' -f2)
    local prev_tx=$(echo "$prev_data" | cut -d' ' -f3)

    local time_diff=$((current_time - prev_time))

    if [[ $time_diff -gt 0 ]]; then
      local rx_diff=$((current_rx - prev_rx))
      local tx_diff=$((current_tx - prev_tx))

      local rx_rate=$((rx_diff / time_diff))
      local tx_rate=$((tx_diff / time_diff))

      echo "$rx_rate $tx_rate"
    else
      echo "0 0"
    fi
  else
    echo "0 0"
  fi

  # Update cache
  echo "$current_time $current_rx $current_tx" >"$BANDWIDTH_FILE"
}

# Format bytes to human readable
format_bytes() {
  local bytes=$1
  local units=("B" "K" "M" "G" "T")
  local unit=0

  while [[ $bytes -gt 1024 && $unit -lt 4 ]]; do
    bytes=$((bytes / 1024))
    ((unit++))
  done

  echo "${bytes}${units[$unit]}"
}

# Get primary network interface
get_primary_interface() {
  if [[ -n "$INTERFACE" ]]; then
    echo "$INTERFACE"
    return
  fi

  # Try to find the active interface with a default route
  local interface=$(ip route | grep '^default' | head -1 | sed 's/.*dev \([^ ]*\).*/\1/')

  if [[ -n "$interface" ]]; then
    echo "$interface"
  else
    # Fallback to first non-loopback interface that's up
    ip link show | grep -E '^[0-9]+:' | grep -v 'lo:' | grep 'state UP' | head -1 | sed 's/.*: \([^:]*\):.*/\1/'
  fi
}

# Get connection type
get_connection_type() {
  local interface="$1"

  if [[ -d "/sys/class/net/$interface/wireless" ]]; then
    echo "wifi"
  elif [[ -d "/sys/class/net/$interface/device" ]]; then
    echo "ethernet"
  else
    echo "unknown"
  fi
}

# Get WiFi signal strength
get_wifi_strength() {
  local interface="$1"

  if [[ -f "/proc/net/wireless" ]]; then
    local signal=$(grep "$interface" /proc/net/wireless | awk '{print $4}' | sed 's/\.//')
    if [[ -n "$signal" ]]; then
      # Convert to percentage (assuming -100 to -50 dBm range)
      local strength=$(((signal + 100) * 2))
      [[ $strength -lt 0 ]] && strength=0
      [[ $strength -gt 100 ]] && strength=100
      echo "$strength"
    fi
  fi
}

# Get IP address
get_ip_address() {
  local interface="$1"
  ip addr show "$interface" 2>/dev/null | grep 'inet ' | head -1 | awk '{print $2}' | cut -d'/' -f1
}

# Get WiFi SSID
get_wifi_ssid() {
  local interface="$1"
  if command -v iwgetid >/dev/null 2>&1; then
    iwgetid -r "$interface" 2>/dev/null
  elif command -v nmcli >/dev/null 2>&1; then
    nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2
  fi
}

# Check internet connectivity
check_internet() {
  ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1
}

# Main function
main() {
  local interface=$(get_primary_interface)

  if [[ -z "$interface" ]]; then
    if [[ "${OUTPUT_FORMAT:-}" == "json" ]]; then
      echo "{\"text\": \"$DISCONNECTED_ICON\", \"tooltip\": \"No network interface found\"}"
    else
      echo "$DISCONNECTED_ICON"
    fi
    return
  fi

  # Check if interface is up
  if ! ip link show "$interface" 2>/dev/null | grep -q "state UP"; then
    if [[ "${OUTPUT_FORMAT:-}" == "json" ]]; then
      echo "{\"text\": \"$DISCONNECTED_ICON\", \"tooltip\": \"Interface $interface is down\"}"
    else
      echo "$DISCONNECTED_ICON"
    fi
    return
  fi

  local connection_type=$(get_connection_type "$interface")
  local ip_address=$(get_ip_address "$interface")
  local icon="$ETH_ICON"
  local status_text=""
  local tooltip="Interface: $interface\\nType: $connection_type"

  # Set icon based on connection type
  if [[ "$connection_type" == "wifi" ]]; then
    local strength=$(get_wifi_strength "$interface")
    if [[ -n "$strength" ]]; then
      if [[ $strength -ge 80 ]]; then
        icon="${WIFI_ICONS[4]}"
      elif [[ $strength -ge 60 ]]; then
        icon="${WIFI_ICONS[3]}"
      elif [[ $strength -ge 40 ]]; then
        icon="${WIFI_ICONS[2]}"
      elif [[ $strength -ge 20 ]]; then
        icon="${WIFI_ICONS[1]}"
      else
        icon="${WIFI_ICONS[0]}"
      fi
    else
      icon="${WIFI_ICONS[2]}" # Default to medium strength
    fi

    local ssid=$(get_wifi_ssid "$interface")
    if [[ -n "$ssid" ]]; then
      status_text="$ssid"
      tooltip="$tooltip\\nSSID: $ssid"
    fi

    if [[ -n "$strength" ]]; then
      tooltip="$tooltip\\nSignal: ${strength}%"
    fi
  fi

  # Add IP address info
  if [[ -n "$ip_address" ]]; then
    tooltip="$tooltip\\nIP: $ip_address"
  else
    tooltip="$tooltip\\nIP: Not assigned"
  fi

  # Calculate bandwidth
  local bandwidth=$(calculate_bandwidth "$interface")
  local rx_rate=$(echo "$bandwidth" | cut -d' ' -f1)
  local tx_rate=$(echo "$bandwidth" | cut -d' ' -f2)

  local rx_formatted=$(format_bytes "$rx_rate")
  local tx_formatted=$(format_bytes "$tx_rate")

  # Build display text - customizable format
  local display_text="$icon"

  # Add SSID if requested and available
  if [[ "$SHOW_SSID" == "true" && "$connection_type" == "wifi" && -n "$status_text" ]]; then
    display_text="$display_text $status_text"
  fi

  # Add IP if requested
  if [[ "$SHOW_IP" == "true" && -n "$ip_address" ]]; then
    display_text="$display_text $ip_address"
  fi

  # Add bandwidth info based on settings
  if [[ "$SHOW_BANDWIDTH" == "true" && ($rx_rate -gt $BANDWIDTH_THRESHOLD || $tx_rate -gt $BANDWIDTH_THRESHOLD) ]]; then
    if [[ "$COMPACT_MODE" == "true" ]]; then
      display_text="$display_text ${rx_formatted}↓ ${tx_formatted}↑"
    else
      display_text="$display_text ↓${rx_formatted}/s ↑${tx_formatted}/s"
    fi
  fi

  tooltip="$tooltip\\nDownload: ${rx_formatted}/s\\nUpload: ${tx_formatted}/s"

  # Output for Ironbar - check if JSON mode is requested
  if [[ "${OUTPUT_FORMAT:-}" == "json" ]]; then
    echo "{\"text\": \"$display_text\", \"tooltip\": \"$tooltip\"}"
  else
    # Plain text output (default)
    echo "$display_text"
  fi
}

# Handle signals for cleanup
cleanup() {
  rm -f "$BANDWIDTH_FILE"
  exit 0
}

trap cleanup SIGTERM SIGINT

# Initialize bandwidth tracking on first run
interface=$(get_primary_interface)
if [[ -n "$interface" && ! -f "$BANDWIDTH_FILE" ]]; then
  init_bandwidth_tracking "$interface"
fi

# Run based on arguments
case "${1:-}" in
--loop)
  while true; do
    main
    sleep "$UPDATE_INTERVAL"
  done
  ;;
--init)
  interface=$(get_primary_interface)
  [[ -n "$interface" ]] && init_bandwidth_tracking "$interface"
  ;;
*)
  main
  ;;
esac
