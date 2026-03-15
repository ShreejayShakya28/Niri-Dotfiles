#!/bin/bash
# =============================================================================
# audio-input-menu.sh — Select audio input device via fuzzel
# =============================================================================
set -euo pipefail

# Get all available sources (excluding monitors)
sources=$(pactl list sources short |
  grep -v '\.monitor' || true)

if [[ -z "$sources" ]]; then
  notify-send "Audio Input" "No input devices found" --urgency=low
  exit 0
fi

# Build parallel arrays: friendly name <-> source name
declare -a entries
declare -a source_names

while IFS=$'\t' read -r _index name _rest; do
  desc=$(pactl list sources |
    awk "/Name: $name/{found=1} found && /Description:/{print; exit}" |
    sed 's/.*Description: //' || echo "$name")
  entries+=("$desc")
  source_names+=("$name")
done <<<"$sources"

# Feed into fuzzel dmenu mode
menu_input=$(printf '%s\n' "${entries[@]}")

chosen=$(echo "$menu_input" |
  fuzzel --dmenu --prompt "󰍬  Input Device: " \
    2>/dev/null || true)

[[ -z "$chosen" ]] && exit 0

# Set the matching source as default
for i in "${!entries[@]}"; do
  if [[ "${entries[$i]}" == "$chosen" ]]; then
    pactl set-default-source "${source_names[$i]}"
    notify-send "Audio Input" "Switched to: $chosen" --urgency=low
    break
  fi
done
