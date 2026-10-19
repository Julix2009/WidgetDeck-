# WidgetDeck

Desktop widgets for **Hyprland** on **Arch Linux**, built with Quickshell: clock, CPU/RAM, music, visualizer, network, temperatures, system status, air quality and weather (with rain and snow particles), in **Frosted Glass** or **Liquid Glass** style. A built-in **builder** lets you place everything with the mouse: snap grid, guides, multi-select, align and distribute.

It runs on its own: it needs none of the author's dotfiles, no other Quickshell setup, no icon theme and no particular font. Optional parts (a bar, a notification service with power menu) are **off by default**.

> Deutsche Version: [README.de.md](README.de.md)

**Only Arch Linux is supported** (Hyprland + Quickshell from the official repositories).

| Liquid Glass | Frosted Glass |
|---|---|
| ![Liquid Glass](docs/liquid-glass.png) | ![Frosted Glass](docs/frosted-glass.png) |

![Builder](docs/builder.png)

_Screenshots from a clean test session: neutral wallpaper, demo location and network name, no personal data._

## Install

```bash
git clone https://github.com/Julix2009/WidgetDeck-.git && cd WidgetDeck- && ./install.sh
```

The installer asks before it changes anything that belongs to you. Then run `hyprctl reload` (or log in again): WidgetDeck starts with your session, and a short **setup assistant** opens once (wallpaper, location, units, style, size, widgets). Nothing needs a restart or manual editing.

Useful options: `--dry-run` (show only), `--yes`, `--modules widgets,builder,bar,notifications`, `--no-hypr-config`, `--prefix <dir>` (try it in a scratch home), `--channel stable`, `--uninstall`.

## Requirements and packages

All packages are in the **official repositories** (no AUR).

| Purpose | Packages |
|---|---|
| required | `quickshell qt6-declarative qt6-wayland qt6-shadertools jq curl iproute2 iputils` |
| recommended (font) | `adwaita-fonts` (without it the next installed font is used: Inter, Cantarell, Noto Sans, DejaVu Sans, else the system default) |
| optional | `networkmanager` (Wi-Fi name), `playerctl`, `cava` (visualizer), `matugen` (colours from the wallpaper; without it a fixed default palette is used) |

Icons are drawn by WidgetDeck itself, so no icon font or icon theme is needed.

## Compatibility

| | Tested | Notes |
|---|---|---|
| Hyprland | **0.55.4** (`hyprland.conf` and Lua `hyprland.lua`) | Rules for 0.53 / 0.54 use the same block syntax and are expected to work but are **untested**. Older versions get the old rule syntax (**untested**); below 0.40 the installer stops. |
| Quickshell / Qt | 0.3.0 (git), Qt 6.11.1 | Qt 6.7 or newer is required. |
| GPU | Intel (Arc) | The shader is a plain Qt ShaderEffect; AMD and NVIDIA are **untested**. Without a working shader everything falls back to Frosted Glass. |
| Wallpaper tools | **awww** (real); swww, hyprpaper (old and new config syntax), swaybg, wpaperd (simulated output / config only) | A manual path in the settings always works. |
| Monitors | one real monitor, plus virtual monitors incl. scale 1.5 in a nested session | The widgets live on one monitor (choose it in the settings). |
| Config styles | plain file, split config with `source =`, Lua, `XDG_CONFIG_HOME`, read-only / Nix store symlink (shown manually) | uwsm: exec-once works, a hint is printed (untested). |
| Hardware | no battery, no fans, no sensors, no Wi-Fi, no network: widgets leave out what is missing | NVIDIA temperature via `nvidia-smi` (simulated). |
| Languages | English (default), German | Chosen by system language or in the settings. |

Known limitations: a monitor much smaller than the one a layout was made on can leave widgets overlapping until you reset the layout; switching the notification module off needs one `widgetdeck restart` before another notification daemon can take over; the bar and notification cards were checked in a nested session but not compared pixel by pixel.

## What it changes - and what it does not

Changes (all removable with `./uninstall.sh`):

| What | Where |
|---|---|
| program files | `~/.config/quickshell/widgetdeck/` (start manually with `qs -c widgetdeck`) |
| commands | `~/.local/bin/widgetdeck`, `widgetdeck-update`, `widgetdeck-doctor` |
| your settings | `~/.config/widgetdeck/` (never overwritten by updates) |
| Hyprland rules | a **separate** file `~/.config/hypr/widgetdeck.conf` (or `.lua`), plus **one marked include line** in your config, only after you agree, with a timestamped backup and a check with `Hyprland --verify-config` first |
| cache, log | `~/.cache/widgetdeck/` |
| matugen | one marked block in `~/.config/matugen/config.toml`, only if matugen is installed and you agree |

