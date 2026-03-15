#!/bin/bash
# =============================================================================
# mpris-toggle.sh — Super+Shift+S keybind handler
#
# If music is playing/paused  → stop completely
# If nothing is playing       → open file picker and play selected
#
# Dependencies: playerctl, zenity, mpv
# =============================================================================

set -euo pipefail

readonly MPV_SOCKET="${MPV_SOCKET:-/tmp/mpvsocket}"

main() {
  local status
  status=$(playerctl status 2>/dev/null || true)

  if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
    playerctl stop
    rm -f "$MPV_SOCKET"
    exit 0
  fi

  # Nothing playing — open file picker
  local selected
  selected=$(zenity --file-selection \
    --multiple \
    --separator=$'\n' \
    --title="Select songs to play" \
    --file-filter="Audio files (mp3 flac ogg wav m4a aac opus) | *.mp3 *.flac *.ogg *.wav *.m4a *.aac *.opus *.MP3 *.FLAC" \
    2>/dev/null) || exit 0

  [[ -z "$selected" ]] && exit 0

  rm -f "$MPV_SOCKET"

  local -a files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && files+=("$file")
  done <<< "$selected"

  mpv --input-ipc-server="$MPV_SOCKET" \
      --no-terminal \
      --really-quiet \
      --no-video \
      "${files[@]}" &disown
}

main "$@"
