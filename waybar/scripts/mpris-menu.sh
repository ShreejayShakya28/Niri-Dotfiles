#!/bin/bash
# =============================================================================
# mpris-menu.sh — Waybar MPRIS controls + mpv queue via fuzzel
#
# Right-click menu showing:
#   • Playback controls  (play/pause, previous, next, stop)
#   • mpv playlist       (jump-to-track, current track highlighted)
#
# Queue/playlist requires mpv launched with an IPC socket:
#   mpv --input-ipc-server="${MPV_SOCKET:-/tmp/mpvsocket}" [files...]
#
# Override socket path via environment:
#   export MPV_SOCKET=~/.local/state/mpv/socket
#
# Dependencies: playerctl, fuzzel, jq
# Optional:     socat  (enables playlist display + jump-to-track)
#               notify-send (desktop notifications)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly NOTIFY_TIMEOUT=2000
readonly FUZZEL_PROMPT="  Media Controls: "
readonly MPV_SOCKET="${MPV_SOCKET:-/tmp/mpvsocket}"

readonly ICON_PLAY="󰐊"
readonly ICON_PAUSE="󰏤"
readonly ICON_PREV="󰒮"
readonly ICON_NEXT="󰒭"
readonly ICON_STOP="󰓛"
readonly ICON_NOW="▶"
readonly SEPARATOR="────────────────────"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_error() { echo "[mpris-menu] ERROR: $*" >&2; }
log_info()  { echo "[mpris-menu] INFO:  $*" >&2; }

# ---------------------------------------------------------------------------
# notify — non-fatal desktop notification
# ---------------------------------------------------------------------------
notify() {
  local summary="$1" body="${2:-}"
  command -v notify-send &>/dev/null &&
    notify-send --expire-time="$NOTIFY_TIMEOUT" "$summary" "$body" || true
}

# ---------------------------------------------------------------------------
# require_cmds — exit early if any hard dependency is missing
# ---------------------------------------------------------------------------
require_cmds() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    notify "Media Error" "Missing: ${missing[*]}"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# mpv_ipc — send a JSON command to mpv's IPC socket; returns response or ""
# Requires socat; silently skips if socket or socat is unavailable.
# ---------------------------------------------------------------------------
mpv_ipc() {
  [[ -S "$MPV_SOCKET" ]] || return 0
  command -v socat &>/dev/null || return 0
  printf '%s\n' "$1" | socat - "$MPV_SOCKET" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# build_playlist_entries — append playlist items to MENU_LABELS[] and
# ACTION_MAP[] via mpv IPC.  No-op when socket or socat is unavailable.
# ---------------------------------------------------------------------------
build_playlist_entries() {
  [[ -S "$MPV_SOCKET" ]] || return 0

  local raw
  raw=$(mpv_ipc '{"command": ["get_property", "playlist"]}')
  [[ -z "$raw" ]] && return 0

  # Validate response shape
  if ! echo "$raw" | jq -e '.data | type == "array"' &>/dev/null; then
    log_error "Unexpected mpv playlist response — skipping queue"
    return 0
  fi

  # Separator between controls and playlist
  MENU_LABELS+=("$SEPARATOR")
  ACTION_MAP["$SEPARATOR"]="noop"

  local idx=0
  while IFS= read -r entry_json; do
    [[ -z "$entry_json" ]] && { ((idx++)) || true; continue; }

    local is_current title
    is_current=$(echo "$entry_json" | jq -r '.current // false')
    # Prefer .title; fall back to the basename of .filename
    title=$(echo "$entry_json" | jq -r \
      '(.title // (.filename | if . then split("/")[-1] else "Track" end))')

    local prefix="    "
    [[ "$is_current" == "true" ]] && prefix="${ICON_NOW}   "

    local label="${prefix}${title}"
    MENU_LABELS+=("$label")
    ACTION_MAP["$label"]="jump:${idx}"

    log_info "Playlist[${idx}]: ${title} (current=${is_current})"
    ((idx++)) || true
  done < <(echo "$raw" | jq -c '.data[]?')
}

# ---------------------------------------------------------------------------
# handle_selection — dispatch the chosen fuzzel entry via ACTION_MAP
# ---------------------------------------------------------------------------
handle_selection() {
  local chosen="$1"
  local mapped="${ACTION_MAP[$chosen]:-}"

  if [[ -z "$mapped" ]]; then
    log_error "No ACTION_MAP entry for: '$chosen'"
    notify "Media Error" "Unknown selection"
    return 1
  fi

  local action="${mapped%%:*}"
  local payload="${mapped#*:}"

  case "$action" in
    cmd)
      log_info "Executing: $payload"
      eval "$payload"
      ;;
    jump)
      log_info "Jumping to playlist index: $payload"
      mpv_ipc "{\"command\": [\"set_property\", \"playlist-pos\", ${payload}]}" >/dev/null
      mpv_ipc '{"command": ["set_property", "pause", false]}' >/dev/null
      ;;
    noop)
      exit 0
      ;;
    *)
      log_error "Unknown action type '${action}' for: '$chosen'"
      notify "Media Error" "Cannot execute: $chosen"
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  require_cmds playerctl fuzzel jq

  local status
  status=$(playerctl status 2>/dev/null || echo "Stopped")

  # ── Playback controls ────────────────────────────────────────────────────
  declare -a MENU_LABELS=()
  declare -A ACTION_MAP=()

  if [[ "$status" == "Playing" ]]; then
    MENU_LABELS+=("${ICON_PAUSE}  Pause")
    ACTION_MAP["${ICON_PAUSE}  Pause"]="cmd:playerctl pause"
  else
    MENU_LABELS+=("${ICON_PLAY}  Play")
    ACTION_MAP["${ICON_PLAY}  Play"]="cmd:playerctl play"
  fi

  MENU_LABELS+=("${ICON_PREV}  Previous")
  ACTION_MAP["${ICON_PREV}  Previous"]="cmd:playerctl previous"

  MENU_LABELS+=("${ICON_NEXT}  Next")
  ACTION_MAP["${ICON_NEXT}  Next"]="cmd:playerctl next"

  MENU_LABELS+=("${ICON_STOP}  Stop")
  ACTION_MAP["${ICON_STOP}  Stop"]="cmd:playerctl stop"

  # ── mpv playlist (optional — requires socat + IPC socket) ────────────────
  build_playlist_entries

  # ── Fuzzel prompt ────────────────────────────────────────────────────────
  if [[ ${#MENU_LABELS[@]} -eq 0 ]]; then
    log_error "Menu is empty — nothing to show"
    exit 1
  fi

  local chosen
  chosen=$(printf '%s\n' "${MENU_LABELS[@]}" |
    fuzzel --dmenu --prompt "$FUZZEL_PROMPT" 2>/dev/null || true)

  [[ -z "$chosen" ]] && exit 0

  handle_selection "$chosen"
}

main "$@"
