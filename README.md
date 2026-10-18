# WidgetDeck

Desktop-Widgets für **Hyprland** mit Quickshell: Uhr, CPU/RAM, Musik, Visualizer, Netzwerk, Temperaturen, Systemstatus, Luftqualität und Wetter (mit Regen- und Schneepartikeln) – im Look **Frosted Glass** oder **Liquid Glass**. Alles lässt sich in einem eingebauten **Builder** per Maus anordnen: Raster, Hilfslinien, Mehrfachauswahl, Ausrichten und Verteilen.

> Screenshots sind absichtlich noch nicht dabei (sie dürfen keine persönlichen Daten zeigen). Lege eigene Bilder in `docs/` ab, sobald du welche hast.

## Voraussetzungen

* Arch Linux (oder ein Derivat), nicht als root
* **Hyprland** – getestet mit 0.55.4 (Lua- und `.conf`-Config). Ab 0.53 wird die neue Regel-Syntax geschrieben, davor die alte (ungetestet).
* **Quickshell** – getestet mit 0.3.0, dazu Qt 6.11 (mindestens Qt 6.7)
* Eine GPU mit Vulkan/OpenGL-Treiber. Liquid Glass ist ein Shader und braucht etwas GPU-Leistung; ohne funktionierenden Shader fällt WidgetDeck automatisch auf Frosted Glass zurück.

Pakete (alle aus den offiziellen Repos, **kein AUR nötig**):

| Zweck | Pakete |
|---|---|
| Pflicht | `quickshell qt6-declarative qt6-wayland qt6-shadertools jq curl iproute2 iputils` |
| Empfohlen (Schrift/Icons) | `adwaita-fonts ttf-iosevka-nerd` |
| Optional | `networkmanager` (WLAN-Name), `playerctl` (Musik-Tasten), `cava` (Visualizer), `matugen` (Farben aus dem Wallpaper) |

Der Installer prüft das und installiert Fehlendes nach deiner Bestätigung mit **einem** `pacman`-Aufruf.

## Installation

```bash
git clone https://github.com/<Benutzer>/widgetdeck && cd widgetdeck && ./install.sh
```

Das Skript fragt vor jeder Änderung an Dingen, die dir gehören. Nützliche Optionen:

| Option | Wirkung |
|---|---|
| `--dry-run` | zeigt nur, was passieren würde |
| `--yes` | keine Rückfragen (Standardantworten) |
| `--no-hypr-config` | Hyprland-Config wird nicht angefasst, die nötigen Zeilen werden nur angezeigt |
| `--no-packages` | Paketprüfung überspringen |
| `--prefix <Pfad>` | Test-Installation in einen anderen „Home“-Ordner |
| `--uninstall` | wieder entfernen (siehe unten) |

Was passiert wo:

| Was | Ort |
|---|---|
| Programm (wird bei Updates ersetzt) | `~/.config/quickshell/widgetdeck/` |
| Starter | `~/.local/bin/widgetdeck` |
| **Deine Einstellungen** (Layout, Glas-Regler, Standort) | `~/.config/widgetdeck/` – wird **nie** überschrieben |
| Hyprland-Regeln | `~/.config/hypr/widgetdeck.conf` (bzw. `.lua`) plus **eine** markierte Zeile in deiner `hyprland.conf`/`hyprland.lua` – vorher mit Zeitstempel-Backup |
| Cache, Log | `~/.cache/widgetdeck/` (`install.log`) |

Deine Hyprland-Hauptconfig wird nur angefasst, wenn du zustimmst. Die Zeile steht zwischen `>>> widgetdeck` und `<<< widgetdeck`. Wer lieber selbst einträgt, nimmt `--no-hypr-config`.

Der Installer warnt, wenn er `waybar`, `eww`, `ags`, `conky`, `dunst`, `mako` oder `swaync` findet. Er beendet nichts. WidgetDeck zeichnet nur Widgets auf dem Desktop (unterste Ebene) und braucht weder Bar noch Benachrichtigungsdienst.

## Erster Start

```bash
hyprctl reload          # lädt die neuen Regeln (oder neu anmelden: dann startet WidgetDeck von selbst)
widgetdeck builder      # startet die Widgets und öffnet den Builder
widgetdeck doctor       # prüft Pakete, Schrift, Shader, Standort
```

Beim ersten Start entsteht ein Standard-Layout (Uhr, CPU/RAM, Musik, Visualizer).

## Bedienung

