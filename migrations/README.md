# Migrationen der Einstellungen

Ändert sich das Format von `~/.config/widgetdeck/` (z. B. eine neue Einstellung), kommt hier ein nummeriertes Skript dazu:

    migrations/0001_kurzer_name.sh
    migrations/0002_anderer_name.sh

* Wird beim Installieren/Aktualisieren automatisch **in Zahlenreihenfolge** ausgeführt, aber nur, wenn die `schema`-Nummer in `config.json` kleiner ist.
* Vorher entsteht ein Backup `~/.config/widgetdeck.bak-<Datum>`. Schlägt ein Skript fehl, wird es zurückgespielt und das Update bricht ab.
* Das Skript bekommt das Config-Verzeichnis als `$1`, muss **idempotent** sein (zweimal ausführen ändert nichts weiter) und darf bestehende Werte des Nutzers nie überschreiben.
  Hilfsfunktionen: `. "$(dirname "$0")/lib.sh"` stellt `merge_defaults <datei> '<json>'` bereit (ergänzt nur fehlende Schlüssel).
* Die Schema-Nummer setzt der Runner nach jedem erfolgreichen Skript selbst.
