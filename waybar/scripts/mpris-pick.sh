#!/bin/bash
# =============================================================================
# mpris-pick.sh — Waybar MPRIS right-click handler
#
# Opens zenity file picker with multi-select.
# Stops current playback and queues all selected files in mpv.
#
# Dependencies: zenity, mpv, playerctl
# =============================================================================

set -euo pipefail

readonly MPV_SOCKET="${MPV_SOCKET:-/tmp/mpvsocket}"

main() {
  local selected
  selected=$(zenity --file-selection \
    --multiple \
    --separator=$'\n' \
    --title="Select songs to play" \
    --file-filter="Audio files (mp3 flac ogg wav m4a aac opus) | *.mp3 *.flac *.ogg *.wav *.m4a *.aac *.opus *.MP3 *.FLAC" \
    2>/dev/null) || exit 0 # user cancelled

  [[ -z "$selected" ]] && exit 0

  # Stop current playback cleanly
  playerctl stop 2>/dev/null || true
  rm -f "$MPV_SOCKET"

  # Build args array from newline-separated paths
  local -a files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && files+=("$file")
  done <<<"$selected"

  mpv --input-ipc-server="$MPV_SOCKET" \
    --no-terminal \
    --really-quiet \
    --no-video \
    "${files[@]}" &
  disown
}

main "$@"