* **Widgets anzeigen/verstecken:** im Builder links „Widgets“ – Karte anklicken fügt hinzu, im Eigenschaften-Panel gibt es „Löschen“. `widgetdeck toggle` öffnet/schließt den Builder; ohne Builder sind die Widgets reine Anzeige (Mausklicks gehen durch).
* **Bearbeiten & Raster:** solange der Builder offen ist, kannst du Widgets ziehen und skalieren. Sie rasten am Raster ein (**Alt** gedrückt halten = freies Verschieben, Shift = Mehrfachauswahl), dazu gibt es Hilfslinien an Kanten, Mitten und gleichen Abständen. Mehrfachauswahl, Ausrichten und Verteilen findest du im Panel „Raster & Ausrichten“.
* **Liquid Glass bearbeiten:** Widget auswählen → „Glas-Stil“ → *Liquid*. Dort stellst du Brechung, Weichzeichnung, Glanz, Lichtrichtung, Tönung usw. ein. Die Werte gelten pro Widget. Unter „Hintergrund des Glases“ siehst du, welches Wallpaper erkannt wurde, und kannst den Pfad überschreiben.
* **Standort & Einheiten:** Builder → Einstellungen → „Standort & Einheiten“. Entweder Breite/Länge eintragen oder die automatische Bestimmung per IP nutzen. Einheiten (°C/°F, km/h/mph) und Sprache folgen standardmäßig deinem System.
* **Farben aus dem Wallpaper** (optional, mit `matugen`): der Installer bietet an, eine Vorlage einzutragen. Ohne matugen wird die eingebaute Palette benutzt.
* **Hardware fehlt?** Kein Sensor/Lüfter/WLAN: das Feld fehlt einfach oder zeigt „Ethernet“/„Offline“; nichts wird erfunden.

## Updates

```bash
cd widgetdeck && ./update.sh      # git pull + Programmdateien neu installieren
```

Deine Einstellungen bleiben unverändert. Wurde die Regeldatei in `~/.config/hypr/` von dir geändert, wird sie nicht überschrieben; die neue Fassung liegt dann daneben (`*.new`).

## Deinstallation

```bash
./uninstall.sh          # entfernt nur, was installiert wurde; fragt, ob deine Einstellungen gelöscht werden sollen
```

Die Hyprland-Config wird aus dem Backup zurückgesetzt (wenn du sie seitdem nicht geändert hast; sonst wird nur die markierte Zeile entfernt). Mit `--purge` gehen auch Einstellungen und Cache weg.

## Optional: als Paket

Statt `install.sh` kann man auch ein Arch-Paket bauen: `cd packaging && makepkg -si`. Es installiert nach `/usr/share/widgetdeck` und `/usr/bin/widgetdeck`. Hyprland-Regeln werden dabei **nicht** automatisch eingetragen – Vorlagen liegen in `/usr/share/widgetdeck/hypr/` (`@BIN@` durch `/usr/bin/widgetdeck` ersetzen). Das Paket ist nicht im AUR; `install.sh` bleibt der Standardweg.

## Bekannte Probleme

* **Shader:** Wenn `qsb` fehlt oder der Shader nicht kompiliert, erscheint Frosted Glass statt Liquid Glass (Details: `~/.cache/widgetdeck/install.log`, `widgetdeck log`).
* **Liquid Glass sieht dein Wallpaper nur als Datei.** Es liest das Bild aus awww/swww, hyprpaper oder swaybg; bei anderen Tools den Pfad im Builder setzen (Einstellungen → „Hintergrund des Glases“ → Wallpaper-Pfad überschreiben). Liegt nicht das echte Wallpaper dahinter, wirkt das Glas „falsch“.
* **Standort:** Ohne Standort zeigen Wetter und Luftqualität einen Hinweis. Die IP-Ortung ist grob (oft nur die Region des Anbieters).
* **Sprache:** Die Oberfläche ist deutsch; Wetterbeschreibungen gibt es deutsch und englisch. Eine vollständige Übersetzung gibt es nicht.
* Getestet wurde nur mit Hyprland 0.55.4 / Quickshell 0.3.0 / Qt 6.11.1 und Intel-GPU.

## Fehlersuche

| Problem | Lösung |
|---|---|
| Es erscheint nichts | `widgetdeck doctor`; läuft der Daemon? `widgetdeck daemon` im Terminal zeigt Fehler. Wurde `hyprctl reload` ausgeführt? `~/.local/bin` im `PATH`? |
| Glas sieht flach/matt aus | Frosted: in Hyprland `decoration { blur { enabled = true } }` prüfen und ob die Regeldatei eingebunden ist. Liquid: `widgetdeck doctor` → Shader kompiliert? Sonst `pacman -S qt6-shadertools`, danach `./install.sh` und `widgetdeck restart` |
| Wetter zeigt den falschen Ort | Builder → Einstellungen → Standort: Breite/Länge eintragen (löscht die automatische Bestimmung) oder `rm ~/.cache/widgetdeck/location.json` |
| Das Wetter fehlt ganz | Kein Internet, oder kein Standort gesetzt. `bash ~/.config/quickshell/widgetdeck/widgets/sysmon/weather.sh` zeigt die Rohdaten |
| Symbole sind Kästchen | `pacman -S ttf-iosevka-nerd`, `fc-cache`, `widgetdeck restart` |
| Doppelt gestartet | Autostart steht schon in deiner eigenen Hyprland-Config: einen entfernen |

## Lizenzen & Danksagung

* Der Liquid-Glass-Shader ist eine **abgeleitete Arbeit** von `liquidglass.frag` aus [MacShell](https://github.com/0-ss/MacShell) (MIT, © 2026 Rickky). Lizenztext: `LICENSES/MIT-MacShell.txt`; Herkunft aller Teile: `NOTICE.md`.
* Wetter und Luftqualität: [Open-Meteo](https://open-meteo.com) (CC BY 4.0). Optionale Ortung: ipwho.is.
* Schriften und Icons werden nicht mitgeliefert, sondern per Paket installiert.
* Lizenz des eigenen Codes: siehe `LICENSE` (falls noch nicht vorhanden, ist sie noch nicht festgelegt).
