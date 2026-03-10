#!/bin/bash
# =============================================================================
# audio-output-menu.sh — Waybar audio output switcher
# System: Tiger Lake-LP (PipeWire/ALSA) — all sinks always present
#
# Sink map on this machine:
#   HiFi__Speaker__sink  → Built-in laptop speakers
#   HiFi__HDMI1__sink    → HDMI-A-1 (BenQ GW2490 monitor)
#   HiFi__HDMI2__sink    → HDMI/DP 2 (unused)
#   HiFi__HDMI3__sink    → HDMI/DP 3 (unused)
#
# Profile switching is only needed for Headphones (adds HiFi__Headphones__sink)
# All other sinks are always visible regardless of active profile.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly NOTIFY_TIMEOUT=3000
readonly PACTL_SETTLE_DELAY=0.5
readonly FUZZEL_PROMPT="  Audio Output: "

# Profile strings — verified via: pactl list cards | grep -A 40 "alsa_card"
readonly PROFILE_WITH_HEADPHONES="HiFi (HDMI1, HDMI2, HDMI3, Headphones, Mic1)"
readonly PROFILE_WITH_SPEAKER="HiFi (HDMI1, HDMI2, HDMI3, Mic1, Speaker)"

# Sink name fragments — matched against pactl list sinks short output
readonly SINK_SPEAKER="HiFi__Speaker__sink"
readonly SINK_HDMI1="HiFi__HDMI1__sink"
readonly SINK_HDMI2="HiFi__HDMI2__sink"
readonly SINK_HDMI3="HiFi__HDMI3__sink"
readonly SINK_HEADPHONES="HiFi__Headphones__sink"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_error() { echo "[audio-menu] ERROR: $*" >&2; }
log_info() { echo "[audio-menu] INFO:  $*" >&2; }

# ---------------------------------------------------------------------------
# notify — non-fatal desktop notification
# ---------------------------------------------------------------------------
notify() {
  local summary="$1" body="${2:-}"
  command -v notify-send &>/dev/null &&
    notify-send --expire-time="$NOTIFY_TIMEOUT" "$summary" "$body" || true
}

# ---------------------------------------------------------------------------
# require_cmds — exit early if any dependency is missing
# ---------------------------------------------------------------------------
require_cmds() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    notify "Audio Menu Error" "Missing: ${missing[*]}"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# get_card_num — first ALSA card index, exits if not found
# ---------------------------------------------------------------------------
get_card_num() {
  local card
  card=$(pactl list cards short 2>/dev/null |
    awk '/alsa_card/{print $1; exit}')
  if [[ -z "$card" ]]; then
    log_error "No ALSA card found"
    notify "Audio Error" "No audio card detected"
    exit 1
  fi
  echo "$card"
}

# ---------------------------------------------------------------------------
# find_sink — return first sink name containing the given fragment, or ""
# ---------------------------------------------------------------------------
find_sink() {
  local fragment="$1"
  pactl list sinks short 2>/dev/null |
    awk -v frag="$fragment" '$2 ~ frag {print $2; exit}'
}

# ---------------------------------------------------------------------------
# activate_sink — set as default sink + notify; returns 1 on failure
# ---------------------------------------------------------------------------
activate_sink() {
  local sink="$1" label="$2"
  if [[ -z "$sink" ]]; then
    log_error "activate_sink called with empty sink for: '$label'"
    notify "Audio Error" "Sink not found for: $label"
    return 1
  fi
  if ! pactl set-default-sink "$sink" 2>/dev/null; then
    log_error "pactl set-default-sink failed for: '$sink'"
    notify "Audio Error" "Could not activate: $label"
    return 1
  fi
  log_info "Active → $label ($sink)"
  notify "Audio Output" "Switched to: $label"
}

# ---------------------------------------------------------------------------
# switch_profile_then_activate — change card profile, wait for PipeWire to
# settle, then find and activate the target sink
# ---------------------------------------------------------------------------
switch_profile_then_activate() {
  local card_num="$1" profile="$2" sink_fragment="$3" label="$4"

  if ! pactl set-card-profile "$card_num" "$profile" 2>/dev/null; then
    log_error "Failed to set card profile: '$profile'"
    notify "Audio Error" "Could not switch profile for: $label"
    return 1
  fi

  sleep "$PACTL_SETTLE_DELAY"

  local sink
  sink=$(find_sink "$sink_fragment")
  activate_sink "$sink" "$label"
}

