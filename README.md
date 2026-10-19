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

## Music widget: two styles

![Music: Normal and Turntable (Liquid Glass)](docs/music-turntable.png)
_Demo data (invented), neutral wallpaper._

The music widget shows the current track of any MPRIS player. Its option **Style** (widget properties in the builder) switches live, with a crossfade, between **Normal** (cover, progress bar, buttons) and **Turntable**: a spinning record with grooves and the cover as its label, a tonearm that swings onto the record when playback starts, follows the progress and lifts off on pause or when the track changes, and title / artist / time / buttons next to it (small size: below, buttons on hover). Clicking the record or the arm toggles play / pause. Options for the turntable: speed (33 / 45 RPM), tonearm follows the progress, vinyl colour (black / from the cover), light reflection. Both styles read the same state; the glass behind is the shared glass panel in both. Nothing runs while paused, without a player or while the widget is not visible. Use the *Small / Large* buttons in the builder for the sizes of the chosen style.

## Timetable widget (WebUntis / Untis Mobile)

![Timetable: Liquid Glass and Frosted Glass](docs/timetable-liquid.png)
![Timetable: Frosted Glass](docs/timetable-frosted.png)
![Timetable: week](docs/timetable-week.png)
_Demo data (invented), neutral wallpaper._

Shows your own WebUntis timetable: the running and the next lesson (small layout), or a day timeline and a week grid (large layout, drag the widget bigger or use the *Small / Large* buttons in the builder). Cancellations are struck through in red, substitutions are green, exams yellow; parallel groups are folded (`+2 parallel`, choose your own group in the widget properties); breaks, free periods, weekends and holidays are recognised from the school's own time grid.

It uses the **Untis Mobile access** of your own account - the only access many schools offer, because the normal login is often behind a Microsoft login. Set it up once:

1. In WebUntis open *Profile → Releases → Untis Mobile → Show* (the QR code). Save a screenshot or photo of it **locally**.
2. Run `widgetdeck-untis-setup` and give the path of the image when asked (or type the values by hand). It reads the QR code with `zbarimg` (package `zbar`), checks the access with one login, and stores the key in your **keyring** (Secret Service, via `secret-tool` from `libsecret`).
3. Let the setup delete the image and remove other copies (Downloads, trash, cloud sync). Anyone with the image can read your timetable.
4. Add the *Timetable* widget in the builder (or tick it in the first-run assistant).

Packages (official repositories): `python`, `zbar`, `libsecret`, plus a running Secret Service (gnome-keyring, KeePassXC with Secret Service enabled, KWallet). Without a Secret Service the setup offers a private file (`chmod 600`) outside the repository - only if you agree.

**What it reads:** only your own timetable (lessons, cancellations, substitutions, room, teacher and class short names, group, a short note, exam marking) and the school's time grid, via the Untis Mobile interface (`getUserData2017`, `getTimetable`). **What it never reads:** marks, absences, homework, messages, student numbers, names or e-mail addresses (such text is removed before anything is stored). Data is fetched every 15 minutes while the widget is visible, kept in a cache with a timestamp (`~/.cache/widgetdeck/timetable.json`, mode 600), and shown as "As of HH:MM" when you are offline. The key never appears in code, config, logs or the command line: the server only receives a one-time code computed from it, over HTTPS with certificate verification. If the key is revoked ("log out devices" in WebUntis) the widget shows "Access expired - please set it up again" and keeps the last data. `widgetdeck-untis-setup --remove` deletes the key and the cache.

The interface is the one of the Untis Mobile app; it is not officially documented and a school may disable it. If your school does not allow it, the setup says so ("The server refused the access") and nothing is stored. `widgetdeck-doctor` checks the Secret Service, whether a key exists (yes/no), whether the server answers and whether the last fetch worked. For screenshots and tests the widget has a data source *Demo (invented lessons)*.

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
