// Weather card: logic without UI (tested by tools/weathercard-test.js). Weather codes -> icon kind, icon layer recipes, hour / day labels,
// and the normalised model the card shows (built from the JSON of sysmon/weather.sh).
var KINDS = ["clear", "mostly_clear", "partly", "cloudy", "fog", "drizzle", "rain", "heavy_rain", "thunder", "snow", "sleet", "hail", "unknown"];

// WMO weather code (Open-Meteo) -> icon kind. Anything unknown gets the neutral fallback, never an empty field.
function kindOf(code) {
    var c = Number(code);
    if (code === undefined || code === null || code === "" || isNaN(c)) return "unknown";
    if (c === 0) return "clear";
    if (c === 1) return "mostly_clear";
    if (c === 2) return "partly";
    if (c === 3) return "cloudy";
    if (c === 45 || c === 48) return "fog";
    if (c === 56 || c === 57 || c === 66 || c === 67) return "sleet";
    if (c >= 51 && c <= 55) return "drizzle";
    if (c === 65 || c === 82) return "heavy_rain";
    if (c === 61 || c === 63 || c === 80 || c === 81) return "rain";
    if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "snow";
    if (c === 96 || c === 99) return "hail";
    if (c === 95) return "thunder";
    return "unknown";
}
function isKind(k) { return KINDS.indexOf(k) >= 0; }

// ---- icon recipes: layers of baked sprites on a 0..1 box. s = sprite, x / y = centre, w = width (box fraction), d = depth for the hover
// parallax (-1 far .. 1 near), m = idle motion (float | drift | breathe | fall | spin | twinkle | flicker | none), p = phase
function L(s, x, y, w, d, m, p) { return { s: s, x: x, y: y, w: w, d: d, m: m || "none", p: p || 0 }; }
function layersFor(kind, day) {
    var sun = !!day;
    var drops = function (xs, y0, w) { var o = []; for (var i = 0; i < xs.length; i++) o.push(L("drop", xs[i], y0 + (i % 2) * 0.07, w, 0.6, "fall", i)); return o; };
    switch (kind) {
    case "clear":
        return sun ? [L("glow", 0.5, 0.5, 1.15, -0.6, "breathe"), L("sun", 0.5, 0.5, 0.78, 0.3, "breathe")]
                   : [L("moon", 0.5, 0.5, 0.78, 0.3, "breathe"), L("star", 0.8, 0.22, 0.2, -0.4, "twinkle", 0), L("star", 0.2, 0.3, 0.13, -0.5, "twinkle", 1), L("star", 0.84, 0.72, 0.11, -0.5, "twinkle", 2)];
    case "mostly_clear":
        return sun ? [L("glow", 0.4, 0.4, 1.0, -0.6, "breathe"), L("sun", 0.4, 0.4, 0.66, 0.2, "breathe"), L("cloud", 0.64, 0.66, 0.66, 0.9, "drift", 0)]
                   : [L("moon", 0.4, 0.4, 0.66, 0.2, "breathe"), L("star", 0.8, 0.2, 0.15, -0.4, "twinkle", 0), L("cloud", 0.64, 0.66, 0.66, 0.9, "drift", 0)];
    case "partly":
        return sun ? [L("glow", 0.36, 0.36, 0.95, -0.6, "breathe"), L("sun", 0.36, 0.36, 0.6, 0.2, "breathe"), L("cloud", 0.58, 0.62, 0.98, 0.9, "drift", 0)]
                   : [L("moon", 0.36, 0.36, 0.58, 0.2, "breathe"), L("star", 0.82, 0.2, 0.13, -0.4, "twinkle", 0), L("cloud", 0.58, 0.62, 0.98, 0.9, "drift", 0)];
    case "cloudy":
        return [L("cloud_grey", 0.36, 0.38, 0.74, -0.2, "drift", 1), L("cloud", 0.6, 0.6, 1.02, 0.9, "drift", 0)];
    case "fog":
        return [L("cloud_grey", 0.5, 0.34, 0.92, 0.4, "drift", 0), L("fogbar", 0.42, 0.64, 0.62, 0.2, "drift", 1), L("fogbar", 0.58, 0.77, 0.54, 0.3, "drift", 2), L("fogbar", 0.46, 0.9, 0.6, 0.4, "drift", 3)];
    case "drizzle":
        return [L("cloud", 0.5, 0.4, 1.0, 0.8, "drift", 0)].concat(drops([0.34, 0.5, 0.66], 0.74, 0.27));
    case "rain":
        return [L("cloud_grey", 0.5, 0.38, 1.02, 0.8, "drift", 0)].concat(drops([0.28, 0.43, 0.58, 0.73], 0.73, 0.3));
    case "heavy_rain":
        return [L("cloud_dark", 0.5, 0.36, 1.04, 0.8, "drift", 0)].concat(drops([0.24, 0.37, 0.5, 0.63, 0.76], 0.72, 0.32));
    case "thunder":
        return [L("cloud_dark", 0.5, 0.34, 1.04, 0.8, "drift", 0), L("bolt", 0.52, 0.76, 0.46, 0.5, "flicker"), L("drop", 0.25, 0.78, 0.28, 0.6, "fall", 0), L("drop", 0.8, 0.76, 0.28, 0.6, "fall", 1)];
    case "snow":
        return [L("cloud", 0.5, 0.38, 1.0, 0.8, "drift", 0), L("flake", 0.3, 0.78, 0.27, 0.6, "spin", 0), L("flake", 0.5, 0.89, 0.23, 0.6, "spin", 1), L("flake", 0.7, 0.78, 0.27, 0.6, "spin", 2)];
    case "sleet":
        return [L("cloud_grey", 0.5, 0.38, 1.02, 0.8, "drift", 0), L("drop", 0.3, 0.77, 0.28, 0.6, "fall", 0), L("flake", 0.5, 0.88, 0.24, 0.6, "spin", 1), L("drop", 0.7, 0.77, 0.28, 0.6, "fall", 2)];
    case "hail":
        return [L("cloud_dark", 0.5, 0.34, 1.04, 0.8, "drift", 0), L("hail", 0.3, 0.78, 0.2, 0.6, "fall", 0), L("hail", 0.46, 0.89, 0.2, 0.6, "fall", 1), L("hail", 0.62, 0.78, 0.2, 0.6, "fall", 2), L("hail", 0.77, 0.89, 0.2, 0.6, "fall", 3)];
    default:
        return [L("cloud_grey", 0.5, 0.5, 0.92, 0.4, "drift", 0)];
    }
}

