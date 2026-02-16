#!/bin/bash
# Cycle through available audio sinks

# Get all available sinks
sinks=$(wpctl status | grep -A 50 "Audio" | grep "├─\|│  ├─" | grep -v "Streams:" | awk '{print $2}' | tr -d '*.')

if [ -z "$sinks" ]; then
    exit 0
fi

# Get current default sink
current_sink=$(wpctl status | grep -A 50 "Audio" | grep "├─\|│  ├─" | grep "\*" | awk '{print $2}' | tr -d '*.')

# Convert to array
sink_array=($sinks)

# Find current sink index
current_index=-1
for i in "${!sink_array[@]}"; do
    if [ "${sink_array[$i]}" = "$current_sink" ]; then
        current_index=$i
        break
    fi
done

# Get next sink (cycle back to 0 if at end)
next_index=$(( (current_index + 1) % ${#sink_array[@]} ))
next_sink="${sink_array[$next_index]}"

# Switch to next sink
wpctl set-default "$next_sink"

# Get sink name for notification
sink_name=$(wpctl status | grep "$next_sink" | sed 's/.*\. //' | sed 's/\[.*\]//')

# Optional: notify user (requires mako)
if command -v notify-send &> /dev/null; then
    notify-send "Audio Output" "Switched to: $sink_name"
fi
