#!/bin/bash
# Bluetooth status monitor showing connected device name

bt_cmd() {
  echo -e "$1\nquit" | bluetoothctl 2>/dev/null
}

while true; do
  # Check if bluetooth is powered on
  bt_status=$(bt_cmd "show" | grep "Powered: yes")

  if [ -z "$bt_status" ]; then
    echo '{"text": "BT: OFF", "class": "off"}'
  else
    # Get all paired devices
    devices=$(bt_cmd "devices Paired")

    connected_device=""

    # Check each device for connection
    while IFS= read -r line; do
      if echo "$line" | grep -q "^Device"; then
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | cut -d' ' -f3-)

        # Check if this device is connected
        info=$(bt_cmd "info $mac")
        if echo "$info" | grep -q "Connected: yes"; then
          connected_device="$name"
          break
        fi
      fi
    done <<<"$devices"

    if [ ! -z "$connected_device" ]; then
      # Truncate name if too long
      if [ ${#connected_device} -gt 15 ]; then
        connected_device="${connected_device:0:12}..."
      fi

      echo "{\"text\": \"$connected_device\", \"class\": \"connected\"}"
    else
      echo '{"text": "BT: ON", "class": "on"}'
    fi
  fi

  sleep 3
done
