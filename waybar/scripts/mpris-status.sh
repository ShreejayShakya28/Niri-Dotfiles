#!/bin/bash
# =============================================================================
# mpris-status.sh — Waybar MPRIS media status output
# =============================================================================

set -euo pipefail

readonly MAX_TITLE_LEN=35
readonly ICON_MUSIC="󰎈"

truncate_str() {
  local str="$1" max="$2"
  [[ ${#str} -gt $max ]] && echo "${str:0:$max}…" || echo "$str"
}

emit_json() {
  local text="$1" tooltip="$2" class="$3"
  /usr/bin/jq -cn \
    --arg text "$text" \
    --arg tooltip "$tooltip" \
    --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

main() {
  if ! command -v playerctl &>/dev/null || ! /usr/bin/jq --version &>/dev/null 2>&1; then
    emit_json "$ICON_MUSIC" "Missing: playerctl or jq" "inactive"
    return
  fi

  local status
  status=$(playerctl status 2>/dev/null || true)

  if [[ -z "$status" || "$status" == "Stopped" ]]; then
    emit_json "$ICON_MUSIC" "Click to play music" "inactive"
    return
  fi

  local title
  title=$(playerctl metadata title 2>/dev/null || echo "Unknown")

  local short_title
  short_title=$(truncate_str "$title" "$MAX_TITLE_LEN")

  local class
  case "$status" in
  Playing) class="playing" ;;
  Paused) class="paused" ;;
  *) class="stopped" ;;
  esac

  local artist
  artist=$(playerctl metadata artist 2>/dev/null || true)
  local tooltip="$title"
  [[ -n "$artist" ]] && tooltip="${artist} — ${title}"

  emit_json "${short_title}" "$tooltip" "$class"
}

main "$@"
