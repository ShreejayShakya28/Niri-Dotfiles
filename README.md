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
