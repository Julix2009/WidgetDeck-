.pragma library
// World clock for the clock widget: read the setting, parse the output of worldclock.sh, show the time of another zone.
// The QML engine has no Intl and ignores the timeZone option of toLocaleString, so the UTC offsets come from the
// system's tzdata through worldclock.sh (one shared feed, refreshed every 15 minutes).

var MAX_ZONES = 6;

// "America/Argentina/Buenos_Aires" -> "Buenos Aires"
function cityOf(zone) {
    var s = String(zone).split("/");
    return s[s.length - 1].replace(/_/g, " ");
}

// "Asia/Tokyo, America/New_York=NYC" -> [{ zone: "Asia/Tokyo", label: "Tokyo" }, { zone: "America/New_York", label: "NYC" }]
// separators: comma, semicolon or new line; "=" gives an own label; duplicates and entries past MAX_ZONES are dropped
function parseZones(text) {
    var out = [], seen = {};
    String(text || "").split(/[,;\n]/).forEach(function (part) {
        var p = part.trim();
        if (p === "" || out.length >= MAX_ZONES) return;
        var eq = p.indexOf("=");
        var zone = (eq >= 0 ? p.slice(0, eq) : p).trim().replace(/\s+/g, "_");
        var label = eq >= 0 ? p.slice(eq + 1).trim() : "";
        if (zone === "" || seen[zone]) return;
        seen[zone] = true;
        out.push({ zone: zone, label: label !== "" ? label : cityOf(zone) });
    });
    return out;
}

// "+0930" -> 570, "-0500" -> -300, anything else -> NaN
function offsetMinutes(s) {
    var m = /^([+-])(\d\d)(\d\d)$/.exec(String(s).trim());
    if (!m) return NaN;
    var v = Number(m[2]) * 60 + Number(m[3]);
    return m[1] === "-" ? -v : v;
}

// worldclock.sh output ("zone \t unix time \t +hhmm" or "zone \t bad" per line) ->
// { "Asia/Tokyo": [[ms, offset minutes], ...] sorted by time, "No/Such_Zone": null }
function parseOffsets(text) {
    var o = {};
    String(text || "").split("\n").forEach(function (line) {
        var f = line.split("\t");
        if (f.length < 2 || f[0] === "") return;
        if (f[1] === "bad") { o[f[0]] = null; return; }
        var t = Number(f[1]), off = offsetMinutes(f[2]);
        if (!isFinite(t) || !isFinite(off) || o[f[0]] === null) return;
        (o[f[0]] = o[f[0]] || []).push([t * 1000, off]);
    });
    for (var k in o) if (o[k]) o[k].sort(function (a, b) { return a[0] - b[0]; });
    return o;
}

// the offset that applies at ms: the last sample at or before it (before the first sample: the first one)
function offsetAt(samples, ms) {
    if (!samples || samples.length === 0) return NaN;
    var off = samples[0][1];
    for (var i = 0; i < samples.length && samples[i][0] <= ms; i++) off = samples[i][1];
    return off;
}

// true when the samples no longer reach the given time (after standby): ask the helper again
function stale(samples, ms) {
    return !samples || samples.length === 0 || samples[samples.length - 1][0] + 15 * 60000 < ms;
}

// a Date-like object whose local getters show the wall time of the zone; enough for the clock widget's fmt()
// (built on UTC getters, so a daylight saving gap of the LOCAL zone cannot shift it)
function zoned(ms, offMin) {
    var u = new Date(ms + offMin * 60000);
    return {
        getHours: function () { return u.getUTCHours(); },
        getMinutes: function () { return u.getUTCMinutes(); },
        getSeconds: function () { return u.getUTCSeconds(); },
        getDate: function () { return u.getUTCDate(); },
        getDay: function () { return u.getUTCDay(); },
        getMonth: function () { return u.getUTCMonth(); },
        getFullYear: function () { return u.getUTCFullYear(); }
    };
}

// calendar day of the zone minus the local calendar day: -1, 0 or +1
function dayShift(now, offMin) {
    var z = new Date(now.getTime() + offMin * 60000);
    var zd = Date.UTC(z.getUTCFullYear(), z.getUTCMonth(), z.getUTCDate());
    var ld = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
    return Math.round((zd - ld) / 86400000);
}

// "+1" / "−1" as small raised digits, "" for the same day
function dayMark(shift) {
    if (!shift) return "";
    var sup = { "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹" };
    return (shift > 0 ? "⁺" : "⁻") + String(Math.abs(shift)).split("").map(function (c) { return sup[c]; }).join("");
}

// one line for all zones: "Tokyo 17:26⁺¹ · NYC 03:26"; spaces inside an entry do not break, so the line only wraps between entries
// fmtTime(dateLike) formats a time; offsets = parseOffsets(...); pending / unknown zones show "–" / "?"
function line(zones, offsets, now, fmtTime) {
    var nb = " ", ms = now.getTime();
    return zones.map(function (z) {
        var s = offsets ? offsets[z.zone] : undefined, t;
        if (s === null) t = "?";
        else {
            var off = offsetAt(s, ms);
            t = isFinite(off) ? fmtTime(zoned(ms, off)) + dayMark(dayShift(now, off)) : "–";
        }
        return (z.label + " " + t).replace(/ /g, nb);
    }).join("  ·  ");
}
