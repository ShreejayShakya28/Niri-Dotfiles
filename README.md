# Niri Dotfiles
Dotfiles for my [Niri](https://github.com/YaLTeR/niri) Wayland compositor setup.

## Configs
| App | Description | Location |
|-----|-------------|----------|
| [Niri](https://github.com/YaLTeR/niri) | Wayland scrolling compositor | `~/.config/niri/config.kdl` |
| [Waybar](https://github.com/Alexays/Waybar) | Status bar with custom scripts | `~/.config/waybar/` |
| [Fuzzel](https://codeberg.org/dnkl/fuzzel) | App launcher | `~/.config/fuzzel/fuzzel.ini` |
| [Foot](https://codeberg.org/dnkl/foot) | Terminal emulator | `~/.config/foot/foot.ini` |
| [Tmux](https://github.com/tmux/tmux) | Terminal multiplexer | `~/.tmux.conf` |

## Sync Script
A `dot` script at the repo root handles syncing configs in both directions.
```bash
./dot push all        # deploy everything from repo → system
./dot pull all        # harvest everything from system → repo
./dot push waybar     # deploy one app
./dot pull waybar     # save one app's edits back to repo
```

### Options
| Flag | Description |
|------|-------------|
| `-n` | Dry run — shows what would be copied without making changes |
| `-b` | Backup existing files as `.bak` before overwriting |
| `-y` | Skip confirmation prompt (useful for scripting) |

```bash
./dot -n push all     # preview a full deploy
./dot -n pull all     # preview what pull would collect
./dot -b push waybar  # backup then deploy waybar
./dot -y push all     # deploy everything, no prompt
```

### Workflow
**New machine / fresh install:**
```bash
./dot push all
```

**After editing a live config:**
```bash
# edit ~/.config/waybar/config.jsonc directly, then save it back
./dot pull waybar
git add -p && git commit
```

> **Note:** `pull` on waybar scripts harvests **all** `.sh` files from the system,
> including any added locally. Run `git diff` before committing to review what changed.

## Structure
```
.
├── foot/
│   └── foot.ini
├── fuzzel/
│   └── fuzzel.ini
├── niri/
│   └── config.kdl
├── tmux/
│   └── tmux.conf
├── waybar/
│   ├── config.jsonc
│   ├── style.css
│   └── scripts/
│       ├── audio-input-menu.sh
│       ├── audio-output-menu.sh
│       ├── audio-sink-switcher.sh
│       ├── bluetooth-menu.sh
│       ├── bluetooth-status.sh
│       ├── mic-status.sh
│       ├── mpris-click.sh
│       ├── mpris-menu.sh
│       ├── mpris-pick.sh
│       ├── mpris-status.sh
│       ├── mpris-toggle.sh
│       ├── power-menu.sh
│       ├── wifi-menu.sh
│       └── wifi-status.sh
├── dot
└── README.md
```

## Features

### WiFi Manager (Waybar + nmcli)
A fuzzel-based WiFi network switcher integrated into Waybar.

**Waybar widget:**
| Interaction | Action |
|-------------|--------|
| Shows signal icon + SSID | Currently connected network |
| Shows `󰤭` | Disconnected |
| Left-click | Open fuzzel network picker |

**Network picker features:**
- Signal strength icon + percentage per network
- `󰌾` secured / `󰟠` open network indicator
- `󰒃` saved/known network indicator
- `●` marks currently connected network
- Connect, Disconnect, and Forget actions
- Password prompt via fuzzel for secured networks

---

### Microphone Status (Waybar + pactl)
Shows current mic mute state in the bar with a tooltip showing the active input device name.

**Waybar widget:**
| State | Icon | Interaction |
|-------|------|-------------|
| Active | `󰍬` | Left-click → toggle mute |
| Muted | `󰍭` | Left-click → toggle mute |
| Right-click | — | Open audio input picker |

---

### Audio Input Picker (fuzzel + pactl)
Right-click the mic widget to switch between input devices (microphones, USB audio, etc.) via a fuzzel menu showing friendly device names.

---

### Music Player (Waybar + mpv)
A lightweight background music player integrated into Waybar via MPRIS. No GUI window, no daemon — just mpv running in the background with playerctl for control.

**Waybar widget (left side of bar):**
| Interaction | Action |
|-------------|--------|
| Shows `󰎈` | No music playing |
| Shows song title | Music is playing or paused |
| Left-click (idle) | Open file picker → play selected songs |
| Left-click (playing) | Play / Pause toggle |
| Right-click | Open file picker → replace current queue (multi-select) |
| Scroll up | Previous track |
| Scroll down | Next track |

**Keybind:**
| Keybind | Action |
|---------|--------|
| `Mod+Shift+S` | Stop if playing — open file picker if idle |

**Shell function** (add to `~/.zshrc`):
```bash
play() {
  rm -f /tmp/mpvsocket
  mpv --input-ipc-server=/tmp/mpvsocket --no-terminal --really-quiet --no-video "$@" &disown
}
```

Then play from terminal with:
```bash
play ~/Music/song.mp3        # single file
play ~/Music/*.mp3           # whole folder
play song1.mp3 song2.mp3    # multiple files
```

---

## Dependencies

### System Packages
Install on Arch with `sudo pacman -S <package>`:

| Package | Used By | Purpose |
|---------|---------|---------|
| `waybar` | Waybar | Status bar |
| `fuzzel` | All `waybar/scripts/*.sh` | Dmenu-style picker for audio, bluetooth, power menus |
| `pipewire` / `wireplumber` | Waybar `wireplumber` module | Audio session management |
| `pulseaudio-utils` (`pactl`) | `audio-output-menu.sh`, `audio-sink-switcher.sh`, `mic-status.sh`, `audio-input-menu.sh` | Sink/source switching |
| `bluez` / `bluez-tools` | `bluetooth-menu.sh`, `bluetooth-status.sh` | Bluetooth device management |
| `libnotify` (`notify-send`) | All `waybar/scripts/*.sh` | Desktop notifications |
| `networkmanager` | `wifi-status.sh`, `wifi-menu.sh` | Network status and switching |
| `niri` | Compositor | Wayland scrolling compositor |
| `foot` | Terminal | Default terminal emulator |
| `tmux` | Terminal | Terminal multiplexer |
| `mpv` | `mpris-*.sh` | Background audio playback |
| `mpv-mpris` | `mpris-*.sh` | Exposes mpv to MPRIS2 / playerctl |
| `playerctl` | `mpris-*.sh` | MPRIS2 CLI controller for play/pause/next/prev/stop |
| `jq` | `mpris-status.sh` | JSON output for Waybar |
| `zenity` | `mpris-click.sh`, `mpris-pick.sh`, `mpris-toggle.sh` | GTK file picker for song selection |
| `socat` | `mpris-menu.sh` | mpv IPC socket communication (optional, for queue display) |

```bash
sudo pacman -S waybar fuzzel pipewire wireplumber pavucontrol \
               bluez bluez-utils libnotify networkmanager foot tmux \
               mpv playerctl jq zenity socat
```

> **mpv-mpris** — install via pacman then add to `~/.config/mpv/mpv.conf`:
> ```
> script=/usr/lib/mpv/mpris.so
> ```

### Fonts
Waybar uses **JetBrainsMono Nerd Font** for all icons and text.

```bash
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip JetBrainsMono.zip -d JetBrainsMono
fc-cache -fv
```

Verify the install:
```bash
fc-list | grep -i "JetBrains" | grep -i "Nerd"
```

> The `style.css` declares `font-family: "JetBrainsMono Nerd Font"` with `"Noto Sans"`
> as a fallback. Noto Sans ships by default so the bar will render even without the
> Nerd Font, just without icons.

### Waybar Script Dependencies
Each script performs a runtime dependency check and will send a desktop notification
listing any missing commands if they are not found.

| Script | Required Commands |
|--------|-------------------|
| `audio-output-menu.sh` | `pactl`, `fuzzel`, `awk`, `grep` |
| `audio-sink-switcher.sh` | `pactl` |
| `audio-input-menu.sh` | `pactl`, `fuzzel`, `notify-send` |
| `bluetooth-menu.sh` | `bluetoothctl`, `fuzzel` |
| `bluetooth-status.sh` | `bluetoothctl` |
| `mic-status.sh` | `pactl`, `awk` |
| `wifi-status.sh` | `nmcli`, `awk` |
| `wifi-menu.sh` | `nmcli`, `fuzzel`, `awk`, `grep`, `notify-send` |
| `power-menu.sh` | `fuzzel`, `systemctl` |
| `mpris-status.sh` | `playerctl`, `jq` |
| `mpris-click.sh` | `playerctl`, `zenity`, `mpv` |
| `mpris-pick.sh` | `playerctl`, `zenity`, `mpv` |
| `mpris-toggle.sh` | `playerctl`, `zenity`, `mpv` |
