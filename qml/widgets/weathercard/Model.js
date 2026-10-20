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

// ---- icon sets: every weather kind has ONE rendered icon (tools/blender: Blender renders of soft clay-like objects) made of aligned layers,
// back to front. `variantKey` picks the set (day / night only where the sky shows: clear, mostly clear, partly cloudy).
// Layer hints: d = depth for the idle parallax (-1 far .. 1 near), m = idle motion (float | drift | breathe | fall | sway | twinkle | flicker), p = phase.
// image format of the rendered sprites (webp needs the Qt image plugin qt6-imageformats; png works everywhere)
var ICON_EXT = "png";
var VARIANTS = {
    clear_day: ["sun"], clear_night: ["moon", "stars"],
    mostly_clear_day: ["sun", "cloud"], mostly_clear_night: ["moon", "stars", "cloud"],
    partly_day: ["sun", "cloud"], partly_night: ["moon", "cloud"],
    cloudy: ["cloud_back", "cloud"], fog: ["cloud", "fog"],
    drizzle: ["cloud", "drops_a", "drops_b"], rain: ["cloud", "drops_a", "drops_b"], heavy_rain: ["cloud", "drops_a", "drops_b"],
    thunder: ["cloud", "bolt", "drops_a"], snow: ["cloud", "flakes_a", "flakes_b"], sleet: ["cloud", "drops_a", "flakes_a"],
    hail: ["cloud", "hail_a", "hail_b"], unknown: ["cloud"]
};
// warm glow behind the sun: [x, z, size] in the units of the Blender scene (the frame spans +-1.125)
var GLOWS = { clear_day: [0, 0, 1.5], mostly_clear_day: [-0.18, 0.2, 1.2], partly_day: [-0.28, 0.28, 1.05] };
var LAYER_HINTS = {
    sun: { d: 0.3, m: "breathe" }, moon: { d: 0.3, m: "breathe" }, stars: { d: -0.4, m: "twinkle" },
    cloud: { d: 0.8, m: "drift" }, cloud_back: { d: 0.2, m: "drift", p: 1 }, fog: { d: 0.4, m: "drift", p: 2 },
    drops_a: { d: 0.6, m: "fall", p: 0 }, drops_b: { d: 0.6, m: "fall", p: 3 }, flakes_a: { d: 0.6, m: "sway", p: 0 }, flakes_b: { d: 0.6, m: "sway", p: 3 },
    bolt: { d: 0.5, m: "flicker" }, hail_a: { d: 0.6, m: "fall", p: 0 }, hail_b: { d: 0.6, m: "fall", p: 3 }
};
function variantKey(kind, day) {
    var k = isKind(kind) ? kind : "unknown";
    return (k === "clear" || k === "mostly_clear" || k === "partly") ? k + (day ? "_day" : "_night") : k;
}
function layersFor(kind, day) {
    var key = variantKey(kind, day), ids = VARIANTS[key], out = [];
    for (var i = 0; i < ids.length; i++) { var h = LAYER_HINTS[ids[i]] || {}; out.push({ key: key, id: ids[i], d: h.d || 0, m: h.m || "none", p: h.p || 0 }); }
    return out;
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
