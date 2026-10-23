# Fehlerbehebung

[Zurück zur README](../README.md) · [English README](../README.en.md)

Erst `widgetdeck-doctor` ausführen. Es prüft Hyprland, Quickshell, Qt, Shader, Pakete, Wallpaper, Monitore, Konflikte, Einstellungen und die Netzwerkdienste und nennt zu jeder WARN- und FAIL-Zeile eine Lösung. Das Protokoll der Shell zeigt `widgetdeck log`.

## Symptome und Lösungen

| Symptom | Ursache | Lösung |
|---|---|---|
| Nach der Installation erscheint nichts | Der Autostart (`exec-once`) läuft nur beim Start von Hyprland. `hyprctl reload` startet ihn nicht. | `widgetdeck builder` startet den Daemon sofort. Ob er läuft, zeigt `widgetdeck status` (Exit-Code 0 = läuft). Beim nächsten Hyprland-Start startet er von selbst, sofern die Regeldatei eingebunden ist (`widgetdeck-doctor`). |
| Nichts erscheint, auch nach einem Neustart | Die Regeldatei ist nicht in deine Hyprland-Config eingebunden, oder die Config wurde nicht gefunden | `widgetdeck-doctor` (Abschnitt Hyprland). `./install.sh` erneut ausführen und die Rückfrage zur Verweiszeile bestätigen, oder die Zeile von Hand eintragen (steht in der Installer-Ausgabe). |
| `widgetdeck: command not found` | `~/.local/bin` fehlt im `PATH` | In der Shell-Konfiguration ergänzen: `export PATH="$HOME/.local/bin:$PATH"` |
| Tastenkürzel für `focus-timer` oder `widgetdeck` tun nichts | Hyprland startet Programme mit seinem eigenen `PATH`, und der enthält `~/.local/bin` unter Umständen nicht | In der Bind-Zeile den vollen Pfad verwenden, zum Beispiel `bind = SUPER, F, exec, $HOME/.local/bin/focus-timer toggle`. Prüfen: `focus-timer status` im Terminal (Exit-Code 1 = WidgetDeck läuft nicht). |
| Frosted Glass wirkt flach | Blur ist in Hyprland ausgeschaltet, oder die Regeldatei fehlt | In der Hyprland-Config `decoration { blur { enabled = true } }` (das ist der Standard) und die Regeldatei einbinden |
| Liquid Glass wirkt flach oder fällt auf Frosted Glass zurück | `qsb` fehlt oder der Shader ließ sich nicht kompilieren, oder es wurde kein Wallpaper gefunden | `widgetdeck-doctor` (Abschnitte Quickshell und Wallpaper). `sudo pacman -S qt6-shadertools`, dann `widgetdeck restart` (oder `./install.sh`). Auf der ersten Seite des Einrichtungsassistenten steht der Stand des Glas-Shaders. |
| Das Wallpaper wird nicht erkannt | Du nutzt kein Werkzeug aus der Liste awww, swww, hyprpaper, swaybg, wpaperd | Im Builder unter *Einstellungen → Glas-Hintergrund* ein Bild wählen (oder den Pfad eintragen); pro Monitor geht ein eigener Pfad. Nach einem Wallpaper-Wechsel liest `widgetdeck ipc reloadWallpaper` es neu ein. |
| Der Wetterort ist falsch | Die Ortung per IP-Adresse ist nur auf Stadtebene genau und liegt bei VPN oder Mobilfunk oft daneben | *Einstellungen → Standort*: Koordinaten und Ortsnamen eintragen (sie haben Vorrang), oder den Assistenten mit `widgetdeck wizard` erneut starten |
| Wetter oder Luftqualität zeigen nur „As of …“ | Der Dienst ist nicht erreichbar | `widgetdeck-doctor` (Abschnitt Network). Die letzten Werte bleiben stehen, bis die Verbindung wieder da ist. |
| Widgets erscheinen auf dem falschen Monitor | Das Widget ist dem Hauptmonitor oder einem anderen Monitor zugeordnet | Im Builder das Widget wählen: *Anzeigen auf*, *Verschieben nach …* oder *Kopieren nach …*. Den Hauptmonitor legt die Einstellung `monitors.primary` fest. Widgets eines abgezogenen Monitors warten (Standard) oder wandern auf den Hauptmonitor. |
| Das Builder-Fenster ist gekachelt und hat einen Rahmen | Die Fensterregeln sind nicht eingebunden | Regeldatei einbinden, siehe oben |
| Zwei Leisten sichtbar | Das Leisten-Modul von WidgetDeck läuft neben einer anderen Leiste | `widgetdeck module bar off` |
| Keine Benachrichtigungen, oder zwei Benachrichtigungsdienste | Nur ein Programm kann `org.freedesktop.Notifications` besitzen. Das Benachrichtigungsmodul von WidgetDeck ersetzt deinen Dienst, beendet ihn aber nie selbst. | Den anderen Dienst zuerst abschalten (`systemctl --user disable --now <name>` oder aus dem Autostart nehmen), oder das Modul ausschalten: `widgetdeck module notifications off`. Danach einmal `widgetdeck restart`, damit ein anderer Dienst übernehmen kann. |
| Stundenplan: „Zugang abgelaufen, bitte neu einrichten“ | Der Untis-Mobile-Schlüssel wurde widerrufen („Geräte abmelden“ in WebUntis) oder ist abgelaufen | Einen neuen QR-Code in WebUntis öffnen und `widgetdeck-untis-setup` erneut ausführen. Das Widget zeigt bis dahin den letzten Stand. |
| Stundenplan: „Der Server hat den Zugang verweigert“ | Die Schule hat die Untis-Mobile-Schnittstelle abgeschaltet | Es wird nichts gespeichert. Das Widget lässt sich dann nicht verwenden. |
| Stundenplan: Der Schlüssel lässt sich nicht speichern | Es läuft kein Secret Service | gnome-keyring starten oder in KeePassXC den Secret Service einschalten. Als Ausweg bietet das Setup eine private Datei an (`chmod 600`). `widgetdeck-doctor` zeigt den Stand. |
| Fokus-Timer ist stumm | Es ist kein Abspielprogramm installiert | Eines von `pw-play`, `paplay`, `ffplay`, `canberra-gtk-play`, `aplay` installieren, zum Beispiel `pipewire-audio` (liefert `pw-play`) |
| Formel-1-Karte ohne Flagge | Es ist keine Emoji-Schrift installiert | `sudo pacman -S noto-fonts-emoji` (der Ländername steht auch ohne Flagge da) |
| Eine Schrift oder das Aussehen des Textes weicht ab | `adwaita-fonts` fehlt, WidgetDeck nimmt die nächste installierte Schrift | `sudo pacman -S adwaita-fonts` |
| `widgetdeck-update` findet keinen Klon | Der geklonte Ordner wurde gelöscht oder verschoben | `widgetdeck-update` klont das Repository neu, wenn die Quelle bekannt ist. Sonst neu klonen und `./install.sh` ausführen. |

## Das Ergebnis von `widgetdeck-doctor` in ein Issue kopieren

1. Im Terminal einer laufenden Hyprland-Sitzung ausführen (nur dort kann es Monitore und das Wallpaper prüfen):

   ```bash
   widgetdeck-doctor --plain
   ```

2. Die komplette Ausgabe in das [Bug-Report-Formular](https://github.com/Julix2009/WidgetDeck-/issues/new/choose) einfügen. Zum Kopieren in die Zwischenablage geht auch (Paket `wl-clipboard`):

   ```bash
   widgetdeck-doctor --plain | wl-copy
   ```

3. Vorher kurz lesen: Das Programm ersetzt dein Home-Verzeichnis durch `~` und gibt weder Standort noch Wallpaper-Pfad aus. Es nennt aber die Systemversion, Kernel, Spracheinstellung, Grafikkarte, Monitor-Auflösungen und, welche Leisten oder Benachrichtigungsdienste laufen.

Hinweis zum Support: Es gibt keine garantierte Antwortzeit, das ist ein Hobbyprojekt. Unterstützt werden nur Arch Linux mit Hyprland und Quickshell, siehe [`SUPPORT.md`](../SUPPORT.md).
