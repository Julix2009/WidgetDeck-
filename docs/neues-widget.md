# Ein neues Widget hinzufügen

[Zurück zur README](../README.md) · [English README](../README.en.md)

Es gibt zwei Wege. Für ein eigenes Widget auf deinem Rechner brauchst du keine Änderung am Repository (Weg 1). Soll das Widget ins Projekt, ist es ein Eintrag in der Registry (Weg 2).

| | Weg 1: eigenes Widget | Weg 2: eingebautes Widget |
|---|---|---|
| Wo | `~/.config/widgetdeck/widgets/<name>/` | `qml/widgets/` im Repository |
| Dateien | `widget.json` und `Widget.qml` | Eintrag in `qml/widgets/Registry.js` und eine QML-Datei |
| Überlebt Updates | ja, liegt bei deinen Einstellungen | ja, ist Teil des Programms |
| Übersetzungen | nicht nötig | Pflicht (English ist die Quellsprache) |

## Weg 1: eigenes Widget

Das Beispiel [`examples/hello`](../examples/hello/) ist ein vollständiges Widget („Textfeld“).

1. Im geklonten Repository den Ordner kopieren:

   ```bash
   mkdir -p ~/.config/widgetdeck/widgets
   cp -r examples/hello ~/.config/widgetdeck/widgets/mein-widget
   ```

2. Die Liste neu einlesen. Entweder die Shell neu starten oder, ohne Neustart:

   ```bash
   widgetdeck restart
   ```

   ```bash
   widgetdeck ipc reloadLayout
   ```

3. Das Widget erscheint im Builder in der Liste links (Klick oder auf die Fläche ziehen).

WidgetDeck sucht in `~/.config/widgetdeck/widgets/*/` nach Ordnern, in denen **beide** Dateien `widget.json` und `Widget.qml` liegen. Eine fehlerhafte `widget.json` wird übersprungen und im Shell-Log (`widgetdeck log`) gemeldet.

### widget.json

```json
{
  "type": "hello",
  "label": "Textfeld",
  "desc": "Freier Text",
  "glyph": "T",
  "size": [320, 120],
  "style": {},
  "props": [
    { "key": "text", "label": "Text", "kind": "text", "def": "Hallo Hyprland" },
    { "key": "scale", "label": "Größe", "kind": "range", "def": 1.4, "min": 0.8, "max": 4, "step": 0.1 }
  ]
}
```

| Feld | Bedeutung | Standard, wenn es fehlt |
|---|---|---|
| `type` | eindeutiger Name des Typs | Ordnername |
| `label`, `desc` | Name und Beschreibung in der Liste | Ordnername, leer |
| `glyph` | Zeichen in der Liste | `◇` |
| `size` | Standardgröße `[Breite, Höhe]` in logischen Pixeln | `[320, 160]` |
| `style` | Vorgaben für den Glas-Stil dieses Typs | – |
| `props` | Einstellungen für das Eigenschaften-Panel | keine |

Einstellungs-Arten (`kind`) laut `qml/widgets/Registry.js`: `text`, `bool`, `int`, `range`, `choice`, `color`. `int` und `range` nehmen `min`, `max`, `step`; `choice` nimmt `options` als Liste von `[Wert, Beschriftung]`.

### Widget.qml

Die Wurzel ist ein `Item` mit diesen vier Eigenschaften, die der Builder füllt:

| Eigenschaft | Inhalt |
|---|---|
| `style` | aufgelöster Stil: `fg`, `accent`, `font`, `font_size`, `mode` … (Farben folgen schon dem Matugen-Theme oder der im Builder gewählten Farbe) |
| `props` | deine Einstellungen aus `widget.json` |
| `innerRadius` | Eckenradius für abgerundete Kinder |
| `palette` | alle Material-Farbrollen als Hex (`primary`, `secondary`, `tertiary`, `surface_container`, `outline` …) |

Das Glas zeichnet WidgetDeck selbst. Dein Widget zeichnet nur den Inhalt. Gib der Wurzel eine `id` und lies `w.style` und `w.palette`; benenne die Eigenschaften nicht wie eingebaute Eigenschaften der Kinder (`Text` hat zum Beispiel selbst `style`). Das vollständig kommentierte Beispiel steht in [`examples/hello/Widget.qml`](../examples/hello/Widget.qml).

## Weg 2: eingebautes Widget

Die vollständigen Regeln stehen in [`CONTRIBUTING.md`](../CONTRIBUTING.md) (englisch). Kurzfassung:

1. **Registry:** In `qml/widgets/Registry.js` einen Eintrag in `TYPES` anlegen: `file`, `size`, bei zwei Größen die Größen-Tabelle `sizes: { small: [b, h], large: [b, h] }` (sie steuert die Knöpfe *Klein* / *Groß* und die Standardgröße pro Monitor) und `props`. Einstellungen, die für alle Instanzen gleich sein sollen, bekommen `shared: true`.
2. **QML-Datei:** In `qml/widgets/` ablegen. `WidgetHost` setzt jedes registrierte Widget auf das gemeinsame `GlassPanel`; die Datei zeichnet nur Inhalt, liest ihre eigene `width` und `height` und blendet bei Bedarf zwischen kleinem und großem Layout (Vorbild: `qml/widgets/F1Widget.qml`). Nie eine Bildschirmgröße voraussetzen.
3. **Daten:** Über einen gemeinsamen Feed holen (`Feed` in `qml/core/Feed.qml`: ein Schlüssel, der alles enthält, was den Befehl ändert, ein Befehl, ein Intervall) und nie pro Widget-Instanz einen eigenen `Process` starten. Dann kostet ein Widget auf mehreren Monitoren nichts extra.
4. **Monitore:** Nichts zu tun. Die Shell erstellt pro Widget **und** Monitor ein Fenster; Position, Größe und Glas-Hintergrund kommen vom Monitor des Widgets.
5. **Texte:** In QML `I18n.tr("English text")`, in Shell-Skripten `t 'English text %s' arg`. Die deutschen Texte kommen nach `qml/core/i18n.js` und `lib/i18n.sh`.
6. **Icons:** In `qml/core/Icons.js` selbst zeichnen (24×24 Linien-Icons). Keine Icon-Schriften und keine fremden Icons ohne kompatible Lizenz.
7. **Prüfen:** die Befehle aus der Liste in `CONTRIBUTING.md` ausführen, mindestens `python3 tools/check-i18n.py`, `shellcheck` und die Tests, die dein Widget berühren.
8. **Doku:** Eintrag in der Widget-Tabelle der [README](../README.md#funktionen-auf-einen-blick) und ein Abschnitt in [`docs/widgets.md`](widgets.md). Die Einstellungs-Tabelle dort lässt sich aus der Registry erzeugen, sie sollte nicht von Hand abgeschrieben werden.

Lizenz: Nur Code beitragen, den du selbst geschrieben hast oder der eine freie Lizenz trägt, und in der Pull-Request-Beschreibung die Herkunft nennen.
