.pragma library
// Built-in widget types. A type = label + default size + editable props + QML file.
// User types live in ~/.config/widgetdeck/widgets/<name>/{widget.json,Widget.qml} (see README) and are
// merged in by Store.qml with the same shape.
//
// prop kinds: text | bool | int | range | choice | color

var TYPES = {
    clock: {
        label: "Uhr & Datum", desc: "Digitaluhr mit Datum", glyph: "◷", size: [380, 190], file: "ClockWidget.qml",
        props: [
            { key: "time_format", label: "Zeitformat", kind: "text", def: "%H:%M" },
            { key: "date_format", label: "Datumsformat", kind: "text", def: "%A, %d. %B" },
            { key: "show_date", label: "Datum anzeigen", kind: "bool", def: true },
            { key: "time_scale", label: "Größe der Uhrzeit", kind: "range", def: 3.6, min: 1.5, max: 7, step: 0.1 },
            { key: "align", label: "Ausrichtung", kind: "choice", def: "start", options: [["start", "Links"], ["center", "Mitte"], ["end", "Rechts"]] }
        ]
    },
    sysmon: {
        label: "CPU & RAM", desc: "Auslastung von Prozessor und Arbeitsspeicher", glyph: "▥", size: [380, 190], file: "SysmonWidget.qml",
        props: [
            { key: "mode", label: "Darstellung", kind: "choice", def: "rings", options: [["rings", "Ringe"], ["bars", "Balken"]] },
            { key: "show_cpu", label: "CPU anzeigen", kind: "bool", def: true },
            { key: "show_ram", label: "RAM anzeigen", kind: "bool", def: true },
            { key: "interval", label: "Aktualisierung (ms)", kind: "int", def: 1000, min: 250, max: 5000, step: 250 }
        ]
    },
    music: {
        label: "Musik", desc: "Aktueller Titel (MPRIS) mit Cover", glyph: "♪", size: [460, 180], file: "MusicWidget.qml",
        props: [
            { key: "show_cover", label: "Cover anzeigen", kind: "bool", def: true },
            { key: "show_controls", label: "Steuerung anzeigen", kind: "bool", def: true },
            { key: "cover_colors", label: "Farben aus dem Albumcover", kind: "bool", def: false },
            { key: "show_progress", label: "Fortschrittsbalken", kind: "bool", def: true },
            { key: "player", label: "Player (leer = automatisch)", kind: "text", def: "" },
            { key: "anim_enabled", label: "Songwechsel-Animation", kind: "bool", def: true },
            { key: "anim_style", label: "Animationsstil", kind: "choice", def: "slide", options: [["crossfade", "Crossfade"], ["slide", "Slide"], ["zoom", "Zoom"]] },
            { key: "anim_duration", label: "Dauer (ms)", kind: "range", def: 440, min: 200, max: 900, step: 10 },
            { key: "anim_zoom", label: "Stärke des Zoom-Effekts", kind: "range", def: 0.06, min: 0, max: 0.2, step: 0.01 }
        ]
    },
    netmon: {
        label: "Netzwerk", desc: "Download / Upload live, 60-s-Kurve, WLAN, Signal, Ping", glyph: "󰖩", size: [440, 250], file: "NetMonWidget.qml",
        props: [
            { key: "ping_target", label: "Ping-Ziel", kind: "text", def: "1.1.1.1" },
            { key: "show_curve", label: "Kurve der letzten 60 s", kind: "bool", def: true }
        ]
    },
    thermals: {
        label: "Temperaturen & Lüfter", desc: "CPU, GPU, SSD und Lüfter aus hwmon", glyph: "󰔏", size: [440, 270], file: "ThermalsWidget.qml",
        props: [
            { key: "mode", label: "Darstellung", kind: "choice", def: "rings", options: [["rings", "Ringe"], ["bars", "Balken"]] },
            { key: "warn_c", label: "Warnschwelle (°C)", kind: "int", def: 80, min: 30, max: 110, step: 1 },
            { key: "show_fans", label: "Lüfter anzeigen", kind: "bool", def: true }
        ]
    },
    sysstatus: {
        label: "Uptime & Status", desc: "Laufzeit, Kernel und fehlgeschlagene systemd-Dienste", glyph: "󰔟", size: [380, 200], file: "SysStatusWidget.qml",
        props: [
            { key: "show_kernel", label: "Kernel-Version anzeigen", kind: "bool", def: true },
            { key: "poll_s", label: "Abfrage (Sekunden)", kind: "int", def: 30, min: 5, max: 600, step: 5 }
        ]
    },
    airquality: {
        label: "Luftqualität", desc: "Europäischer AQI, PM2.5, PM10, Ozon (Open-Meteo)", glyph: "󰖕", size: [400, 230], file: "AirQualityWidget.qml",
        props: [
            { key: "lat", label: "Breite (leer = Standort aus den Einstellungen)", kind: "text", def: "" },
            { key: "lon", label: "Länge (leer = Standort aus den Einstellungen)", kind: "text", def: "" }
        ]
    },
    weather: {
        label: "Wetter", desc: "Temperatur und Wetterlage, Liquid Glass mit Regen- und Schnee-Partikeln", glyph: "󰖐", size: [440, 200], file: "WeatherWidget.qml",
        props: [
            { key: "show_details", label: "Details anzeigen", kind: "bool", def: true },
            { key: "particles", label: "Wetter-Partikel (nur Liquid Glass)", kind: "bool", def: true },
            { key: "particle_density", label: "Dichte der Partikel (max. 40 Tropfen)", kind: "range", def: 1.0, min: 0.1, max: 1.0, step: 0.05 },
            { key: "debug_weather", label: "Test: Wetter erzwingen", kind: "choice", def: "auto", options: [["auto", "Echtes Wetter"], ["rain", "Regen"], ["snow", "Schnee"], ["off", "Trocken"]] }
        ]
    },
    visualizer: {
        label: "Musik-Visualizer", desc: "Audio-reaktive Balken (cava)", glyph: "▁▃▆", size: [460, 150], file: "VisualizerWidget.qml",
        style: { bg_alpha: 0.45 },
        props: [
            { key: "bars", label: "Anzahl Balken", kind: "int", def: 32, min: 6, max: 96, step: 1 },
            { key: "mode", label: "Darstellung", kind: "choice", def: "bars", options: [["bars", "Balken"], ["mirror", "Gespiegelt"], ["line", "Linie"]] },
            { key: "gradient", label: "Farbverlauf", kind: "bool", def: true },
            { key: "color2", label: "Zweite Farbe (Verlauf)", kind: "color", def: "theme:secondary" },
            { key: "gap", label: "Abstand", kind: "range", def: 0.35, min: 0.05, max: 0.8, step: 0.01 },
            { key: "source", label: "Audioquelle (auto = Standard)", kind: "text", def: "auto" }
        ]
    }
};

function propDefaults(type, extra) {
    var t = TYPES[type] || (extra && extra[type]) || null, d = {};
    if (t) for (var i = 0; i < t.props.length; i++) d[t.props[i].key] = t.props[i].def;
    return d;
}
function resolveProps(type, partial, extra) {
    var d = propDefaults(type, extra);
    if (partial) for (var k in partial) d[k] = partial[k];
    return d;
}
