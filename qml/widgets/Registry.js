.pragma library
// Built-in widget types. A type = label + default size + editable props + QML file.
// User types live in ~/.config/widgetdeck/widgets/<name>/{widget.json,Widget.qml} (see README) and are
// merged in by Store.qml with the same shape.
//
// prop kinds: text | bool | int | range | choice | color

var TYPES = {
    clock: {
        label: "Clock & date", desc: "Digital clock with date", icon: "clock", size: [380, 190], file: "ClockWidget.qml",
        props: [
            { key: "time_format", label: "Time format (empty = automatic)", kind: "text", def: "" },
            { key: "date_format", label: "Date format (empty = automatic)", kind: "text", def: "" },
            { key: "show_date", label: "Show date", kind: "bool", def: true },
            { key: "time_scale", label: "Time size", kind: "range", def: 3.6, min: 1.5, max: 7, step: 0.1 },
            { key: "align", label: "Alignment", kind: "choice", def: "start", options: [["start", "Left"], ["center", "Centre"], ["end", "Right"]] }
        ]
    },
    sysmon: {
        label: "CPU & RAM", desc: "Processor and memory load", icon: "cpu", size: [380, 190], file: "SysmonWidget.qml",
        props: [
            { key: "mode", label: "Display", kind: "choice", def: "rings", options: [["rings", "Rings"], ["bars", "Bars"]] },
            { key: "show_cpu", label: "Show CPU", kind: "bool", def: true },
            { key: "show_ram", label: "Show RAM", kind: "bool", def: true },
            { key: "interval", label: "Update interval (ms)", kind: "int", def: 1000, min: 250, max: 5000, step: 250 }
        ]
    },
    music: {
        label: "Music", desc: "Current track (MPRIS) with cover", icon: "music", size: [460, 180], file: "MusicWidget.qml",
        sizes: { small: [380, 160], large: [460, 180] },
        skinSizes: { turntable: { small: [300, 340], large: [580, 260] } },
        props: [
            { key: "skin", label: "Style", kind: "choice", def: "normal", options: [["normal", "Normal"], ["turntable", "Turntable"]] },
            { key: "rpm", label: "Speed (RPM)", kind: "choice", def: "33", options: [["33", "33 RPM"], ["45", "45 RPM"]], when: { key: "skin", is: "turntable" } },
            { key: "arm_follows", label: "Tonearm follows the progress", kind: "bool", def: true, when: { key: "skin", is: "turntable" } },
            { key: "vinyl_color", label: "Vinyl colour", kind: "choice", def: "black", options: [["black", "Black"], ["cover", "From the cover"]], when: { key: "skin", is: "turntable" } },
            { key: "glare", label: "Light reflection", kind: "bool", def: true, when: { key: "skin", is: "turntable" } },
            { key: "show_cover", label: "Show cover", kind: "bool", def: true, when: { key: "skin", is: "normal" } },
            { key: "show_controls", label: "Show controls", kind: "bool", def: true, when: { key: "skin", is: "normal" } },
            { key: "cover_colors", label: "Colours from the album cover", kind: "bool", def: false, when: { key: "skin", is: "normal" } },
            { key: "show_progress", label: "Progress bar", kind: "bool", def: true, when: { key: "skin", is: "normal" } },
            { key: "player", label: "Player (empty = automatic)", kind: "text", def: "" },
            { key: "anim_enabled", label: "Track change animation", kind: "bool", def: true },
            { key: "anim_style", label: "Animation style", kind: "choice", def: "slide", options: [["crossfade", "Crossfade"], ["slide", "Slide"], ["zoom", "Zoom"]] },
            { key: "anim_duration", label: "Duration (ms)", kind: "range", def: 440, min: 200, max: 900, step: 10 },
            { key: "anim_zoom", label: "Zoom strength", kind: "range", def: 0.06, min: 0, max: 0.2, step: 0.01 }
        ]
    },
    netmon: {
        label: "Network", desc: "Live download / upload, 60 s curve, Wi-Fi, signal, ping", icon: "wifi", size: [440, 250], file: "NetMonWidget.qml",
        props: [
            { key: "ping_target", label: "Ping target", kind: "text", def: "1.1.1.1" },
            { key: "show_curve", label: "Curve of the last 60 s", kind: "bool", def: true }
        ]
    },
    thermals: {
        label: "Temperatures & fans", desc: "CPU, GPU, SSD and fans from hwmon", icon: "thermometer", size: [440, 270], file: "ThermalsWidget.qml",
        props: [
            { key: "mode", label: "Display", kind: "choice", def: "rings", options: [["rings", "Rings"], ["bars", "Bars"]] },
            { key: "warn_c", label: "Warning threshold (°C)", kind: "int", def: 80, min: 30, max: 110, step: 1 },
            { key: "show_fans", label: "Show fans", kind: "bool", def: true }
        ]
    },
    sysstatus: {
        label: "Uptime & status", desc: "Uptime, kernel and failed systemd services", icon: "hourglass", size: [380, 200], file: "SysStatusWidget.qml",
        props: [
            { key: "show_kernel", label: "Show kernel version", kind: "bool", def: true },
            { key: "poll_s", label: "Poll interval (seconds)", kind: "int", def: 30, min: 5, max: 600, step: 5 }
        ]
    },
    airquality: {
        label: "Air quality", desc: "European AQI, PM2.5, PM10, ozone (Open-Meteo)", icon: "leaf", size: [400, 230], file: "AirQualityWidget.qml",
        props: [
            { key: "lat", label: "Latitude (empty = location from the settings)", kind: "text", def: "" },
            { key: "lon", label: "Longitude (empty = location from the settings)", kind: "text", def: "" }
        ]
    },
    weather: {
        label: "Weather", desc: "Temperature and conditions, with rain and snow particles on Liquid Glass", icon: "cloud", size: [440, 200], file: "WeatherWidget.qml",
        props: [
            { key: "show_details", label: "Show details", kind: "bool", def: true },
            { key: "particles", label: "Weather particles (Liquid Glass only)", kind: "bool", def: true },
            { key: "particle_density", label: "Particle density (max. 40 drops)", kind: "range", def: 1.0, min: 0.1, max: 1.0, step: 0.05 },
            { key: "debug_weather", label: "Test: force weather", kind: "choice", def: "auto", options: [["auto", "Real weather"], ["rain", "Rain"], ["snow", "Snow"], ["off", "Dry"]] }
        ]
    },
    weathercard: {
        label: "Weather card", desc: "Weather with 3D icons: now, the next hours and days (same data as the weather widget)", icon: "cloud", size: [520, 340], file: "WeatherCardWidget.qml",
        sizes: { small: [380, 220], large: [520, 340] },
        props: [
            { key: "hours", label: "Hours shown (large size)", kind: "range", def: 6, min: 4, max: 8, step: 1 },
            { key: "days", label: "Days shown (large size)", kind: "range", def: 3, min: 3, max: 7, step: 1 },
            { key: "day_bars", label: "Temperature bars", kind: "bool", def: true },
            { key: "show_feels", label: "Show feels-like temperature", kind: "bool", def: false },
            { key: "sky_gradient", label: "Sky gradient (milk glass only)", kind: "bool", def: true },
            { key: "animations", label: "Animations", kind: "choice", def: "subtle", options: [["off", "Off"], ["subtle", "Subtle"], ["full", "Full"]] },
            { key: "font", label: "Font", kind: "font", def: "" },
            { key: "debug_kind", label: "Test: force weather", kind: "choice", def: "auto", options: [["auto", "Real weather"], ["clear", "Clear"], ["mostly_clear", "Mostly clear"], ["partly", "Partly cloudy"], ["cloudy", "Cloudy"], ["fog", "Fog"], ["drizzle", "Drizzle"], ["rain", "Rain"], ["heavy_rain", "Heavy rain"], ["thunder", "Thunderstorm"], ["snow", "Snow"], ["sleet", "Sleet"], ["hail", "Hail"], ["unknown", "Unknown code"]] },
            { key: "debug_time", label: "Test: day / night", kind: "choice", def: "auto", options: [["auto", "Real"], ["day", "Day"], ["night", "Night"]] }
        ]
    },
    timetable: {
        label: "Timetable", desc: "Your WebUntis timetable (Untis Mobile access): now / next lesson, day and week", icon: "calendar", size: [380, 220], file: "TimetableWidget.qml",
        sizes: { small: [380, 220], large: [640, 460] },
        props: [
            { key: "default_view", label: "View (large size)", kind: "choice", def: "today", options: [["today", "Today"], ["tomorrow", "Tomorrow"], ["week", "Week"]] },
            { key: "group", label: "My group (empty = all)", kind: "text", def: "" },
            { key: "show_room", label: "Show room", kind: "bool", def: true },
            { key: "show_teacher", label: "Show teacher", kind: "bool", def: true },
            { key: "source", label: "Data source", kind: "choice", def: "auto", options: [["auto", "Untis Mobile"], ["demo", "Demo (invented lessons)"], ["demo-holiday", "Demo (holidays)"]] }
        ]
    },
    visualizer: {
        label: "Music visualizer", desc: "Audio-reactive bars (cava)", icon: "bars", size: [460, 150], file: "VisualizerWidget.qml",
        style: { bg_alpha: 0.45 },
        props: [
            { key: "bars", label: "Number of bars", kind: "int", def: 32, min: 6, max: 96, step: 1 },
            { key: "mode", label: "Display", kind: "choice", def: "bars", options: [["bars", "Bars"], ["mirror", "Mirrored"], ["line", "Line"]] },
            { key: "gradient", label: "Gradient", kind: "bool", def: true },
            { key: "color2", label: "Second colour (gradient)", kind: "color", def: "theme:secondary" },
            { key: "gap", label: "Spacing", kind: "range", def: 0.35, min: 0.05, max: 0.8, step: 0.01 },
            { key: "source", label: "Audio source (auto = default)", kind: "text", def: "auto" }
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
