.pragma library
// Built-in widget types. A type = label + default size + editable props + QML file.
// User types live in ~/.config/widgetdeck/widgets/<name>/{widget.json,Widget.qml} (see README) and are
// merged in by Store.qml with the same shape.
//
// prop kinds: text | bool | int | range | choice | color
// prop flags for the builder: simple: true = also shown in the simple mode; design: true = a choice shown as preview tiles
// prop flag shared: true = the value is the same for every instance of the type (setting it on one sets it on all; a new instance takes it over):
//   for widgets that show ONE shared thing (the focus timer)

var TYPES = {
    clock: {
        label: "Clock", desc: "Clock with date in several styles: digital, flower, poster, card, stacked, day ring, pixel", icon: "clock", size: [380, 190], file: "ClockWidget.qml",
        props: [
            { key: "clock_style", design: true, label: "Clock style", kind: "choice", def: "digital", options: [["digital", "Digital"], ["flower", "Flower (analogue)"], ["poster", "Poster"], ["card", "Greeting card"], ["stacked", "Stacked"], ["ring", "Day ring"], ["pixel", "Pixel"]] },
            { key: "clock_glass", simple: true, label: "Glass behind the clock style", kind: "bool", def: false },
            { key: "show_seconds", simple: true, label: "Seconds (hand / blinking colon)", kind: "bool", def: true },
            { key: "petals", label: "Petals (flower)", kind: "int", def: 10, min: 5, max: 16, step: 1 },
            { key: "spin", label: "Flower turns slowly", kind: "bool", def: false },
            { key: "time_format", label: "Time format (empty = automatic)", kind: "text", def: "" },
            { key: "date_format", label: "Date format (empty = automatic)", kind: "text", def: "" },
            { key: "show_date", simple: true, label: "Show date", kind: "bool", def: true },
            { key: "world_zones", label: "World clock: time zones (e.g. Asia/Tokyo, America/New_York=NYC)", kind: "text", def: "", when: { key: "clock_style", is: "digital" } },
            { key: "time_scale", label: "Time size", kind: "range", def: 3.6, min: 1.5, max: 7, step: 0.1 },
            { key: "align", simple: true, label: "Alignment", kind: "choice", def: "start", options: [["start", "Left"], ["center", "Centre"], ["end", "Right"]] }
        ]
    },
    sysmon: {
        label: "CPU & RAM", desc: "Processor and memory load", icon: "cpu", size: [380, 190], file: "SysmonWidget.qml",
        props: [
            { key: "mode", simple: true, label: "Display", kind: "choice", def: "rings", options: [["rings", "Rings"], ["bars", "Bars"]] },
            { key: "show_cpu", simple: true, label: "Show CPU", kind: "bool", def: true },
            { key: "show_ram", simple: true, label: "Show RAM", kind: "bool", def: true },
            { key: "interval", label: "Update interval (ms)", kind: "int", def: 1000, min: 250, max: 5000, step: 250 }
        ]
    },
    music: {
        label: "Music", desc: "Current track (MPRIS) with cover", icon: "music", size: [460, 180], file: "MusicWidget.qml",
        sizes: { small: [380, 160], large: [460, 180] },
        skinSizes: { turntable: { small: [300, 340], large: [580, 260] }, poster: { small: [240, 360], large: [320, 480] }, disc: { small: [220, 260], large: [320, 380] },
                     minimal: { small: [420, 170], large: [640, 230] }, cassette: { small: [340, 220], large: [480, 310] }, pill: { small: [320, 90], large: [440, 120] } },
        props: [
            { key: "skin", design: true, label: "Style", kind: "choice", def: "normal", options: [["normal", "Normal"], ["turntable", "Turntable"], ["poster", "Poster"], ["disc", "Spinning disc"], ["minimal", "Typography"], ["cassette", "Cassette"], ["pill", "Capsule"]] },
            { key: "skin_glass", simple: true, label: "Glass behind the style", kind: "bool", def: false },
            { key: "rpm", label: "Speed (RPM)", kind: "choice", def: "33", options: [["33", "33 RPM"], ["45", "45 RPM"]], when: { key: "skin", is: "turntable" } },
            { key: "arm_follows", label: "Tonearm follows the progress", kind: "bool", def: true, when: { key: "skin", is: "turntable" } },
            { key: "vinyl_color", label: "Vinyl colour", kind: "choice", def: "black", options: [["black", "Black"], ["cover", "From the cover"]], when: { key: "skin", is: "turntable" } },
            { key: "glare", label: "Light reflection", kind: "bool", def: true, when: { key: "skin", is: "turntable" } },
            { key: "show_cover", label: "Show cover", kind: "bool", def: true, when: { key: "skin", is: "normal" } },
            { key: "show_controls", simple: true, label: "Show controls", kind: "bool", def: true, when: { key: "skin", is: "normal" } },
            { key: "cover_colors", simple: true, label: "Colours from the album cover", kind: "bool", def: false, when: { key: "skin", is: "normal" } },
            { key: "show_progress", simple: true, label: "Progress bar", kind: "bool", def: true, when: { key: "skin", is: "normal" } },
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
            { key: "ping_target", simple: true, label: "Ping target", kind: "text", def: "1.1.1.1" },
            { key: "show_curve", simple: true, label: "Curve of the last 60 s", kind: "bool", def: true },
            { key: "color_down", label: "Colour: download (number and curve)", kind: "color", def: "theme:primary" },
            { key: "color_up", label: "Colour: upload (number and curve)", kind: "color", def: "theme:tertiary" },
            { key: "color_signal", label: "Colour: Wi-Fi icon and bars", kind: "color", def: "theme:primary" },
            { key: "color_ping", label: "Colour: ping", kind: "color", def: "theme:on_surface" },
            { key: "color_error", label: "Colour: no connection / ping too high", kind: "color", def: "theme:error" }
        ]
    },
    thermals: {
        label: "Temperatures", desc: "CPU, GPU, SSD and fans from hwmon", icon: "thermometer", size: [440, 270], file: "ThermalsWidget.qml",
        props: [
            { key: "mode", simple: true, label: "Display", kind: "choice", def: "rings", options: [["rings", "Rings"], ["bars", "Bars"]] },
            { key: "warn_c", label: "Warning threshold (°C)", kind: "int", def: 80, min: 30, max: 110, step: 1 },
            { key: "show_fans", simple: true, label: "Show fans", kind: "bool", def: true }
        ]
    },
    sysstatus: {
        label: "Uptime", desc: "Uptime, kernel and failed systemd services", icon: "hourglass", size: [380, 200], file: "SysStatusWidget.qml",
        props: [
            { key: "show_kernel", simple: true, label: "Show kernel version", kind: "bool", def: true },
            { key: "poll_s", label: "Poll interval (seconds)", kind: "int", def: 30, min: 5, max: 600, step: 5 }
        ]
    },
    fastfetch: {
        label: "System", desc: "fastfetch-style overview: system, kernel, uptime, packages, CPU, GPU, memory, disk (needs fastfetch)", icon: "cpu", size: [560, 330], file: "FastfetchWidget.qml",
        props: [
            { key: "show_logo", simple: true, label: "Show logo", kind: "bool", def: true },
            { key: "show_title", label: "Show user@host", kind: "bool", def: true },
            { key: "show_hardware", simple: true, label: "Show hardware (device, CPU, GPU)", kind: "bool", def: true },
            { key: "show_software", simple: true, label: "Show software (packages, shell, WM)", kind: "bool", def: true },
            { key: "show_colors", label: "Show colour blocks", kind: "bool", def: true },
            { key: "poll_s", label: "Poll interval (seconds)", kind: "int", def: 60, min: 10, max: 600, step: 10 }
        ]
    },
    lyrics: {
        label: "Lyrics", desc: "Synchronised lyrics of the playing song, the line being sung is highlighted (LRCLIB, needs a player with MPRIS)", icon: "music", size: [520, 300], file: "LyricsWidget.qml",
        style: { bg_alpha: 0.35 },
        props: [
            { key: "text_size", simple: true, label: "Text size", kind: "range", def: 1.3, min: 0.8, max: 2.4, step: 0.05 },
            { key: "align", simple: true, label: "Alignment", kind: "choice", def: "left", options: [["left", "Left"], ["center", "Centre"]] },
            { key: "word_highlight", label: "Light up word by word", kind: "bool", def: true },
            { key: "accent_current", label: "Current line in the accent colour", kind: "bool", def: false },
            { key: "show_title", label: "Show title and artist", kind: "bool", def: false },
            { key: "no_glass", simple: true, label: "Text only (no glass container)", kind: "bool", def: false },
            { key: "player", label: "Player (empty = automatic)", kind: "text", def: "" }
        ]
    },
    airquality: {
        label: "Air", desc: "European AQI, PM2.5, PM10, ozone (Open-Meteo)", icon: "leaf", size: [400, 230], file: "AirQualityWidget.qml",
        props: [
            { key: "lat", label: "Latitude (empty = location from the settings)", kind: "text", def: "" },
            { key: "lon", label: "Longitude (empty = location from the settings)", kind: "text", def: "" }
        ]
    },
    weather: {
        label: "Weather", desc: "Temperature and conditions, with rain and snow particles on Liquid Glass", icon: "cloud", size: [440, 200], file: "WeatherWidget.qml",
        props: [
            { key: "show_details", simple: true, label: "Show details", kind: "bool", def: true },
            { key: "particles", simple: true, label: "Weather particles (Liquid Glass only)", kind: "bool", def: true },
            { key: "particle_density", label: "Particle density (max. 40 drops)", kind: "range", def: 1.0, min: 0.1, max: 1.0, step: 0.05 },
            { key: "debug_weather", label: "Test: force weather", kind: "choice", def: "auto", options: [["auto", "Real weather"], ["rain", "Rain"], ["snow", "Snow"], ["off", "Dry"]] }
        ]
    },
    weathercard: {
        label: "Forecast", desc: "Weather with 3D icons: now, the next hours and days (same data as the weather widget)", icon: "cloud", size: [520, 340], file: "WeatherCardWidget.qml",
        sizes: { small: [380, 220], large: [520, 340] },
        props: [
            { key: "hours", label: "Hours shown (large size)", kind: "range", def: 6, min: 4, max: 8, step: 1 },
            { key: "days", label: "Days shown (large size)", kind: "range", def: 3, min: 3, max: 7, step: 1 },
            { key: "day_bars", simple: true, label: "Temperature bars", kind: "bool", def: true },
            { key: "show_feels", simple: true, label: "Show feels-like temperature", kind: "bool", def: false },
            { key: "sky_gradient", label: "Sky gradient (milk glass only)", kind: "bool", def: true },
            { key: "animations", label: "Animations", kind: "choice", def: "subtle", options: [["off", "Off"], ["subtle", "Subtle"], ["full", "Full"]] },
            { key: "font", label: "Font", kind: "font", def: "" },
            { key: "debug_kind", label: "Test: force weather", kind: "choice", def: "auto", options: [["auto", "Real weather"], ["clear", "Clear"], ["mostly_clear", "Mostly clear"], ["partly", "Partly cloudy"], ["cloudy", "Cloudy"], ["fog", "Fog"], ["drizzle", "Drizzle"], ["rain", "Rain"], ["heavy_rain", "Heavy rain"], ["thunder", "Thunderstorm"], ["snow", "Snow"], ["sleet", "Sleet"], ["hail", "Hail"], ["unknown", "Unknown code"]] },
            { key: "debug_time", label: "Test: day / night", kind: "choice", def: "auto", options: [["auto", "Real"], ["day", "Day"], ["night", "Night"]] }
        ]
    },
    f1: {
        label: "Formula 1", desc: "Next race weekend: track outline, countdown, all sessions in local time, last result and standings (unofficial fan widget)", icon: "clock", size: [580, 540], file: "F1Widget.qml",
        sizes: { small: [420, 240], large: [580, 540] },
        props: [
            { key: "design", design: true, label: "Design", kind: "choice", def: "classic", options: [["classic", "Classic card"], ["track", "Circuit"], ["countdown", "Big countdown"], ["lights", "Start lights"], ["tower", "Standings tower"], ["ticket", "Race ticket"]] },
            { key: "design_glass", simple: true, label: "Glass behind the design", kind: "bool", def: false },
            { key: "show_results", simple: true, label: "Show last result", kind: "bool", def: true },
            { key: "show_standings", simple: true, label: "Show driver standings", kind: "bool", def: true },
            { key: "standings", label: "Standings places (large size)", kind: "range", def: 3, min: 3, max: 10, step: 1 },
            { key: "show_track", label: "Track outline", kind: "bool", def: true },
            { key: "draw_in", label: "Draw the outline in once", kind: "bool", def: true },
            { key: "time_format", label: "Time format", kind: "choice", def: "auto", options: [["auto", "From system"], ["24h", "24 h"], ["12h", "12 h"]] },
            { key: "live_data", label: "Live data during a session (OpenF1)", kind: "bool", def: false },
            { key: "reminder", simple: true, label: "Remind me before sessions", kind: "bool", def: false },
            { key: "rem_practice", label: "Remind: practice", kind: "bool", def: false, when: { key: "reminder", is: "true" } },
            { key: "rem_quali", label: "Remind: qualifying", kind: "bool", def: true, when: { key: "reminder", is: "true" } },
            { key: "rem_race", label: "Remind: race and sprint", kind: "bool", def: true, when: { key: "reminder", is: "true" } },
            { key: "debug_scenario", label: "Test: weekend", kind: "choice", def: "auto", options: [["auto", "Real data"], ["weekend", "Normal weekend"], ["sprint", "Sprint weekend"], ["running", "Session running"], ["finished", "Race just finished"], ["seasonend", "Season finished"], ["cancelled", "Race cancelled"], ["noresult", "No result yet"]] },
            { key: "debug_circuit", label: "Test: circuit", kind: "choice", def: "auto", options: [["auto", "Real circuit"], ["albert_park", "Albert Park Circuit"],["shanghai", "Shanghai International Circuit"],["suzuka", "Suzuka International Racing Course"],["miami", "Miami International Autodrome"],["villeneuve", "Circuit Gilles-Villeneuve"],["monaco", "Circuit de Monaco"],["catalunya", "Circuit de Barcelona-Catalunya"],["red_bull_ring", "Red Bull Ring"],["silverstone", "Silverstone Circuit"],["spa", "Circuit de Spa-Francorchamps"],["hungaroring", "Hungaroring"],["zandvoort", "Circuit Zandvoort"],["monza", "Autodromo Nazionale Monza"],["madring", "Circuito de Madring"],["baku", "Baku City Circuit"],["sepang", "Sepang International Circuit"],["marina_bay", "Marina Bay Street Circuit"],["americas", "Circuit of the Americas"],["rodriguez", "Autódromo Hermanos Rodríguez"],["interlagos", "Autódromo José Carlos Pace - Interlagos"],["vegas", "Las Vegas Street Circuit"],["losail", "Losail International Circuit"],["yas_marina", "Yas Marina Circuit"],["bahrain", "Bahrain International Circuit"],["jeddah", "Jeddah Corniche Circuit"],["imola", "Autodromo Enzo e Dino Ferrari"],["mugello", "Autodromo Internazionale del Mugello"],["nurburgring", "Nürburgring"],["hockenheimring", "Hockenheimring"],["ricard", "Circuit Paul Ricard"],["magny_cours", "Circuit de Nevers Magny-Cours"],["istanbul", "Intercity Istanbul Park"],["portimao", "Autódromo Internacional do Algarve"],["estoril", "Autódromo do Estoril"],["sochi", "Sochi Autodrom"],["indianapolis", "Indianapolis Motor Speedway"],["galvez", "Autódromo Oscar y Juan Gálvez"],["kyalami", "Kyalami Grand Prix Circuit"],["watkins_glen", "Watkins Glen International"],["jacarepagua", "Autódromo Internacional Nelson Piquet"]] }
        ]
    },
    focustimer: {
        label: "Timer", desc: "Pomodoro: focus and break phases with a ring, sessions today (one timer for all instances and monitors)", icon: "hourglass", size: [300, 380], file: "FocusTimerWidget.qml",
        sizes: { small: [200, 200], large: [300, 380] },
        props: [
            { key: "focus_min", simple: true, label: "Focus (minutes)", kind: "int", def: 25, min: 1, max: 180, step: 1, shared: true },
            { key: "short_min", simple: true, label: "Short break (minutes)", kind: "int", def: 5, min: 1, max: 60, step: 1, shared: true },
            { key: "long_min", label: "Long break (minutes)", kind: "int", def: 15, min: 1, max: 120, step: 1, shared: true },
            { key: "cycles", label: "Focus sessions before the long break", kind: "int", def: 4, min: 1, max: 12, step: 1, shared: true },
            { key: "auto_next", label: "Start the next phase automatically", kind: "bool", def: false, shared: true },
            { key: "focus_mode", label: "Pause notifications during focus", kind: "bool", def: false, shared: true },
            { key: "sound", simple: true, label: "Sound at the end of a phase", kind: "bool", def: true, shared: true },
            { key: "volume", label: "Volume", kind: "range", def: 70, min: 0, max: 100, step: 5, shared: true },
            { key: "notify", label: "Notification at the end of a phase", kind: "bool", def: true, shared: true },
            { key: "debug_fast", label: "Test: phases of seconds", kind: "bool", def: false, shared: true }
        ]
    },
    timetable: {
        label: "Timetable", desc: "Your WebUntis timetable (Untis Mobile access): now / next lesson, day and week", icon: "calendar", size: [380, 220], file: "TimetableWidget.qml",
        sizes: { small: [380, 220], large: [640, 460] },
        props: [
            { key: "default_view", simple: true, label: "View (large size)", kind: "choice", def: "today", options: [["today", "Today"], ["tomorrow", "Tomorrow"], ["week", "Week"]] },
            { key: "group", label: "My group (empty = all)", kind: "text", def: "" },
            { key: "show_room", simple: true, label: "Show room", kind: "bool", def: true },
            { key: "show_teacher", simple: true, label: "Show teacher", kind: "bool", def: true },
            { key: "source", label: "Data source", kind: "choice", def: "auto", options: [["auto", "Untis Mobile"], ["demo", "Demo (invented lessons)"], ["demo-holiday", "Demo (holidays)"]] }
        ]
    },
    github: {
        label: "GitHub activity", desc: "Your GitHub contribution calendar with totals and streak", icon: "branch", size: [820, 230], file: "GithubWidget.qml",
        sizes: { small: [420, 200], large: [820, 230] },
        props: [
            { key: "colors", simple: true, label: "Colours", kind: "choice", def: "green", options: [["green", "GitHub green"], ["accent", "Accent colour"]] },
            { key: "show_totals", simple: true, label: "Show total and streak", kind: "bool", def: true },
            { key: "show_legend", label: "Show legend and user name", kind: "bool", def: true }
        ]
    },
    schoolprogress: {
        label: "Progress", desc: "How much of the school day or the school week is over, in percent (counts the lessons of the timetable)", icon: "calendar", size: [200, 200], file: "SchoolProgressWidget.qml",
        props: [
            { key: "mode", simple: true, label: "Show", kind: "choice", def: "week", options: [["week", "School week"], ["day", "School day"]] },
            { key: "group", label: "My group (empty = all)", kind: "text", def: "" },
            { key: "show_count", simple: true, label: "Show the lessons (e.g. 5 of 30)", kind: "bool", def: true }
        ]
    },
    visualizer: {
        label: "Visualizer", desc: "Audio-reactive bars (cava)", icon: "bars", size: [460, 150], file: "VisualizerWidget.qml",
        style: { bg_alpha: 0.45 },
        props: [
            { key: "bars", simple: true, label: "Number of bars", kind: "int", def: 32, min: 6, max: 96, step: 1 },
            { key: "mode", simple: true, label: "Display", kind: "choice", def: "bars", options: [["bars", "Bars"], ["mirror", "Mirrored"], ["line", "Line"]] },
            { key: "gradient", label: "Gradient", kind: "bool", def: true },
            { key: "color2", label: "Second colour (gradient)", kind: "color", def: "theme:secondary" },
            { key: "gap", label: "Spacing", kind: "range", def: 0.35, min: 0.05, max: 0.8, step: 0.01 },
            { key: "fps", label: "Smoothness (frames per second)", kind: "choice", def: "30", options: [["20", "20 (lowest CPU)"], ["30", "30 (default)"], ["45", "45 (smoother)"], ["60", "60 (smoothest)"]] },
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
