#!/bin/bash
# =============================================================================
# wifi-status.sh — Waybar custom module for WiFi status
# Outputs JSON for waybar custom module with icon, SSID, signal strength
# =============================================================================

set -euo pipefail

# Get wifi info from nmcli
wifi_info=$(nmcli -t -f active,ssid,signal dev wifi |
  awk -F: '$1=="yes"{print $2"|"$3}' | head -1 || true)

if [[ -z "$wifi_info" ]]; then
  # Not connected
  printf '{"text": "󰤭 ", "tooltip": "WiFi disconnected", "class": "disconnected"}\n'
  exit 0
fi

ssid="${wifi_info%%|*}"
signal="${wifi_info##*|}"

# Pick icon based on signal strength
if [[ "$signal" -ge 75 ]]; then
  icon="󰤨"
elif [[ "$signal" -ge 50 ]]; then
  icon="󰤥"
elif [[ "$signal" -ge 25 ]]; then
  icon="󰤢"
else
  icon="󰤟"
fi

printf '{"text": "%s %s", "tooltip": "%s  %d%%", "class": "connected"}\n' \
  "$icon" "$ssid" "$ssid" "$signal"
