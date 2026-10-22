# NOTICE – Herkunft und Lizenzen

WidgetDeck enthält eigenen Code und die folgenden Teile fremder Herkunft. Prüfstand: siehe unten.

## Enthalten (mit Namensnennung)

| Teil | Herkunft | Lizenz |
|---|---|---|
| `qml/core/glass.frag` (Liquid-Glass-Shader), mit Anpassungen auch `qml/core/drops.frag`, `qml/core/GlassPanel.qml`, `qml/core/Defaults.js` | abgeleitet von `liquidglass.frag` aus **MacShell** (https://github.com/0-ss/MacShell) | **MIT**, © 2026 Rickky – Volltext in `LICENSES/MIT-MacShell.txt` |
| `qml/widgets/f1/circuits.json`, `circuits.js` (Streckenumrisse des Formel-1-Widgets; vereinfacht, in einen 0..1000-Rahmen skaliert) | abgeleitet aus dem GeoJSON von **bacinger/f1-circuits** (https://github.com/bacinger/f1-circuits), erzeugt mit `tools/f1/build_circuits.py` | **MIT**, © 2019-2025 Tomislav Bacinger – Volltext in `LICENSES/MIT-f1-circuits.txt` |

Die MIT-Lizenz verlangt, dass der Copyright-Hinweis und der Lizenztext in allen Kopien oder wesentlichen Teilen erhalten bleiben.
Bitte `LICENSES/` und die Dateikopf-Kommentare nicht entfernen.

## Nicht enthalten

* Die Dotfiles-Panels, Top-Bar, Settings-Menüs und Skripte aus dem Dotfiles-Projekt **ilyamiro/imperative-dots** liegen **nicht** im Paket.
  Das Projekt hat keine Lizenzdatei; ohne Lizenz darf der Code nicht weitergegeben werden. WidgetDeck bringt eigene Ersatzskripte für Wetter, Luftqualität und Standort mit.
* Es werden **keine Schriften oder Emoji-Daten** mitgeliefert; bevorzugt wird `Adwaita Sans` (`adwaita-fonts`, OFL 1.1), das per `pacman` installiert wird. Die **Icons** (`qml/core/Icons.js`) sind für dieses Projekt gezeichnet (eigener Code).

## Genutzte Online-Dienste (nur Daten, kein Code)

* **Open-Meteo** (https://open-meteo.com) – Wetter und Luftqualität, ohne API-Schlüssel. Die Daten stehen unter CC BY 4.0; die kostenlose API ist für nicht-kommerzielle Nutzung gedacht.
* **Jolpica-F1** (https://api.jolpi.ca/ergast/f1/, Nachfolger der Ergast-API) – Rennkalender, Ergebnisse und Fahrerwertung für das Formel-1-Widget. **Nutzungsbedingungen: https://github.com/jolpica/jolpica-f1/blob/main/TERMS.md – die Daten stehen unter CC BY-NC-SA 4.0 (nur nicht-kommerzielle Nutzung, Namensnennung); Limits: 4 Anfragen pro Sekunde, 500 pro Stunde.** Ohne Schlüssel, nur lesend, mit lokalem Zwischenspeicher; Anfragen werden gedrosselt (Kalender höchstens einmal pro Tag, Ergebnisse / Wertung alle 6 Stunden, Wartezeit nach Fehlern und bei HTTP 429 / `Retry-After`). Die Daten werden nicht weitergegeben und nicht in diesem Repository gespeichert; sie liegen nur im lokalen Zwischenspeicher (`~/.cache/widgetdeck/f1.json`). WidgetDeck ist ein freies, nicht-kommerzielles Projekt – wer das Widget kommerziell einsetzen will, muss sich selbst mit den Betreibern der Dienste einigen.
* **OpenF1** (https://api.openf1.org/v1/) – abgesagte Sessions (`is_cancelled`) und die **optionale** Live-Ansicht (Flagge, die ersten Drei; standardmäßig aus). Der Dienst ist ein inoffizielles Projekt (Lizenz des Projekts: CC BY-NC-SA 4.0, siehe sein Repository). Es wird nur der frei zugängliche, schlüssellose Teil genutzt; verlangt der Dienst während einer Live-Session eine Anmeldung, bleibt die normale Ansicht.
* **ipwho.is** – optionale Standortbestimmung per IP (abschaltbar: `~/.config/widgetdeck/config.json`, `location.auto = false`).

## Eigener Code

Die 3D-Wetter-Icons der Wetter-Karte (`qml/widgets/weathercard/icons3d/`) sind **eigene Arbeit**: sie werden von `tools/blender/render.sh` (Blender, Cycles) aus der eigenen prozeduralen Szenenbeschreibung `tools/blender/icon_scenes.py` gerendert; es wurden keine fremden Bilder, Icons, Netze oder Texturen verwendet, nachgezeichnet oder zugeschnitten. Blender selbst (GPL) wird nur zum Erzeugen gebraucht und nicht mitgeliefert; die erzeugten Bilder sind eigene Werke.

Alle übrigen Dateien sind eigener Code des Projekts. Die Lizenz dafür steht in `LICENSE` (siehe README, Abschnitt „Lizenz“).

## Formel-1-Widget: Marken und Streckenumrisse

* **Inoffizielles Fan-Widget.** Es steht in keiner Verbindung zu Formula 1, der FIA, Teams oder Fahrern und wird von ihnen weder unterstützt noch geprüft. „Formula 1“, „F1“, „FIA“ und die zugehörigen Marken gehören ihren jeweiligen Inhabern; sie werden nur als Bezeichnung für das beschriebene Sportereignis genannt.
* Es werden **keine Logos, Schriftzüge, Fotos oder Bilder** der Formel 1, der FIA oder von Teams mitgeliefert oder geladen; es wird **nichts von Webseiten gelesen („gescrapt“)**, nur die oben genannten offenen Schnittstellen werden abgefragt.
* **Streckenumrisse:** Quelle ist das Repository *bacinger/f1-circuits* (MIT-Lizenz, siehe oben). Das Repository nennt die Herkunft der Geometrie nicht ausdrücklich; es handelt sich um öffentliche geografische Streckenverläufe. WidgetDeck liefert davon nur **eigene, stark vereinfachte Umrisslinien** (einige hundert Punkte pro Strecke, ohne Namen, Logos oder Zusatzdaten). Falls ein Rechteinhaber Einwände hat, wird die Datei entfernt bzw. neu aus einer anderen Quelle erzeugt (`tools/f1/build_circuits.py`).
* Beim Installieren und im Betrieb wird **nichts nachgeladen**, was Umrisse betrifft: die fertige Datei liegt im Repository.

## Fokus-Timer: Ton

Der Ton des Fokus-Timers (`qml/widgets/focustimer/chime.wav`) ist **eigene Arbeit**: `tools/focustimer/make_chime.py` erzeugt ihn deterministisch aus reinen Sinuswellen (zwei „Glocken“-Töne mit Obertönen und abklingender Hüllkurve). Es wurde keine Aufnahme, kein Sample und keine fremde Audiodatei verwendet.
