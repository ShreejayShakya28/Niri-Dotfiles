#!/bin/bash
# =============================================================================
# mic-status.sh — Waybar custom module for microphone status
# Outputs JSON: icon changes based on mute state
# =============================================================================
set -euo pipefail

# Get default source mute status
muted=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null |
  awk '{print $2}' || echo "yes")

# Get default source description (friendly name)
default_source=$(pactl get-default-source 2>/dev/null || echo "")
desc=""
if [[ -n "$default_source" ]]; then
  desc=$(pactl list sources |
    awk "/Name: $default_source/{found=1} found && /Description:/{print; exit}" |
    sed 's/.*Description: //' || echo "$default_source")
fi

if [[ "$muted" == "yes" ]]; then
  printf '{"text": "󰍭", "tooltip": "Mic muted: %s", "class": "muted"}\n' \
    "$desc"
else
  printf '{"text": "󰍬", "tooltip": "Mic active: %s", "class": "active"}\n' \
    "$desc"
fi
