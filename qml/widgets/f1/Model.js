// F1 widget: logic without UI (tested by tools/f1-test.js). Input = the JSON of f1.py (UTC times as ISO strings); every function takes `now` as a Date, so the
// tests can set any moment. All local times come from the Date object itself (system time zone, daylight saving included): nothing is computed by hand.
var DURATION = { FirstPractice: 60, SecondPractice: 60, ThirdPractice: 60, SprintQualifying: 45, Sprint: 35, Qualifying: 65, Race: 130 };   // minutes: "running now" window
var ORDER = ["FirstPractice", "SecondPractice", "ThirdPractice", "SprintQualifying", "Sprint", "Qualifying", "Race"];
var FINISHED_HOLD_MIN = 6 * 60;           // after the race the finished weekend stays in front for 6 hours, then the next race takes over

function toDate(s) { if (!s) return null; var d = new Date(s); return isNaN(d.getTime()) ? null : d; }

// the sessions of a race weekend with their state at `now`: past | running | next | future | open (no time known)
function sessionsOf(race, now) {
    var out = [], i, nextSet = false, list = (race && race.sessions) ? race.sessions.slice() : [];
    list.sort(function (a, b) { var x = toDate(a.start), y = toDate(b.start); return x && y ? x - y : ORDER.indexOf(a.key) - ORDER.indexOf(b.key); });
    for (i = 0; i < list.length; i++) {
        var s = list[i], st = toDate(s.start), mins = DURATION[s.key] || 60, en = st ? new Date(st.getTime() + mins * 60000) : null, state = "open";
        if (st) { state = now >= en ? "past" : (now >= st ? "running" : "future"); }
        out.push({ key: s.key, start: st, end: en, state: state, date: s.date || "" });
    }
    for (i = 0; i < out.length; i++) if (out[i].state === "future" && !nextSet) { out[i].state = "next"; nextSet = true; }
    return out;
}
function raceSession(race) { var l = (race && race.sessions) || []; for (var i = 0; i < l.length; i++) if (l[i].key === "Race") return l[i]; return null; }
function raceStart(race) { var s = raceSession(race); return s ? toDate(s.start) : null; }
// when the weekend is over: the race's end (or the end of its date when no time is known)
function raceEnd(race) {
    var st = raceStart(race);
    if (st) return new Date(st.getTime() + DURATION.Race * 60000);
    var d = toDate((race && race.date ? race.date : "") + "T23:59:59Z");
    return d;
}
function isSprint(race) { var l = (race && race.sessions) || []; for (var i = 0; i < l.length; i++) if (l[i].key === "Sprint" || l[i].key === "SprintQualifying") return true; return false; }

// what the widget shows: { kind: upcoming | running | finished | cancelled | seasonend | empty, race, prev, next, sessions }
function stateOf(data, now) {
    if (!data || !data.races || data.races.length === 0) return { kind: "empty" };
    var races = data.races.slice().sort(function (a, b) { return (a.date || "") < (b.date || "") ? -1 : 1; }), i;
    // a session is running
    for (i = 0; i < races.length; i++) {
        if (races[i].cancelled) continue;
        var ss = sessionsOf(races[i], now);
        for (var j = 0; j < ss.length; j++) if (ss[j].state === "running") return { kind: "running", race: races[i], sessions: ss, running: ss[j], next: following(races, i) };
    }
    // the race ended a few hours ago: the finished weekend stays in front for a while
    for (i = races.length - 1; i >= 0; i--) {
        var en = raceEnd(races[i]);
        if (!races[i].cancelled && en && now >= en && now < new Date(en.getTime() + FINISHED_HOLD_MIN * 60000))
            return { kind: "finished", race: races[i], sessions: sessionsOf(races[i], now), next: following(races, i) };
    }
    // the first weekend that is not over
    for (i = 0; i < races.length; i++) {
        var e2 = raceEnd(races[i]);
        if (e2 && now >= e2) continue;
        if (!e2 && races[i].date && now >= toDate(races[i].date + "T23:59:59Z")) continue;
        if (races[i].cancelled) return { kind: "cancelled", race: races[i], next: following(races, i), sessions: [] };
        return { kind: "upcoming", race: races[i], sessions: sessionsOf(races[i], now), next: following(races, i) };
    }
    return { kind: "seasonend", race: races[races.length - 1] };
}
function following(races, i) { for (var k = i + 1; k < races.length; k++) if (!races[k].cancelled) return races[k]; return null; }

