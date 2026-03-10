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
│       ├── audio-output-menu.sh
│       ├── audio-sink-switcher.sh
│       ├── bluetooth-menu.sh
│       ├── bluetooth-status.sh
│       └── power-menu.sh
├── dot
└── README.md
```

## Dependencies

### System Packages
Install on Fedora with `sudo dnf install <package>`:

| Package | Used By | Purpose |
|---------|---------|---------|
| `waybar` | Waybar | Status bar |
| `fuzzel` | All `waybar/scripts/*.sh` | Dmenu-style picker for audio, bluetooth, power menus |
| `pipewire` / `wireplumber` | Waybar `wireplumber` module | Audio session management |
| `pulseaudio-utils` (`pactl`) | `audio-output-menu.sh`, `audio-sink-switcher.sh` | Sink/profile switching |
| `bluez` / `bluez-tools` | `bluetooth-menu.sh`, `bluetooth-status.sh` | Bluetooth device management |
| `libnotify` (`notify-send`) | All `waybar/scripts/*.sh` | Desktop notifications on output switch |
| `networkmanager` | Waybar `network` module | Network status and `nm-connection-editor` |
| `niri` | Compositor | Wayland scrolling compositor |
| `foot` | Terminal | Default terminal emulator |
| `tmux` | Terminal | Terminal multiplexer |

```bash
sudo dnf install waybar fuzzel pipewire wireplumber pulseaudio-utils \
                 bluez bluez-tools libnotify networkmanager foot tmux
```

### Fonts
Waybar uses **JetBrainsMono Nerd Font** for all icons and text. The Fedora repo
ships the base font but not the Nerd Font patched version — install it manually:

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
> as a fallback. Noto Sans ships by default on Fedora so the bar will render even
> without the Nerd Font, just without the icons.

### Waybar Script Dependencies
Each script in `waybar/scripts/` performs a runtime dependency check and will send
a desktop notification listing any missing commands if they are not found.

| Script | Required Commands |
|--------|-------------------|
| `audio-output-menu.sh` | `pactl`, `fuzzel`, `awk`, `grep` |
| `audio-sink-switcher.sh` | `pactl` |
| `bluetooth-menu.sh` | `bluetoothctl`, `fuzzel` |
| `bluetooth-status.sh` | `bluetoothctl` |
| `power-menu.sh` | `fuzzel`, `systemctl` |
