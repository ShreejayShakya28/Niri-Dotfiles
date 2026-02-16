#!/bin/bash
# Audio output switcher with card profile switching

# Get card number
card_num=$(pactl list cards short | grep "alsa_card" | head -1 | awk '{print $1}')

if [ -z "$card_num" ]; then
  echo "Error: Could not find audio card"
  exit 1
fi

# Build menu with available outputs
menu_items=()
menu_items+=("Headphones / Headphone Jack")
menu_items+=("Speakers (Built-in)")

# Check if bluetooth is connected
bt_sinks=$(pactl list sinks short | grep "bluez")
if [ ! -z "$bt_sinks" ]; then
  # Get bluetooth device name
  bt_name=$(pactl list sinks | grep -A 20 "bluez" | grep "Description:" | head -1 | sed 's/.*Description: //')
  menu_items+=("$bt_name")
fi

# Show fuzzel menu
chosen=$(printf '%s\n' "${menu_items[@]}" | fuzzel --dmenu --prompt "Audio Output: ")

# Handle selection
if [ -z "$chosen" ]; then
  exit 0
fi

case "$chosen" in
"Headphones / Headphone Jack")
  # Switch to headphones profile
  pactl set-card-profile "$card_num" "HiFi (HDMI1, HDMI2, HDMI3, Headphones, Mic1)"
  sleep 0.5
  # Set headphones as default
  headphone_sink=$(pactl list sinks short | grep -i "headphone" | awk '{print $2}')
  if [ ! -z "$headphone_sink" ]; then
    pactl set-default-sink "$headphone_sink"
    if command -v notify-send &>/dev/null; then
      notify-send "Audio Output" "Switched to: Headphones"
    fi
  fi
  ;;

"Speakers (Built-in)")
  # Switch to speaker profile
  pactl set-card-profile "$card_num" "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Speaker)"
  sleep 0.5
  # Set speaker as default
  speaker_sink=$(pactl list sinks short | grep -i "speaker" | awk '{print $2}')
  if [ ! -z "$speaker_sink" ]; then
    pactl set-default-sink "$speaker_sink"
    if command -v notify-send &>/dev/null; then
      notify-send "Audio Output" "Switched to: Speakers"
    fi
  fi
  ;;

*)
  # Bluetooth device selected
  bt_sink=$(pactl list sinks short | grep "bluez" | awk '{print $2}')
  if [ ! -z "$bt_sink" ]; then
    pactl set-default-sink "$bt_sink"
    if command -v notify-send &>/dev/null; then
      notify-send "Audio Output" "Switched to: $chosen"
    fi
  fi
  ;;
esac