// ---- sky gradient (milk-glass mode only): [top, bottom] colours for a weather kind and day / night
function skyColors(kind, day) {
    if (!day) return (kind === "clear" || kind === "mostly_clear" || kind === "partly") ? ["#101a3a", "#2c3f78"] : ["#1a2036", "#394560"];
    switch (kind) {
    case "clear": case "mostly_clear": return ["#2f7fe0", "#74bdf8"];
    case "partly": return ["#4a86d0", "#8fbde6"];
    case "cloudy": case "fog": case "unknown": return ["#68788f", "#a0afc2"];
    case "drizzle": case "rain": case "sleet": return ["#4d5d78", "#7d8ca6"];
    case "heavy_rain": case "thunder": case "hail": return ["#38405a", "#5c6482"];
    case "snow": return ["#8aa2c2", "#cddbed"];
    default: return ["#68788f", "#a0afc2"];
    }
}

// ---- labels
function use12h(timeFormat, localeShortFmt) {
    var t = timeFormat || "auto";
    if (t === "12h") return true;
    if (t === "24h") return false;
    return /[aA]/.test(String(localeShortFmt || "").replace(/'[^']*'/g, ""));
}
// "14:00" -> "14:00" or "2 PM"
function hourLabel(t, twelve) {
    var h = parseInt(String(t).substring(0, 2), 10);
    if (isNaN(h)) return "";
    if (!twelve) return (h < 10 ? "0" : "") + h + ":00";
    return (h % 12 === 0 ? 12 : h % 12) + " " + (h < 12 ? "AM" : "PM");
}
function weekday(dateStr) {       // "2026-10-20" -> 0..6 (Sunday = 0), calendar arithmetic only (no time zone)
    var p = String(dateStr).split("-");
    if (p.length < 3) return -1;
    return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]), 12, 0, 0).getDay();
}
function num(v) { var n = Number(v); return (v === undefined || v === null || v === "" || isNaN(n)) ? null : Math.round(n); }

// normalised model from the JSON of weather.sh (missing parts stay null / empty so the card can hide them)
function model(d, count, days) {
    if (!d || d.current_temp === undefined) return null;
    var hours = [], i;
    var hl = d.hourly || [];
    for (i = 0; i < hl.length && hours.length < count; i++)
        hours.push({ t: hl[i].t, temp: num(hl[i].temp), kind: kindOf(hl[i].code), day: hl[i].day !== 0 });
    var dl = [], dd = d.daily || [];
    for (i = 0; i < dd.length && dl.length < days; i++)
        dl.push({ date: dd[i].date, max: num(dd[i].max), min: num(dd[i].min), kind: kindOf(dd[i].code) });
    var f = d.forecast && d.forecast.length ? d.forecast[0] : null;
    return {
        place: d.place || "", unit: d.unit || "°C",
        temp: num(d.current_temp), feels: f ? num(f.feels_like) : null,
        hi: f ? num(f.max) : (dl.length ? dl[0].max : null), lo: f ? num(f.min) : (dl.length ? dl[0].min : null),
        code: d.current_code, kind: kindOf(d.current_code), day: d.is_day !== 0,
        pop: (d.pop === undefined || d.pop === null) ? null : num(d.pop),
        desc: f && f.desc ? f.desc : "",
        hours: hours, days: dl, stale: !!d.stale, fetched: d.fetched || 0
    };
}
// range of all shown daily values (for the thin temperature bars)
function dayRange(dl) {
    var lo = null, hi = null;
    for (var i = 0; i < dl.length; i++) {
        if (dl[i].min !== null && (lo === null || dl[i].min < lo)) lo = dl[i].min;
        if (dl[i].max !== null && (hi === null || dl[i].max > hi)) hi = dl[i].max;
    }
    return { lo: lo, hi: hi };
}
