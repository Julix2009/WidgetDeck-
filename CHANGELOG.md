# Änderungsprotokoll

Alle nennenswerten Änderungen an WidgetDeck stehen hier. Das Format folgt
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/), die Versionen folgen [Semantic Versioning](https://semver.org/lang/de/).

## [Unveröffentlicht]

### Hinzugefügt
- Neues Widget „System-Info“ im Stil von fastfetch (System, Kernel, Laufzeit, Pakete, CPU, GPU, RAM, Speicher, kleines Logo, Farbblöcke) mit Liquid Glass; braucht `fastfetch`, das der Installer optional anbietet.
- Widget „Stundenplan“ (WebUntis über den Untis-Mobile-Zugang des eigenen Kontos): aktuelle/nächste Stunde, Tag und Woche, Entfall/Vertretung/Prüfung, parallele Gruppen, Offline-Cache; Einrichtung mit `widgetdeck-untis-setup` (Schlüssel nur im Schlüsselbund), Prüfung in `widgetdeck-doctor`.
- Knöpfe „Small/Large“ für Widgets mit mehreren Größen; die Größe wechselt weich über Breite und Höhe.
- Liquid Glass: optionale „Kantenlinse“ (Stärke, Kantenbiegung, Regenbogensaum, Tönung) – der Rand biegt den Hintergrund wie ein Wassertropfen; neue Presets „Crystal“ und „Water drop“. Ältere Widgets bleiben unverändert (Stärke 0).

### Geändert
- Schärfe: Bei gebrochener Skalierung (zum Beispiel 1,25 oder 1,5) liegen Widget-Fenster jetzt auf ganzen physischen Pixeln (Position und Größe werden auf den kleinsten passenden Schritt gerundet, gespeichert wird nichts Neues), und die Glas-Texturen nutzen das echte Pixelverhältnis des Fensters statt der gerundeten Bildschirmangabe. Das Wetter-Karten-Widget lädt seine Icons nicht mehr zu groß.
- README und Widget-Dokumentation auf den aktuellen Stand gebracht (Version, Schulfortschritt, Kantenlinse und Presets, Stil kopieren und einfügen, Builder wird nur bei Bedarf geladen); Bilder unverändert.
- Speicher: Der Builder wird nur noch geladen, solange er geöffnet ist (LazyLoader). Geschlossen spart das rund 20 MB, geöffnet-und-wieder-geschlossen gibt es etwa 50 MB frei; Funktion und Aussehen bleiben gleich.
- Builder: Werkzeugleiste der Fläche bricht bei schmalem Fenster um, lange Hinweis- und Widget-Namen werden gekürzt statt abgeschnitten; Preset-Knöpfe umbrechen.

## [0.9.0] - 2026-11-08

### Geändert
- Untis-Mock hält 'nächste Woche' wochentagsunabhängig für unveröffentlicht (schlug sonntags fehl)
- README (de/en) und widgets.md auf den aktuellen Stand, bestehende Bilder bleiben
- Builder wird nur noch geladen, solange er offen ist (LazyLoader)
- Liquid Glass: Kantenlinse (Wassertropfen-Look) + Builder-Layout ohne abgeschnittene Elemente
- Stil kopieren/einfügen per Shortcut (Strg+Umschalt+C/V und Strg+C/V), unabhängig davon, welches Element den Fokus hat

## [0.8.0] - 2026-11-04

### Geändert
- Stil kopieren und einfügen (Knöpfe im Glas-Bereich und Strg+Umschalt+C / V), auf mehrere markierte Widgets gleichzeitig

## [0.7.0] - 2026-11-04

### Geändert
- Netzwerk-Widget: alle Farben einstellbar (Download, Upload, WLAN, Ping, Fehler), Theme-Rolle oder eigene Farbe

## [0.6.0] - 2026-11-03

### Hinzugefügt
- Neues Widget Schulfortschritt: Prozent vom Schultag oder von der Schulwoche, gezählt in Stunden des Stundenplans

### Geändert
- README überarbeitet (de/en), docs/ ergänzt, neue Screenshots

## [0.5.0] - 2026-10-23

### Geändert
- Focus-timer: findet die QML-Dateien auch über einen Symlink (Entwickler-Installationen)
- Fokus-Timer: Installer, Deinstallation, Doctor, Tastenkürzel-Vorschläge, README (de/en), NOTICE, CI und Bilder-Skript
- Fokus-Timer: Widget (Ring, Klein/Groß aus der Größen-Tabelle), geteilte Einstellungen (shared) und Texte
- Fokus-Timer: gemeinsamer Dienst (Singleton) mit gespeichertem Zustand, Statistik, Ton, Benachrichtigung und Nicht-stören (WidgetDeck, dunst, mako, swaync, Flag-Datei); IPC-Target focustimer und Befehl focus-timer
- Fokus-Timer: Logik ohne UI (Phasen, Zielzeitpunkt, Wiederherstellung nach Neustart/Standby, Statistik) mit Tests und selbst erzeugtem Ton
- Tools/nested: nie auf die neueste Hyprland-Sitzung ausweichen (konnte die eigene sein); jede Hilfsfunktion sucht die verschachtelte Sitzung neu
- Qsgtiming.sh (Bilder pro Sekunde und Bildzeit über QSG_RENDER_TIMING)
- Bildvergleich (visual-regression.sh) mit gemessener Maske der beweglichen Teile; Animationen über Größen-Zeitverläufe
- Messwerkzeug (Speicher, CPU, Aufwachvorgänge, GPU, Prozess-Starts) für den Test-Aufbau; env.sh findet mehrere verschachtelte Sitzungen

## [0.4.0] - 2026-10-21

### Geändert
- Formel-1-Widget (inoffiziell): nächstes Rennwochenende mit Streckenumriss, Countdown, allen Sessions in Ortszeit, Ergebnis und Wertung
- Größen-Animation: eine zweite Animation stoppt die erste nicht mehr auf halbem Weg
- Linke Widget-Liste scrollt (Scrollbalken), damit auch 'Auf dem Desktop' erreichbar bleibt

## [0.3.0] - 2026-10-21

### Geändert
- Mehrere Monitore: Erkennung mit stabiler Kennung, Monitor-Wahl im Builder, Zuordnung und Layout pro Monitor, Hotplug, Glas pro Monitor, gemeinsame Daten-Feeds
- Wetter-Karte: Icons als echte 3D-Renderings (Blender/Cycles), Ebenen aus 5x3 Blickwinkeln, Hover-Drehung, Schlagschatten, Abschneiden behoben
- Wetter-Karte: neues Widget mit 3D-Icons (Sprite-Ebenen aus eigenem SDF-Renderer), Stunden- und Tagesliste, gemeinsame Daten mit dem Wetter-Widget

## [0.2.1] - 2026-10-19

### Geändert
- Secret-Scan ignoriert generische Konten (root), gitleaks erlaubt den öffentlichen RFC-6238-Testschlüssel
- Musik-Widget: zweiter Stil "Schallplattenspieler"

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