# ---------------------------------------------------------------------------
# build_menu — populate MENU_LABELS[] and SINK_MAP{}
#
# Entry format in SINK_MAP:
#   "direct:<sink_fragment>"         — find sink and activate directly
#   "profile:<profile>|<fragment>"   — switch profile first, then activate
# ---------------------------------------------------------------------------
build_menu() {
  # Always-present sinks (no profile change needed)
  MENU_LABELS+=("🔊  Speakers (Built-in)")
  SINK_MAP["🔊  Speakers (Built-in)"]="profile:${PROFILE_WITH_SPEAKER}|${SINK_SPEAKER}"

  MENU_LABELS+=("🖥️  BenQ GW2490 (HDMI-A-1)")
  SINK_MAP["🖥️  BenQ GW2490 (HDMI-A-1)"]="direct:${SINK_HDMI1}"

  # Secondary HDMI ports — only show if a sink is currently active (non-SUSPENDED)
  # Uncomment these if you connect additional displays:
  # MENU_LABELS+=("🖥️  HDMI / DP 2")
  # SINK_MAP["🖥️  HDMI / DP 2"]="direct:${SINK_HDMI2}"
  # MENU_LABELS+=("🖥️  HDMI / DP 3")
  # SINK_MAP["🖥️  HDMI / DP 3"]="direct:${SINK_HDMI3}"

  # Headphones — requires profile switch; only show if sink already visible OR always offer
  MENU_LABELS+=("🎧  Headphones / Headphone Jack")
  local hp_sink
  hp_sink=$(find_sink "$SINK_HEADPHONES")
  if [[ -n "$hp_sink" ]]; then
    # Profile already set — activate directly
    SINK_MAP["🎧  Headphones / Headphone Jack"]="direct:${SINK_HEADPHONES}"
  else
    # Profile switch required to expose the headphone sink
    SINK_MAP["🎧  Headphones / Headphone Jack"]="profile:${PROFILE_WITH_HEADPHONES}|${SINK_HEADPHONES}"
  fi

  # Bluetooth — enumerate dynamically; omit section entirely if none connected
  local bt_line
  while IFS= read -r bt_line; do
    [[ -z "$bt_line" ]] && continue
    local bt_sink
    bt_sink=$(echo "$bt_line" | awk '{print $2}')
    # Resolve human-readable name from PipeWire node properties
    local bt_label
    bt_label=$(pactl list sinks 2>/dev/null |
      awk "/Name: ${bt_sink}/{f=1} f && /node\.nick =/{gsub(/.*= \"|\"/, \"\"); print; exit}")
    [[ -z "$bt_label" ]] && bt_label="Bluetooth Device"
    local menu_entry="🎵  ${bt_label}"
    MENU_LABELS+=("$menu_entry")
    SINK_MAP["$menu_entry"]="direct:${bt_sink}"
  done < <(pactl list sinks short 2>/dev/null | grep "bluez_output" || true)
}

# ---------------------------------------------------------------------------
# handle_selection — dispatch chosen label via SINK_MAP
# ---------------------------------------------------------------------------
handle_selection() {
  local chosen="$1" card_num="$2"
  local map_val="${SINK_MAP[$chosen]:-}"

  if [[ -z "$map_val" ]]; then
    log_error "No SINK_MAP entry for: '$chosen'"
    notify "Audio Error" "Unknown selection"
    return 1
  fi

  local action="${map_val%%:*}"
  local payload="${map_val#*:}"

  case "$action" in
  direct)
    local sink
    sink=$(find_sink "$payload")
    activate_sink "$sink" "$chosen"
    ;;
  profile)
    local profile="${payload%%|*}"
    local fragment="${payload##*|}"
    switch_profile_then_activate "$card_num" "$profile" "$fragment" "$chosen"
    ;;
  *)
    log_error "Unknown action '$action' in SINK_MAP for: '$chosen'"
    notify "Audio Error" "Cannot switch to: $chosen"
    return 1
    ;;
  esac
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  require_cmds pactl fuzzel awk grep

  local card_num
  card_num=$(get_card_num)

  declare -a MENU_LABELS=()
  declare -A SINK_MAP=()
  build_menu

  if [[ ${#MENU_LABELS[@]} -eq 0 ]]; then
    log_error "No audio outputs found"
    notify "Audio Error" "No outputs available"
    exit 1
  fi

  local chosen
  chosen=$(printf '%s\n' "${MENU_LABELS[@]}" |
    fuzzel --dmenu --prompt "$FUZZEL_PROMPT" 2>/dev/null || true)

  [[ -z "$chosen" ]] && exit 0

  handle_selection "$chosen" "$card_num"
}

main "$@"
