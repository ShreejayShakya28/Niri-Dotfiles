#!/bin/bash
# =============================================================================
# wifi-menu.sh — Fuzzel-based WiFi network switcher
# Requires: nmcli, fuzzel, notify-send (optional)
#
# Features:
#   - Signal strength bar + color coding (green/yellow/orange/red)
#   - 󰒃 Known/saved network indicator
#   - 󰌾 Secured (password) vs  Open network indicator
#   - Currently connected network marked
#   - Connect / Disconnect / Forget actions
#   - Password prompt via fuzzel for secured networks
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly NOTIFY_TIMEOUT=4000
readonly FUZZEL_PROMPT_NETWORK="󰤨  Network: "
readonly FUZZEL_PROMPT_ACTION="󰒓  Action: "
readonly FUZZEL_PROMPT_PASSWORD="󰌾  Password: "

# Pango color tags for fuzzel (requires fuzzel with pango markup support)
# Signal strength thresholds
readonly SIGNAL_EXCELLENT=75   # green
readonly SIGNAL_GOOD=50        # yellow
readonly SIGNAL_FAIR=25        # orange
# below SIGNAL_FAIR             # red

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_error() { echo "[wifi-menu] ERROR: $*" >&2; }
log_info()  { echo "[wifi-menu] INFO:  $*" >&2; }

# ---------------------------------------------------------------------------
# notify — non-fatal desktop notification
# ---------------------------------------------------------------------------
notify() {
  local summary="$1" body="${2:-}"
  command -v notify-send &>/dev/null \
    && notify-send --expire-time="$NOTIFY_TIMEOUT" "$summary" "$body" || true
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
    notify "WiFi Menu Error" "Missing: ${missing[*]}"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# signal_bar — convert signal % to 4-char bar and color name
# Output: "<bar>|<color>"
# ---------------------------------------------------------------------------
signal_bar() {
  local strength="$1"
  local bar color

  if   [[ "$strength" -ge "$SIGNAL_EXCELLENT" ]]; then
    bar="󰤨" color="#a6e3a1"   # full — green
  elif [[ "$strength" -ge "$SIGNAL_GOOD" ]]; then
    bar="󰤥" color="#f9e2af"   # good — yellow
  elif [[ "$strength" -ge "$SIGNAL_FAIR" ]]; then
    bar="󰤢" color="#fab387"   # fair — orange
  else
    bar="󰤟" color="#f38ba8"   # weak — red
  fi

  echo "${bar}|${color}"
}

# ---------------------------------------------------------------------------
# scan_networks — rescan and return parsed network list
# Populates parallel arrays:
#   NET_SSIDS[]        raw SSID
#   NET_SIGNALS[]      signal % (0-100)
#   NET_SECURITY[]     "WPA"|"WEP"|"--" (open)
#   NET_KNOWN[]        "yes"|"no"  (saved connection profile exists)
#   NET_CONNECTED[]    "yes"|"no"
# ---------------------------------------------------------------------------
scan_networks() {
  # Trigger a rescan (non-blocking, best effort)
  nmcli device wifi rescan 2>/dev/null || true

  # Get currently connected SSID
  CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi \
    | awk -F: '$1=="yes"{print $2}' | head -1 || true)

  # Get list of saved/known connection profiles
  mapfile -t KNOWN_PROFILES < <(
    nmcli -t -f name,type connection show \
      | awk -F: '$2~/wireless/{print $1}'
  )

  # Parse available networks
  # Fields: SSID, SIGNAL, SECURITY
  # Using IN_USE (*) marker from nmcli
  mapfile -t RAW_NETS < <(
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null \
      | grep -v '^[[:space:]]*$' \
      | sort -t: -k3 -rn   # sort by signal descending
  )

  NET_SSIDS=()
  NET_SIGNALS=()
  NET_SECURITY=()
  NET_KNOWN=()
  NET_CONNECTED=()
  SEEN_SSIDS=()

  for line in "${RAW_NETS[@]}"; do
    local inuse ssid signal security

    inuse=$(echo "$line"   | cut -d: -f1)
    ssid=$(echo "$line"    | cut -d: -f2)
    signal=$(echo "$line"  | cut -d: -f3)
    security=$(echo "$line" | cut -d: -f4-)

    # Skip empty SSIDs (hidden networks)
    [[ -z "$ssid" ]] && continue

    # Deduplicate — keep highest signal entry (already sorted desc)
    local already_seen=false
    for seen in "${SEEN_SSIDS[@]:-}"; do
      [[ "$seen" == "$ssid" ]] && already_seen=true && break
    done
    "$already_seen" && continue
    SEEN_SSIDS+=("$ssid")

    # Check if known/saved
    local known="no"
    for profile in "${KNOWN_PROFILES[@]:-}"; do
      [[ "$profile" == "$ssid" ]] && known="yes" && break
    done

    # Normalize security
    local sec="open"
    [[ "$security" != "--" && -n "$security" ]] && sec="secured"

    NET_SSIDS+=("$ssid")
    NET_SIGNALS+=("${signal:-0}")
    NET_SECURITY+=("$sec")
    NET_KNOWN+=("$known")
    NET_CONNECTED+=("$inuse")
  done
}

