# NOTICE – Herkunft und Lizenzen

WidgetDeck enthält eigenen Code und die folgenden Teile fremder Herkunft. Prüfstand: siehe unten.

## Enthalten (mit Namensnennung)

| Teil | Herkunft | Lizenz |
|---|---|---|
| `qml/core/glass.frag` (Liquid-Glass-Shader), mit Anpassungen auch `qml/core/drops.frag`, `qml/core/GlassPanel.qml`, `qml/core/Defaults.js` | abgeleitet von `liquidglass.frag` aus **MacShell** (https://github.com/0-ss/MacShell) | **MIT**, © 2026 Rickky – Volltext in `LICENSES/MIT-MacShell.txt` |

Die MIT-Lizenz verlangt, dass der Copyright-Hinweis und der Lizenztext in allen Kopien oder wesentlichen Teilen erhalten bleiben.
Bitte `LICENSES/` und die Dateikopf-Kommentare nicht entfernen.

## Nicht enthalten

* Die Dotfiles-Panels, Top-Bar, Settings-Menüs und Skripte aus dem Dotfiles-Projekt **ilyamiro/imperative-dots** liegen **nicht** im Paket.
  Das Projekt hat keine Lizenzdatei; ohne Lizenz darf der Code nicht weitergegeben werden. WidgetDeck bringt eigene Ersatzskripte für Wetter, Luftqualität und Standort mit.
* Es werden **keine Schriften oder Emoji-Daten** mitgeliefert; bevorzugt wird `Adwaita Sans` (`adwaita-fonts`, OFL 1.1), das per `pacman` installiert wird. Die **Icons** (`qml/core/Icons.js`) sind für dieses Projekt gezeichnet (eigener Code).

## Genutzte Online-Dienste (nur Daten, kein Code)

* **Open-Meteo** (https://open-meteo.com) – Wetter und Luftqualität, ohne API-Schlüssel. Die Daten stehen unter CC BY 4.0; die kostenlose API ist für nicht-kommerzielle Nutzung gedacht.
* **ipwho.is** – optionale Standortbestimmung per IP (abschaltbar: `~/.config/widgetdeck/config.json`, `location.auto = false`).

## Eigener Code

Alle übrigen Dateien sind eigener Code des Projekts. Die Lizenz dafür steht in `LICENSE` (siehe README, Abschnitt „Lizenz“).
