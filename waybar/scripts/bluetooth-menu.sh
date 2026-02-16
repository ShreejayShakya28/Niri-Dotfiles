#!/bin/bash
# Fast Bluetooth menu - shows paired devices instantly

# Function to run bluetoothctl commands
bt_cmd() {
  echo -e "$1\nquit" | bluetoothctl
}

# Function for commands that need time (connect, pair, etc)
bt_cmd_wait() {
  (
    echo -e "$1"
    sleep 5
    echo "quit"
  ) | bluetoothctl
}

# Check if bluetooth is powered on
bt_power=$(bt_cmd "show" | grep "Powered: yes")

if [ -z "$bt_power" ]; then
  # Bluetooth is off
  choice=$(printf "Turn Bluetooth ON\nCancel" | fuzzel --dmenu --prompt "Bluetooth is OFF: ")
  if [ "$choice" = "Turn Bluetooth ON" ]; then
    bt_cmd "power on"
    sleep 1
    exec "$0"
  fi
  exit 0
fi

# Get paired devices (INSTANT - no scanning)
paired=$(bt_cmd "devices Paired")

# Build menu
menu_items=()
menu_items+=("Scan for new devices")
menu_items+=("Turn Bluetooth OFF")
menu_items+=("---")

if [ -z "$paired" ] || ! echo "$paired" | grep -q "Device"; then
  menu_items+=("(no paired devices)")
else
  while IFS= read -r line; do
    if echo "$line" | grep -q "^Device"; then
      mac=$(echo "$line" | awk '{print $2}')
      name=$(echo "$line" | cut -d' ' -f3-)

      # Get connection status quickly
      info=$(bt_cmd "info $mac")

      if echo "$info" | grep -q "Connected: yes"; then
        menu_items+=("✓ $name|$mac")
      else
        menu_items+=("○ $name|$mac")
      fi
    fi
  done <<<"$paired"
fi

# Show menu
chosen=$(printf '%s\n' "${menu_items[@]}" | sed 's/|.*//' | fuzzel --dmenu --prompt "Bluetooth: ")

# Handle selection
if [ -z "$chosen" ]; then
  exit 0
elif [ "$chosen" = "Turn Bluetooth OFF" ]; then
  bt_cmd "power off"
elif [ "$chosen" = "Scan for new devices" ]; then
  # Scan and show all devices
  (echo -e "scan on" | bluetoothctl) >/dev/null 2>&1 &
  sleep 4
  all_devices=$(bt_cmd "devices")

  # Show all found devices in fuzzel
  device_menu=()
  while IFS= read -r line; do
    if echo "$line" | grep -q "^Device"; then
      mac=$(echo "$line" | awk '{print $2}')
      name=$(echo "$line" | cut -d' ' -f3-)

      info=$(bt_cmd "info $mac")
      if ! echo "$info" | grep -q "Paired: yes"; then
        device_menu+=("+ $name|$mac")
      fi
    fi
  done <<<"$all_devices"

  if [ ${#device_menu[@]} -eq 0 ]; then
    device_menu+=("(no new devices found)")
  fi

  new_device=$(printf '%s\n' "${device_menu[@]}" | sed 's/|.*//' | fuzzel --dmenu --prompt "New Devices: ")

  if [[ "$new_device" == "+"* ]]; then
    device_name=$(echo "$new_device" | sed 's/^+ //')
    new_mac=$(echo "$all_devices" | grep "$device_name" | awk '{print $2}' | head -1)

    if [ ! -z "$new_mac" ]; then
      bt_cmd_wait "pair $new_mac"
      bt_cmd "trust $new_mac"
      bt_cmd_wait "connect $new_mac"
    fi
  fi
elif [ "$chosen" = "---" ] || [[ "$chosen" == "(no"* ]]; then
  exit 0
else
  # Device selected - toggle connection
  device_name=$(echo "$chosen" | sed 's/^✓ //; s/^○ //')
  mac=$(echo "$paired" | grep "$device_name" | awk '{print $2}' | head -1)

  if [ ! -z "$mac" ]; then
    info=$(bt_cmd "info $mac")

    if echo "$info" | grep -q "Connected: yes"; then
      bt_cmd_wait "disconnect $mac"
    else
      bt_cmd_wait "connect $mac"
    fi
  fi
fi
