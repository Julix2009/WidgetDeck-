# Änderungsprotokoll

Alle nennenswerten Änderungen an WidgetDeck stehen hier. Das Format folgt
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/), die Versionen folgen [Semantic Versioning](https://semver.org/lang/de/).

## [Unveröffentlicht]

### Hinzugefügt
- Widget „Stundenplan“ (WebUntis über den Untis-Mobile-Zugang des eigenen Kontos): aktuelle/nächste Stunde, Tag und Woche, Entfall/Vertretung/Prüfung, parallele Gruppen, Offline-Cache; Einrichtung mit `widgetdeck-untis-setup` (Schlüssel nur im Schlüsselbund), Prüfung in `widgetdeck-doctor`.
- Knöpfe „Small/Large“ für Widgets mit mehreren Größen; die Größe wechselt weich über Breite und Höhe.

## [0.2.0] - 2026-10-19

### Geändert
- Ansicht als gespeicherter Zustand, größere Klickflächen, Wochenende, Abruf-Warteschlange
- Bindungsschleife in der Fußzeile behoben
- Secret-Scan: Schema-Name des QR-Codes erlaubt (Schlüssel-/Host-Muster bleiben aktiv)
- Secret-Scan: Platzhalter-Servername erlaubt
- ISO-Zeiten, leere Zeitraster-Beschriftung, unveröffentlichte Folgewoche (-7004), Wochenraster ohne leere Zeilen; Setup-Skript wie Update-Befehl im Terminal
- Secret-Service-Erkennung korrigiert (kein Dienst = 'no')
- Widget Stundenplan (Untis Mobile): Client, Setup, Anzeige, Doku, Tests
- Reiner MIT-Text, damit GitHub die Lizenz erkennt (Hinweis zum Shader steht in NOTICE.md)

## [0.1.0] - 2026-10-18

### Hinzugefügt
- Desktop-Widgets für Hyprland mit Quickshell: Uhr, CPU/RAM, Musik, Visualizer, Netzwerk, Temperaturen, Systemstatus, Luftqualität und Wetter (mit Regen- und Schneepartikeln).
- Zwei Glas-Stile: Frosted Glass und Liquid Glass (Shader, mit Rückfall auf Frosted).
- Visueller Builder mit Raster, Hilfslinien, Mehrfachauswahl, Ausrichten und Verteilen.
- Installationsskript (`install.sh`) mit Paketprüfung, Hyprland-Regeldatei samt Backup, `--dry-run`, `--prefix` und Deinstallation.
- Wetter, Luftqualität und Standort über Open-Meteo (ohne API-Schlüssel); Einheiten und Sprache folgen dem System.
- Update-Weg: `widgetdeck-update`, Update-Hinweis in den Einstellungen, Migrationen für die Einstellungen und Rollback.
- Eigenständig ohne fremde Dotfiles: eigene Icons (keine Icon-Schrift nötig), Schrift-Fallback, feste Standard-Palette (Matugen optional), Wallpaper-Erkennung für awww, swww, hyprpaper, swaybg und wpaperd mit eigener Dateiauswahl.
- Module: Widgets, Builder, Leiste und Benachrichtigungen/Power-Menü (die beiden letzten standardmäßig aus); Warnung vor Konflikten, nichts wird je selbst beendet.
- Einrichtungsassistent beim ersten Start; `widgetdeck-doctor`; Oberfläche und Installer auf Englisch und Deutsch.
- Installer: Prüfung der Hyprland-Config per `--verify-config`, XDG-Pfade, Lua-Config, schreibgeschützte (Nix-)Configs werden nur angezeigt.
- LICENSE, CONTRIBUTING, SUPPORT, Issue-Vorlage und GitHub-Prüfungen (shellcheck, qmllint, Übersetzungen, Secret-Scan).