# ---------------------------------------------------------------------------
# build_menu_entries — format each network into a display line
# Populates MENU_LINES[] parallel to NET_* arrays
# ---------------------------------------------------------------------------
build_menu_entries() {
  MENU_LINES=()

  for i in "${!NET_SSIDS[@]}"; do
    local ssid="${NET_SSIDS[$i]}"
    local signal="${NET_SIGNALS[$i]}"
    local security="${NET_SECURITY[$i]}"
    local known="${NET_KNOWN[$i]}"
    local connected="${NET_CONNECTED[$i]}"

    # Signal bar + color
    local bar_color
    bar_color=$(signal_bar "$signal")
    local bar="${bar_color%%|*}"
    local color="${bar_color##*|}"

    # Security icon
    local sec_icon
    [[ "$security" == "secured" ]] && sec_icon="󰌾" || sec_icon="󰟠"

    # Known/saved icon
    local known_icon
    [[ "$known" == "yes" ]] && known_icon="󰒃" || known_icon=" "

    # Connected marker
    local conn_marker
    [[ "$connected" == "*" ]] && conn_marker=" ●" || conn_marker="  "

    # Pad signal to 3 chars for alignment
    local sig_padded
    sig_padded=$(printf "%3d" "$signal")

    # Final line format:
    # <bar> <sig>%  <sec_icon> <known_icon>  <ssid><conn_marker>
    MENU_LINES+=("${bar} ${sig_padded}%  ${sec_icon} ${known_icon}  ${ssid}${conn_marker}")
  done
}

# ---------------------------------------------------------------------------
# show_network_menu — display fuzzel picker, return chosen index via stdout
# Returns the index into NET_SSIDS[], or "" if dismissed
# ---------------------------------------------------------------------------
show_network_menu() {
  local chosen
  chosen=$(printf '%s\n' "${MENU_LINES[@]}" \
    | fuzzel --dmenu \
        --prompt "$FUZZEL_PROMPT_NETWORK" \
        --width 50 \
        2>/dev/null || true)

  [[ -z "$chosen" ]] && echo "" && return

  # Match chosen line back to index
  for i in "${!MENU_LINES[@]}"; do
    if [[ "${MENU_LINES[$i]}" == "$chosen" ]]; then
      echo "$i"
      return
    fi
  done
  echo ""
}

# ---------------------------------------------------------------------------
# prompt_password — show fuzzel password prompt, echo entered password
# Returns "" if cancelled
# ---------------------------------------------------------------------------
prompt_password() {
  local ssid="$1"
  fuzzel --dmenu \
    --prompt "󰌾  Password for '${ssid}': " \
    --width 50 \
    --password \
    < /dev/null \
    2>/dev/null || true
}

# ---------------------------------------------------------------------------
# action_menu — show connect/disconnect/forget actions for a network
# Returns chosen action string or ""
# ---------------------------------------------------------------------------
action_menu() {
  local ssid="$1"
  local is_connected="$2"   # "yes" | "no"
  local is_known="$3"       # "yes" | "no"
  local is_secured="$4"     # "secured" | "open"

  local actions=()

  if [[ "$is_connected" == "yes" ]]; then
    actions+=("󰤭  Disconnect")
  else
    if [[ "$is_known" == "yes" ]]; then
      actions+=("󰤨  Connect")
      actions+=("󰚃  Forget network")
    else
      actions+=("󰤨  Connect")
    fi
  fi
  actions+=("✕  Cancel")

  printf '%s\n' "${actions[@]}" \
    | fuzzel --dmenu \
        --prompt "${FUZZEL_PROMPT_ACTION}" \
        --width 40 \
        2>/dev/null || true
}

