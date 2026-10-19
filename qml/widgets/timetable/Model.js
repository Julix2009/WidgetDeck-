.pragma library
// Timetable logic without any UI: grouping of parallel lessons, current / next lesson, progress, school days.
// Input = the json of untis.py: { grid: {MON: [{label,start,end}]}, lessons: [{date,start,end,slot,subject,room,teacher,klass,group,state,note,subst}] }.
// Times are "HH:MM", dates "YYYY-MM-DD" (local time).

var DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

function mins(t) { var p = String(t || "").split(":"); return p.length === 2 ? parseInt(p[0], 10) * 60 + parseInt(p[1], 10) : -1; }
function pad(n) { return (n < 10 ? "0" : "") + n; }
function ymd(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
function parseDate(s) { var p = String(s).split("-"); return new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10)); }
function addDays(d, n) { var r = new Date(d.getFullYear(), d.getMonth(), d.getDate() + n); return r; }
function dayKey(d) { return DAYS[d.getDay()]; }
function minutesOf(now) { return now.getHours() * 60 + now.getMinutes(); }

// lessons of one day, grouped by start time. group: the user's own group ("" = show everything).
// -> [{start, end, slot, main, others: [lessons], parallel: n, replaced: bool}]
function entries(lessons, dateStr, group) {
    var by = {}, order = [], i, l;
    for (i = 0; i < lessons.length; i++) {
        l = lessons[i];
        if (l.date !== dateStr) continue;
        var k = l.start + "-" + l.end;
        if (!by[k]) { by[k] = []; order.push(k); }
        by[k].push(l);
    }
    order.sort(function (a, b) { return mins(a.split("-")[0]) - mins(b.split("-")[0]); });
    var out = [];
    for (i = 0; i < order.length; i++) {
        var list = by[order[i]], mine = [], rest = [], j;
        for (j = 0; j < list.length; j++) {
            if (group === "" || !list[j].group || list[j].group === group) mine.push(list[j]); else rest.push(list[j]);
        }
        if (mine.length === 0) { mine = rest; rest = []; }
        // a cancelled lesson next to a real one at the same time: the real one is the replacement
        var live = mine.filter(function (x) { return x.state !== "cancelled"; });
        var main = live.length > 0 ? live[0] : mine[0];
        var replaced = live.length > 0 && live.length < mine.length;
        var others = mine.filter(function (x) { return x !== main; }).concat(rest);
        out.push({ start: list[0].start, end: list[0].end, slot: main.slot || "", main: main, others: others, parallel: others.length, replaced: replaced });
    }
    return out;
}

// the entry that runs right now (minute precision) or -1
function currentIndex(es, nowMin) {
    for (var i = 0; i < es.length; i++) if (nowMin >= mins(es[i].start) && nowMin < mins(es[i].end)) return i;
    return -1;
}
// the first entry that has not started yet (cancelled ones included, so a cancellation is visible in advance) or -1
function nextIndex(es, nowMin) {
    for (var i = 0; i < es.length; i++) if (mins(es[i].start) > nowMin) return i;
    return -1;
}
function progress(e, nowMin) {
    var a = mins(e.start), b = mins(e.end);
    return b > a ? Math.max(0, Math.min(1, (nowMin - a) / (b - a))) : 0;
}
function remaining(e, nowMin) { return Math.max(0, mins(e.end) - nowMin); }

// the next day (starting at `from`, up to 21 days ahead) that has lessons -> {date: Date, entries}
function nextSchoolDay(lessons, from, group) {
    for (var i = 0; i < 21; i++) {
        var d = addDays(from, i), es = entries(lessons, ymd(d), group);
        if (es.length > 0) return { date: d, entries: es };
    }
    return null;
}

// what the compact view shows
// -> {kind: "now"|"break"|"before"|"free", cur, next, nextDay}
function summary(lessons, now, group) {
    var today = ymd(now), nm = minutesOf(now), es = entries(lessons, today, group);
    var ci = currentIndex(es, nm), ni = nextIndex(es, nm);
    if (ci >= 0) return { kind: "now", cur: es[ci], next: ni >= 0 ? es[ni] : null, nextDay: null, entries: es };
    if (ni >= 0) return { kind: es.length > 0 && nm < mins(es[0].start) ? "before" : "break", cur: null, next: es[ni], nextDay: null, entries: es };
    var nd = nextSchoolDay(lessons, addDays(now, 1), group);
    return { kind: "free", cur: null, next: nd ? nd.entries[0] : null, nextDay: nd ? nd.date : null, entries: es };
}

// school-day indexes for the week grid: Monday .. last day with lessons (at least Friday)
function weekDays(now) {
    var mon = addDays(now, -((now.getDay() + 6) % 7)), out = [];
    for (var i = 0; i < 5; i++) out.push(addDays(mon, i));
    return out;
}
// distinct slot rows for a set of days from the grid (label + times), taken from the school's time grid
function gridRows(grid, days) {
    var rows = {}, order = [];
    for (var i = 0; i < days.length; i++) {
        var g = grid[dayKey(days[i])] || [];
        for (var j = 0; j < g.length; j++) {
            var k = g[j].start;
            if (!rows[k]) { rows[k] = { label: g[j].label, start: g[j].start, end: g[j].end }; order.push(k); }
        }
    }
    order.sort(function (a, b) { return mins(a) - mins(b); });
    return order.map(function (k) { return rows[k]; });
}
// the entry of `date` whose start equals `start` (week grid cell)
function cell(lessons, date, start, group) {
    var es = entries(lessons, ymd(date), group);
    for (var i = 0; i < es.length; i++) if (es[i].start === start) return es[i];
    return null;
}
// a break / free period: gap between two entries of the day (>= 30 min counts as a longer break)
function gapAfter(es, i) { return i + 1 < es.length ? mins(es[i + 1].start) - mins(es[i].end) : 0; }