It does **not**: stop, disable or replace any other program (bars, notification daemons, wallpaper tools); edit anything else in your Hyprland config; install anything from the AUR; run as root (only `pacman` is called through `sudo`, after you confirm).

**Network use** (all optional): weather and air quality come from open-meteo.com (only coordinates are sent). The location can be found once by IP address via ipwho.is (cached for a week) - the assistant explains this and you can enter coordinates instead or switch weather off. A daily update check does `git ls-remote` on this repository; it can be switched off in the settings. Nothing is looked up before you accept the assistant's location question.

## Modules

| Module | Default | Notes |
|---|---|---|
| Widgets | on | weather, network, temperatures, system, air quality, music |
| Builder and grid | on | the editor (`widgetdeck builder`) |
| Bar | **off** | slim top bar: workspaces, clock, tray, power button |
| Notifications and power menu | **off** | replaces your notification daemon |

Choose at install time (`--modules`) or later in the builder under *Settings → Modules*. Before the bar or the notification service is switched on, WidgetDeck looks for waybar, ags, eww, hyprpanel, dunst, mako, swaync and similar, tells you what to turn off first, and **never turns anything off itself**. Command line: `widgetdeck module bar on|off`.

The widgets work without the bar. Everything the bar offers is also reachable by IPC and optional key binds; the generated rules file contains commented examples:

```
bind = SUPER, W, exec, widgetdeck toggle                  # builder / edit mode
bind = SUPER SHIFT, P, exec, widgetdeck ipc powerPanel    # power menu
bind = SUPER, N, exec, widgetdeck ipc toggleDnd           # do not disturb
```

## First start and everyday use

* **Assistant:** wallpaper check (with a built-in file chooser if nothing is found), location, units (°C/°F, 24 h/12 h), glass style, widget size, which widgets. Skippable; run it again with `widgetdeck wizard` or in the settings.
* **Builder:** `widgetdeck builder` (or `widgetdeck toggle`). Drag widgets (Alt = free placement, Shift = multi-select), align and distribute, change the glass per widget, switch modules.
* **Liquid Glass** refracts your wallpaper, so it needs the wallpaper file. It is found automatically for awww, swww, hyprpaper, swaybg and wpaperd; otherwise choose a picture. If there is none (or the shader cannot be built) every widget uses Frosted Glass.
* **Check your setup:** `widgetdeck-doctor` prints OK / WARN / FAIL lines with a suggested fix (Hyprland version and config, Quickshell, shaders, packages, wallpaper detection, conflicts, sensors, network). Its output hides your home directory and prints no location or wallpaper path, so you can paste it into a GitHub issue.

## Updates and removal

```bash
widgetdeck-update              # shows the changes, asks, updates; settings are never touched
widgetdeck-update --rollback   # back to the previous version (and the settings backup)
./uninstall.sh                 # removes what was installed; asks before deleting your settings
```

Details (channels, migrations, local changes): see [README.de.md](README.de.md#updates) or run `widgetdeck-update --help`.

## Troubleshooting

| Problem | What to do |
|---|---|
| Nothing appears | `widgetdeck-doctor`. Is the daemon running (`widgetdeck status`)? Did you run `hyprctl reload`? Is `~/.local/bin` in your `PATH`? |
| Glass looks flat | Frosted: `decoration { blur { enabled = true } }` and the rules file included? Liquid: `widgetdeck-doctor` → shader / wallpaper lines; `pacman -S qt6-shadertools` |
| No icons / odd font | Icons are built in. For the font: `pacman -S adwaita-fonts` |
| Wrong weather location | Settings → Location: enter coordinates (or run the assistant again) |
| Builder window is tiled | The rules file is not included: re-run `./install.sh` |
| Two bars / no notifications | Another bar or notification daemon is running: the settings tell you which one |

## Licence and credits

Own code: MIT, see [LICENSE](LICENSE). The Liquid Glass shader is derived from `liquidglass.frag` of [MacShell](https://github.com/0-ss/MacShell) (MIT, © 2026 Rickky), see `NOTICE.md` and `LICENSES/`. Weather data: [Open-Meteo](https://open-meteo.com) (CC BY 4.0). Fonts and icon sets are not bundled; the icons are drawn for this project.

Contributing: [CONTRIBUTING.md](CONTRIBUTING.md) · Help: [SUPPORT.md](SUPPORT.md)