// the champion of a finished season = leader of the standings (only when the standings are from the last round)
function champion(data) {
    if (!data || !data.standings || data.standings.length === 0 || !data.races || data.races.length === 0) return null;
    var lastRound = 0; for (var i = 0; i < data.races.length; i++) lastRound = Math.max(lastRound, data.races[i].round);
    return data.standings_round >= lastRound ? data.standings[0] : null;
}
function roundText(data, race) { return race ? { round: race.round, total: data.races.length } : null; }

// ---- countdown
function parts(target, now) {
    var ms = Math.max(0, target.getTime() - now.getTime()), s = Math.floor(ms / 1000);
    return { d: Math.floor(s / 86400), h: Math.floor(s % 86400 / 3600), m: Math.floor(s % 3600 / 60), s: s % 60, total: s };
}
// the clock ticks every second in the last hour before the start, else once a minute (the display only shows seconds then)
function tickMs(target, now) { return (target && target.getTime() - now.getTime() < 3600000) ? 1000 : 60000; }

// ---- labels
function use12h(timeFormat, localeShortFmt) {
    var t = timeFormat || "auto";
    if (t === "12h") return true;
    if (t === "24h") return false;
    return /[aA]/.test(String(localeShortFmt || "").replace(/'[^']*'/g, ""));
}
function two(n) { return (n < 10 ? "0" : "") + n; }
function timeText(d, twelve) {
    if (!d) return "";
    var h = d.getHours(), m = d.getMinutes();
    if (!twelve) return two(h) + ":" + two(m);
    return (h % 12 === 0 ? 12 : h % 12) + ":" + two(m) + " " + (h < 12 ? "AM" : "PM");
}
// "Fr 23.10." (de) / "Fri Oct 23" (en); the LOCAL date (a 23:00 UTC session can be tomorrow here)
function dateText(d, dayShort, monthShort, lang) {
    if (!d) return "";
    var wd = dayShort[d.getDay()];
    return lang === "de" ? wd + " " + d.getDate() + "." + (d.getMonth() + 1) + "." : wd + " " + monthShort[d.getMonth()] + " " + d.getDate();
}
function ymdLocal(d) { return d.getFullYear() + "-" + two(d.getMonth() + 1) + "-" + two(d.getDate()); }

var ISO2 = { "USA": "US", "United States": "US", "UK": "GB", "United Kingdom": "GB", "UAE": "AE", "United Arab Emirates": "AE", "Netherlands": "NL", "Malaysia": "MY", "Australia": "AU", "China": "CN",
             "Japan": "JP", "Italy": "IT", "Monaco": "MC", "Spain": "ES", "Canada": "CA", "Austria": "AT", "Belgium": "BE", "Hungary": "HU", "Azerbaijan": "AZ", "Singapore": "SG", "Mexico": "MX",
             "Brazil": "BR", "Qatar": "QA", "Bahrain": "BH", "Saudi Arabia": "SA", "Germany": "DE", "France": "FR", "Portugal": "PT", "Turkey": "TR", "Argentina": "AR", "South Africa": "ZA",
             "Russia": "RU", "Korea": "KR", "India": "IN", "Switzerland": "CH", "Sweden": "SE", "Morocco": "MA", "Vietnam": "VN", "Indonesia": "ID" };
function iso2(country) { return ISO2[country] || ""; }
// the flag as an emoji (two regional-indicator letters); "" when the country is unknown
function flag(country) {
    var c = iso2(country);
    if (c.length !== 2) return "";
    return String.fromCodePoint(0x1F1E6 + c.charCodeAt(0) - 65, 0x1F1E6 + c.charCodeAt(1) - 65);
}

// ---- track outline: the stored points (0..1000 box) fitted into w x h with a fixed padding. Uniform scale, centred; only coordinates change (no item scale).
function fit(c, w, h, pad) {
    if (!c || !c.pts || c.pts.length < 4) return null;
    var aw = Math.max(1, w - 2 * pad), ah = Math.max(1, h - 2 * pad), s = Math.min(aw / Math.max(1, c.w), ah / Math.max(1, c.h));
    var ox = pad + (aw - c.w * s) / 2, oy = pad + (ah - c.h * s) / 2, d = "", i, x, y, len = 0, px = 0, py = 0;
    for (i = 0; i < c.pts.length; i += 2) {
        x = ox + c.pts[i] * s; y = oy + c.pts[i + 1] * s;
        d += (i === 0 ? "M " : " L ") + x.toFixed(1) + " " + y.toFixed(1);
        if (i > 0) len += Math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
        px = x; py = y;
    }
    var x0 = ox + c.pts[0] * s, y0 = oy + c.pts[1] * s;
    if (c.closed) { d += " Z"; len += Math.sqrt((x0 - px) * (x0 - px) + (y0 - py) * (y0 - py)); }
    // direction at the start (towards the second point) for the start / finish marker
    var ang = Math.atan2(c.pts[3] - c.pts[1], c.pts[2] - c.pts[0]);
    return { d: d, len: len, sx: x0, sy: y0, ang: ang, scale: s, w: c.w * s, h: c.h * s, ox: ox, oy: oy };
}

// reminder: which sessions start in `lead` minutes (±the poll interval) and have not been announced yet
function remindersDue(race, now, leadMin, wanted, done) {
    var out = [], ss = sessionsOf(race, now);
    for (var i = 0; i < ss.length; i++) {
        var s = ss[i];
        if (!s.start || wanted.indexOf(s.key) < 0) continue;
        var left = (s.start.getTime() - now.getTime()) / 60000;
        var id = race.round + ":" + s.key;
        if (left <= leadMin && left > 0 && done.indexOf(id) < 0) out.push({ id: id, key: s.key, start: s.start, race: race });
    }
    return out;
}

// the same path moved by (dx, dy) - for the drop shadow of the outline (coordinates only)
function shiftPath(d, dx, dy) {
    return d.replace(/(-?\d+(?:\.\d+)?) (-?\d+(?:\.\d+)?)/g, function (m, x, y) { return (parseFloat(x) + dx).toFixed(1) + " " + (parseFloat(y) + dy).toFixed(1); });
}

// ---- German names (the data comes in English): "United States Grand Prix" -> "Großer Preis der USA"; unknown names stay as they are
var GP_DE = { "Australian": "von Australien", "Chinese": "von China", "Japanese": "von Japan", "Miami": "von Miami", "Canadian": "von Kanada", "Monaco": "von Monaco", "Barcelona": "von Barcelona-Katalonien",
              "Spanish": "von Spanien", "Austrian": "von Österreich", "British": "von Großbritannien", "Belgian": "von Belgien", "Hungarian": "von Ungarn", "Dutch": "der Niederlande", "Italian": "von Italien",
              "Azerbaijan": "von Aserbaidschan", "Singapore": "von Singapur", "United States": "der USA", "Mexico City": "von Mexiko-Stadt", "Mexican": "von Mexiko", "Brazilian": "von Brasilien",
              "São Paulo": "von São Paulo", "Sao Paulo": "von São Paulo", "Las Vegas": "von Las Vegas", "Qatar": "von Katar", "Abu Dhabi": "von Abu Dhabi", "Bahrain": "von Bahrain",
              "Saudi Arabian": "von Saudi-Arabien", "Emilia Romagna": "der Emilia-Romagna", "Madrid": "von Madrid", "French": "von Frankreich", "German": "von Deutschland", "Portuguese": "von Portugal",
              "Turkish": "der Türkei", "Russian": "von Russland", "Argentine": "von Argentinien", "South African": "von Südafrika", "Malaysian": "von Malaysia", "Styrian": "der Steiermark",
              "70th Anniversary": "zum 70-jährigen Jubiläum", "Eifel": "der Eifel", "Tuscan": "der Toskana", "Sakhir": "von Sakhir" };
function raceName(name, lang) {
    if (lang !== "de" || !name) return name || "";
    var m = /^(.+?) Grand Prix( .*)?$/.exec(name);
    if (m && GP_DE[m[1]] && !m[2]) return "Großer Preis " + GP_DE[m[1]];
    return name;
}
var COUNTRY_DE = { "USA": "USA", "UK": "Großbritannien", "UAE": "Vereinigte Arabische Emirate", "Netherlands": "Niederlande", "Malaysia": "Malaysia", "Australia": "Australien", "China": "China", "Japan": "Japan",
                   "Italy": "Italien", "Monaco": "Monaco", "Spain": "Spanien", "Canada": "Kanada", "Austria": "Österreich", "Belgium": "Belgien", "Hungary": "Ungarn", "Azerbaijan": "Aserbaidschan",
                   "Singapore": "Singapur", "Mexico": "Mexiko", "Brazil": "Brasilien", "Qatar": "Katar", "Bahrain": "Bahrain", "Saudi Arabia": "Saudi-Arabien", "Germany": "Deutschland", "France": "Frankreich",
                   "Portugal": "Portugal", "Turkey": "Türkei", "Argentina": "Argentinien", "South Africa": "Südafrika", "Russia": "Russland" };
function countryName(c, lang) { return lang === "de" && COUNTRY_DE[c] ? COUNTRY_DE[c] : (c || ""); }
