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
| `--channel stable` | Update-Kanal: nur getaggte Releases (Standard: `main`, immer der neueste getestete Stand) |
| `--prefix <Pfad>` | Test-Installation in einen anderen „Home“-Ordner |
| `--uninstall` | wieder entfernen (siehe unten) |

Was passiert wo:

| Was | Ort |
|---|---|
| Programm (wird bei Updates ersetzt) | `~/.config/quickshell/widgetdeck/` |
| Starter und Update-Befehl | `~/.local/bin/widgetdeck`, `~/.local/bin/widgetdeck-update` |
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
widgetdeck-update
```

Der Befehl wird bei der Installation nach `~/.local/bin` gelegt. Er holt den Remote-Stand, zeigt die **Änderungen seit deiner Version** (aus dem Änderungsprotokoll) und fragt, ob aktualisiert werden soll. Danach werden Programmdateien ersetzt, der Shader neu vorkompiliert, fehlende Pakete nach Rückfrage über `pacman` nachinstalliert und die Widgets neu gestartet.

| Befehl | Wirkung |
|---|---|
| `widgetdeck-update --yes` | ohne Rückfrage |
| `widgetdeck-update --dry-run` | zeigt nur, was passieren würde |
| `widgetdeck-update --channel stable` | ab jetzt nur getaggte Releases (`--channel main` = immer der neueste Stand, Standard) |
| `widgetdeck-update --version v0.2.0` | eine bestimmte Version installieren |
| `widgetdeck-update --rollback` | zurück auf die Version vor dem letzten Update, inklusive Backup der Einstellungen |

**Deine Einstellungen bleiben erhalten.** Ein Update berührt nur Programmdateien. Alles in `~/.config/widgetdeck/` (Layout, Positionen, Glas-Regler, Standort) bleibt, wie es ist. Ändert sich das Format, laufen nummerierte Migrationen (`migrations/`) automatisch in der richtigen Reihenfolge – vorher entsteht ein Backup `~/.config/widgetdeck.bak-<Datum>`, und fehlende neue Einstellungen werden mit Standardwerten ergänzt, ohne vorhandene zu überschreiben. Schlägt etwas fehl, wird die vorherige Version samt Einstellungen automatisch wiederhergestellt.

**Eigene Änderungen an Dateien** im geklonten Ordner erkennt das Skript: Es bietet an, sie per `git stash` zu sichern oder als Kopie mit Zeitstempel abzulegen, und aktualisiert erst danach. Selbst bearbeitete installierte Programmdateien werden vor dem Ersetzen nach `~/.cache/widgetdeck/program-backup-<Datum>` kopiert. Änderungen an den Hyprland-Regeln landen nur in `~/.config/hypr/widgetdeck.conf` (bzw. `.lua`), nie in deiner Hauptconfig.

**Hinweis in der Oberfläche:** Im Builder unter *Einstellungen → Version & Updates* steht die Version, daneben „Auf Updates prüfen“. Gibt es eine neuere Version, erscheint „Update verfügbar“ mit dem Änderungsprotokoll-Auszug und einem Knopf, der `widgetdeck-update` in einem Terminal öffnet. Die Prüfung läuft im Hintergrund höchstens einmal pro Tag (`git ls-remote`, ohne API-Token), blockiert nichts und bleibt still, wenn du offline bist oder keinen Zugriff auf das Repository hast. Es wird **nie** automatisch installiert. Abschalten: Schalter „Täglich nach Updates suchen“ oder `"update": { "check": false }` in `~/.config/widgetdeck/config.json`.

## Deinstallation

```bash
./uninstall.sh          # entfernt nur, was installiert wurde; fragt, ob deine Einstellungen gelöscht werden sollen
```

Die Hyprland-Config wird aus dem Backup zurückgesetzt (wenn du sie seitdem nicht geändert hast; sonst wird nur die markierte Zeile entfernt). Mit `--purge` gehen auch Einstellungen und Cache weg.

## Für Betreuer: neue Version veröffentlichen

Im geklonten Repo, auf dem Branch `main` und mit sauberem Arbeitsbaum:

```bash
./release.sh patch      # Fehlerbehebung 0.1.0 -> 0.1.1   (minor: neue Funktion, major: grundlegende Änderung)
```

Das Skript prüft zuerst `shellcheck`, einen Secret-Scan (`tools/secret-scan.sh`: persönliche Pfade, Tokens, Koordinaten und alle Wörter aus der nicht eingecheckten Datei `.release-denylist`, über Dateien **und** Historie) und die Raster-Tests. Dann erhöht es `VERSION`, schreibt aus den Commit-Nachrichten einen Entwurf für `CHANGELOG.md` (Präfixe `feat:`/`fix:` sortieren nach *Hinzugefügt*/*Behoben*, alles andere nach *Geändert*; der Entwurf öffnet sich im `$EDITOR`), zeigt Version, Änderungen und geänderte Dateien und fragt. Erst nach „j“ wird committet, mit `vX.Y.Z` getaggt und `main` samt Tag gepusht. `./release.sh patch --dry-run` zeigt nur, was passieren würde. Die allererste Veröffentlichung (Version steht schon in `VERSION`): `./release.sh current`.

* Ändert sich das Format der Einstellungen, lege vorher `migrations/000N_name.sh` an (Vorlage und Regeln: `migrations/README.md`) und erhöhe damit die Schema-Nummer.
* `shellcheck` und `gitleaks` installierst du mit `sudo pacman -S shellcheck gitleaks`. Nur wenn das nicht geht: `--no-shellcheck` (wird in der Zusammenfassung vermerkt).
* Commits tragen deine Git-Identität. Wer seine private Adresse nicht öffentlich haben will, nutzt die GitHub-`noreply`-Adresse (`git config user.email <id>+<name>@users.noreply.github.com`).

**Fehler in einem Release zurücknehmen:** Lösche den Tag nicht heimlich, sondern behebe den Fehler mit einem normalen Commit (`git revert <commit>` oder ein Fix) und veröffentliche sofort ein neues Patch-Release mit `./release.sh patch`. Wer das fehlerhafte Release schon hat, bekommt den Fix mit `widgetdeck-update`, oder geht mit `widgetdeck-update --rollback` auf den Stand davor zurück. Nur wenn ein Release gar nicht erscheinen durfte (etwa weil es ein Geheimnis enthielt): Tag entfernen (`git push origin :refs/tags/vX.Y.Z`), Geheimnis sofort ungültig machen und die Historie bereinigen – ein Secret gilt nach dem Push als bekannt.

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
