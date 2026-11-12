# Änderungsprotokoll

Alle nennenswerten Änderungen an WidgetDeck stehen hier. Das Format folgt
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/), die Versionen folgen [Semantic Versioning](https://semver.org/lang/de/).

## [Unveröffentlicht]

### Hinzugefügt
- Neue README (Deutsch und Englisch) mit Galerie und neuen Bildern: Gesamtansichten in Liquid Glass (Preset Wassertropfen) und Frosted Glass, Builder mit Glas-Panel und eigenen Presets sowie Bilder zu Songtext und System-Info (alle mit erfundenen Demo-Daten und selbst erzeugtem Wallpaper).
- Songtext: Einstellung „Wort für Wort aufleuchten“ (Standard an): Die Wörter der gesungenen Zeile leuchten nacheinander auf; das Timing ist aus der Länge der Wörter geschätzt, weil LRCLIB nur den Zeilenanfang kennt.
- Neues Widget „Songtext“: zeigt nur den Text des laufenden Lieds, synchron zur Wiedergabe – die gesungene Zeile leuchtet hell auf, die anderen sind gedimmt, der Text scrollt mit (Quelle: LRCLIB, ein Abruf pro Lied, lokal zwischengespeichert; Position vom MPRIS-Player). Mit der Einstellung „Nur Text (ohne Glas-Behälter)“ steht der Text frei auf dem Wallpaper; jedes Widget kann diese Einstellung über den Schlüssel `no_glass` anbieten.
- Builder: eigene Glas-Presets speichern, anwenden und löschen (*Aktuellen Look als Preset speichern*; in `config.json` unter `user_presets`).
- Visualizer: Einstellung „Flüssigkeit (Bilder pro Sekunde)“ (20, 30, 45, 60; Standard jetzt 30 statt 45).
- Neues Widget „System-Info“ im Stil von fastfetch (System, Kernel, Laufzeit, Pakete, CPU, GPU, RAM, Speicher, kleines Logo, Farbblöcke) mit Liquid Glass; braucht `fastfetch`, das der Installer optional anbietet.
- Widget „Stundenplan“ (WebUntis über den Untis-Mobile-Zugang des eigenen Kontos): aktuelle/nächste Stunde, Tag und Woche, Entfall/Vertretung/Prüfung, parallele Gruppen, Offline-Cache; Einrichtung mit `widgetdeck-untis-setup` (Schlüssel nur im Schlüsselbund), Prüfung in `widgetdeck-doctor`.
- Knöpfe „Small/Large“ für Widgets mit mehreren Größen; die Größe wechselt weich über Breite und Höhe.
- Liquid Glass: optionale „Kantenlinse“ (Stärke, Kantenbiegung, Regenbogensaum, Tönung) – der Rand biegt den Hintergrund wie ein Wassertropfen; neue Presets „Crystal“ und „Water drop“. Ältere Widgets bleiben unverändert (Stärke 0).

### Geändert
- Widgets nach dem Start zu groß (Fortsetzung): Direkt nach dem Boot kann Qt einen veralteten Bildschirm melden (z. B. 1463×914, also Skalierung 1,75) während Hyprland längst 1,25 hat. WidgetDeck prüft jetzt, ob Größe und Skalierung zu den Angaben von hyprctl passen, veröffentlicht widersprüchliche Daten nie (so wird auch das gespeicherte Layout nicht verfälscht) und startet sich nach 8 Sekunden Widerspruch selbst neu, höchstens zweimal innerhalb von 5 Minuten.
- Widgets nach dem Start zu groß: Ein Widget-Fenster, das erzeugt wurde, als der Monitor noch eine andere Skalierung hatte (nach Boot, Login oder Standby), behielt diese Skalierung und wurde um den Unterschied zu groß oder zu klein gezeichnet (1,75 gegen 1,25 ergibt Faktor 1,4). WidgetDeck vergleicht jetzt das Pixelverhältnis jedes Fensters mit der Skalierung, die Hyprland meldet, und erzeugt das Fenster bei Abweichung neu (höchstens dreimal pro Fenster).
- Monitore: Eine Änderung von Größe, Skalierung oder Anzahl der Monitore wird erst übernommen, wenn sie 2 Sekunden unverändert bleibt. Direkt nach dem Aufwachen aus dem Standby melden Quickshell und Hyprland kurz halb aktualisierte Werte; das hat die Widgets zuvor dauerhaft zu groß gemacht (bis zum Neustart von WidgetDeck).
- Stundenplan: Schlägt der Abruf fehl und es gibt noch keine gespeicherten Daten (zum Beispiel, weil das Netz direkt nach dem Login noch nicht steht), versucht das Widget es nach 30 Sekunden, 1, 2 und höchstens 5 Minuten erneut, statt 15 Minuten zu warten.
- Weniger Last und Speicher: Der Visualizer startet `cava` nur, solange das Widget sichtbar ist und läuft mit 30 statt 45 Bildern pro Sekunde; das Hintergrundbild des Liquid Glass wird nicht größer decodiert als die Textur, in der es landet (rund 5 MB weniger bei fünf Widgets).
- Builder: Namen und Beschreibungen in der Widget-Liste werden übersetzt.
- Schärfe: Bei gebrochener Skalierung (zum Beispiel 1,25 oder 1,5) liegen Widget-Fenster jetzt auf ganzen physischen Pixeln (Position und Größe werden auf den kleinsten passenden Schritt gerundet, gespeichert wird nichts Neues), und die Glas-Texturen nutzen das echte Pixelverhältnis des Fensters statt der gerundeten Bildschirmangabe. Das Wetter-Karten-Widget lädt seine Icons nicht mehr zu groß.
- README und Widget-Dokumentation auf den aktuellen Stand gebracht (Version, Schulfortschritt, Kantenlinse und Presets, Stil kopieren und einfügen, Builder wird nur bei Bedarf geladen); Bilder unverändert.
- Speicher: Der Builder wird nur noch geladen, solange er geöffnet ist (LazyLoader). Geschlossen spart das rund 20 MB, geöffnet-und-wieder-geschlossen gibt es etwa 50 MB frei; Funktion und Aussehen bleiben gleich.
- Builder: Werkzeugleiste der Fläche bricht bei schmalem Fenster um, lange Hinweis- und Widget-Namen werden gekürzt statt abgeschnitten; Preset-Knöpfe umbrechen.

## [1.0.0] - 2026-11-12

### Hinzugefügt
- Neues Widget: Songtext (synchron zum laufenden Lied, gesungene Zeile leuchtet auf), Quelle LRCLIB mit lokalem Zwischenspeicher
- Neues Widget: System-Info im Stil von fastfetch (Liquid Glass), fastfetch als optionales Paket

### Geändert
- Widerspruechliche Bildschirmdaten (Qt gegen hyprctl) nie veroeffentlichen, nach 8 s Selbstneustart (max. 2x in 5 min)
- Einstellung 'Nur Text (ohne Glas-Behaelter)', allgemein ueber den Widget-Schluessel no_glass
- Widgets nach dem Start zu gross: Fenster mit falscher Skalierung werden erkannt und neu erzeugt
- Aenderungen erst nach 2 s Stabilitaet uebernehmen (Widgets blieben nach dem Aufwachen aus dem Standby zu gross)
- Bei Fehlschlag ohne Daten schneller erneut versuchen (30 s bis 5 min) statt 15 Minuten warten
- Visualizer sparsamer (30 fps, cava nur bei sichtbarem Widget), Hintergrundbild nicht groesser als Textur, eigene Glas-Presets, Widget-Liste uebersetzt
- Widget-Fenster auf ganze physische Pixel (gebrochene Skalierung), Glas-Texturen mit echtem Pixelverhältnis

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
