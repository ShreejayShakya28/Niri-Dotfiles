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

A `dot` script at the repo root handles copying configs to their destinations.

```bash
# one app at a time
./dot niri
./dot waybar
./dot fuzzel
./dot foot
./dot tmux

# everything at once (prompts for confirmation)
./dot all
```

### Options

| Flag | Description |
|------|-------------|
| `-n` | Dry run — shows what would be copied without making changes |
| `-b` | Backup existing files as `.bak` before overwriting |
| `-y` | Skip confirmation prompt (useful for scripting) |

```bash
./dot -n all        # preview what sync all would do
./dot -b waybar     # backup then sync waybar
./dot -y all        # sync everything, no prompt
```

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