# ---------------------------------------------------------------------------
# connect_network — connect to SSID, prompting for password if needed
# ---------------------------------------------------------------------------
connect_network() {
  local ssid="$1"
  local is_known="$2"
  local is_secured="$3"

  # If we have a saved profile, just connect
  if [[ "$is_known" == "yes" ]]; then
    log_info "Connecting to known network: '$ssid'"
    notify "WiFi" "Connecting to $ssid..."
    if nmcli connection up "$ssid" 2>/dev/null; then
      notify "WiFi" "Connected to $ssid"
      log_info "Connected to '$ssid'"
    else
      notify "WiFi Error" "Failed to connect to $ssid"
      log_error "nmcli failed connecting to '$ssid'"
    fi
    return
  fi

  # New network — prompt for password if secured
  local password=""
  if [[ "$is_secured" == "secured" ]]; then
    password=$(prompt_password "$ssid")
    if [[ -z "$password" ]]; then
      log_info "Password entry cancelled for '$ssid'"
      return
    fi
  fi

  log_info "Connecting to new network: '$ssid'"
  notify "WiFi" "Connecting to $ssid..."

  local result
  if [[ -n "$password" ]]; then
    result=$(nmcli device wifi connect "$ssid" password "$password" 2>&1) || true
  else
    result=$(nmcli device wifi connect "$ssid" 2>&1) || true
  fi

  if echo "$result" | grep -q "successfully activated"; then
    notify "WiFi" "Connected to $ssid"
    log_info "Successfully connected to '$ssid'"
  else
    local err_msg
    err_msg=$(echo "$result" | grep -i "error\|failed" | head -1 || echo "Unknown error")
    notify "WiFi Error" "Failed: $err_msg"
    log_error "Connection failed for '$ssid': $err_msg"
  fi
}

# ---------------------------------------------------------------------------
# disconnect_network — disconnect from current SSID
# ---------------------------------------------------------------------------
disconnect_network() {
  local ssid="$1"
  log_info "Disconnecting from '$ssid'"
  notify "WiFi" "Disconnecting from $ssid..."
  if nmcli connection down "$ssid" 2>/dev/null; then
    notify "WiFi" "Disconnected from $ssid"
  else
    # Fallback: disconnect the wifi device entirely
    local wifi_dev
    wifi_dev=$(nmcli -t -f device,type device | awk -F: '$2=="wifi"{print $1}' | head -1)
    if [[ -n "$wifi_dev" ]]; then
      nmcli device disconnect "$wifi_dev" 2>/dev/null || true
      notify "WiFi" "Disconnected"
    else
      notify "WiFi Error" "Could not disconnect from $ssid"
      log_error "Failed to disconnect from '$ssid'"
    fi
  fi
}

# ---------------------------------------------------------------------------
# forget_network — delete saved connection profile
# ---------------------------------------------------------------------------
forget_network() {
  local ssid="$1"
  log_info "Forgetting network: '$ssid'"
  if nmcli connection delete "$ssid" 2>/dev/null; then
    notify "WiFi" "Forgot network: $ssid"
  else
    notify "WiFi Error" "Could not forget $ssid"
    log_error "Failed to forget '$ssid'"
  fi
}

# ---------------------------------------------------------------------------
# handle_selection — dispatch action for selected network index
# ---------------------------------------------------------------------------
handle_selection() {
  local idx="$1"
  local ssid="${NET_SSIDS[$idx]}"
  local signal="${NET_SIGNALS[$idx]}"
  local security="${NET_SECURITY[$idx]}"
  local known="${NET_KNOWN[$idx]}"
  local raw_connected="${NET_CONNECTED[$idx]}"

  local is_connected="no"
  [[ "$raw_connected" == "*" ]] && is_connected="yes"

  local action
  action=$(action_menu "$ssid" "$is_connected" "$known" "$security")

  [[ -z "$action" ]] && return

  case "$action" in
    *Connect)
      connect_network "$ssid" "$known" "$security"
      ;;
    *Disconnect)
      disconnect_network "$ssid"
      ;;
    *Forget*)
      forget_network "$ssid"
      ;;
    *Cancel|"✕"*)
      return
      ;;
    *)
      log_error "Unknown action: '$action'"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  require_cmds nmcli fuzzel awk grep

  # Check wifi is available
  if ! nmcli radio wifi 2>/dev/null | grep -q "enabled"; then
    notify "WiFi" "WiFi is disabled — enabling..."
    nmcli radio wifi on 2>/dev/null || true
    sleep 1
  fi

  # Declare all parallel arrays
  declare -a NET_SSIDS=()
  declare -a NET_SIGNALS=()
  declare -a NET_SECURITY=()
  declare -a NET_KNOWN=()
  declare -a NET_CONNECTED=()
  declare -a MENU_LINES=()
  declare -a SEEN_SSIDS=()
  declare -a KNOWN_PROFILES=()
  declare    CURRENT_SSID=""

  scan_networks
  build_menu_entries

  if [[ ${#NET_SSIDS[@]} -eq 0 ]]; then
    notify "WiFi" "No networks found"
    log_error "No networks found after scan"
    exit 0
  fi

  local chosen_idx
  chosen_idx=$(show_network_menu)

  [[ -z "$chosen_idx" ]] && exit 0

  handle_selection "$chosen_idx"
}

main "$@"
