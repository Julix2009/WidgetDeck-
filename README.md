<div align="center">

<img src="docs/images/logo.svg" width="128" alt="">

# WidgetDeck

**Desktop widgets for Hyprland that you put together with the mouse.**<br>
Clock, weather, music, system stats, timetable, Formula 1 and more, in three styles,<br>
with colours that follow your wallpaper or your shell. Built with Quickshell.

![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00a8cc)
![Quickshell](https://img.shields.io/badge/Quickshell-QML-41cd52)
![Arch Linux](https://img.shields.io/badge/Arch-Linux-1793d1)
![License](https://img.shields.io/badge/license-MIT-555555)
![Status](https://img.shields.io/badge/status-hobby%20project-d9a030)

<a href="#installation"><b>Installation</b></a>

</div>

---

### Liquid Glass

![Liquid Glass](docs/images/stil-liquid.webp)

### Frosted Glass

![Frosted Glass](docs/images/stil-frosted.webp)

### Solid

![Solid](docs/images/stil-solid.webp)

<sub>Demo data. Wallpaper: <a href="https://commons.wikimedia.org/wiki/File:Hakkoda_Mountains,_Part_II-_Foothills_-_Hakkoda6929.jpg">Hakkoda Mountains</a> by lumoplank, CC0.</sub>

## More variants

The pictures show only one look per widget. Several widgets come in more designs, which you can flip through with the arrows in the library:

| Widget | Variants |
|---|---|
| Clock | 7: digital, flower (analogue), poster, greeting card, stacked, day ring, pixel |
| Music | 7: normal, turntable, poster, spinning disc, typography, cassette, capsule |
| Formula 1 | 6: classic card, circuit, big countdown, start lights, standings tower, race ticket |
| Visualizer | 3: bars, mirrored, line |
| CPU & RAM, Temperatures | 2: rings, bars |

## Installation

For **Arch Linux** with **Hyprland** only.

```bash
git clone https://github.com/Julix2009/WidgetDeck-.git
cd WidgetDeck-
./install.sh
```

Then:

```bash
hyprctl reload
widgetdeck builder
```

Update with `widgetdeck-update`, remove with `./uninstall.sh`. `./install.sh --dry-run` only shows what would happen.

## Thanks

<sub>Liquid Glass shader derived from <a href="https://github.com/0-ss/MacShell">MacShell</a> (MIT) · F1 track outlines from <a href="https://github.com/bacinger/f1-circuits">bacinger/f1-circuits</a> (MIT) · Built with <a href="https://quickshell.org">Quickshell</a><br>
Data: <a href="https://open-meteo.com">Open-Meteo</a> (weather, air quality) · <a href="https://api.jolpi.ca/ergast/f1/">Jolpica-F1</a> and <a href="https://openf1.org">OpenF1</a> (Formula 1) · <a href="https://lrclib.net">LRCLIB</a> (lyrics) · <a href="https://ipwho.is">ipwho.is</a> (location) · GitHub (contribution calendar)</sub>

---

<sub>[All widgets](docs/widgets.md) · [Troubleshooting](docs/troubleshooting.md) · [Contributing](CONTRIBUTING.md) · [MIT](LICENSE) · [Notices](NOTICE.md)<br>
Unofficial hobby project, not affiliated with Formula 1, Untis, Apple or any other trademark owner named here.</sub>
