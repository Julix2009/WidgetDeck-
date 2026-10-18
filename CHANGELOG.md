# Änderungsprotokoll

Alle nennenswerten Änderungen an WidgetDeck stehen hier. Das Format folgt
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/), die Versionen folgen [Semantic Versioning](https://semver.org/lang/de/).

## [Unveröffentlicht]

## [0.1.0] - 2026-10-18

### Hinzugefügt
- Desktop-Widgets für Hyprland mit Quickshell: Uhr, CPU/RAM, Musik, Visualizer, Netzwerk, Temperaturen, Systemstatus, Luftqualität und Wetter (mit Regen- und Schneepartikeln).
- Zwei Glas-Stile: Frosted Glass und Liquid Glass (Shader, mit Rückfall auf Frosted).
- Visueller Builder mit Raster, Hilfslinien, Mehrfachauswahl, Ausrichten und Verteilen.
- Installationsskript (`install.sh`) mit Paketprüfung, Hyprland-Regeldatei samt Backup, `--dry-run`, `--prefix` und Deinstallation.
- Wetter, Luftqualität und Standort über Open-Meteo (ohne API-Schlüssel); Einheiten und Sprache folgen dem System.
- Update-Weg: `widgetdeck-update`, Update-Hinweis in den Einstellungen, Migrationen für die Einstellungen und Rollback.
