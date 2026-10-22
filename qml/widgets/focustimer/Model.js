.pragma library
// Focus timer (Pomodoro): the logic without any UI (tested by tools/focus-timer-test.js).
// Time is never counted in ticks: a running phase has an absolute end (endsAt, ms since the epoch), a paused one a stored remaining time. So the
// remaining time is right after standby, after a hanging UI and after a restart of the shell.
//
// state    { v, phase: "focus"|"short"|"long", cycle, running, endsAt, remainingMs }
//          cycle = focus sessions completed in the current set (the dots); a set ends with the long break
// settings { focus_min, short_min, long_min, cycles, auto_next, debug_fast }   (debug_fast: phases of seconds for testing)
// events   what happened, for the service (stats, sound, notification): { completed, phase, next, late, seconds }

var PHASES = ["focus", "short", "long"];
var GRACE_MS = 15000;                          // a phase that ended more than this ago while nobody was looking is "missed": silent, next phase paused
var DEBUG_MS = { focus: 10000, short: 4000, long: 6000 };
var KEEP_DAYS = 365;

function num(v, d, lo, hi) { v = Number(v); if (!isFinite(v)) v = d; return Math.max(lo, Math.min(hi, v)); }
function cleanSettings(s) {
    s = s || {};
    return { focus_min: num(s.focus_min, 25, 1, 180), short_min: num(s.short_min, 5, 1, 60), long_min: num(s.long_min, 15, 1, 120),
             cycles: Math.round(num(s.cycles, 4, 1, 12)), auto_next: s.auto_next === true, debug_fast: s.debug_fast === true };
}
function durationMs(settings, phase) {
    var s = cleanSettings(settings);
    if (s.debug_fast) return DEBUG_MS[phase] || DEBUG_MS.focus;
    return Math.round((phase === "short" ? s.short_min : phase === "long" ? s.long_min : s.focus_min) * 60000);
}
function fresh(settings) { return { v: 1, phase: "focus", cycle: 0, running: false, endsAt: 0, remainingMs: durationMs(settings, "focus") }; }
function remaining(st, now) { return st.running ? Math.max(0, st.endsAt - now) : Math.max(0, st.remainingMs); }

// the phase after this one; `completed` = a focus phase that really ended counts for the set
function following(st, settings, completed) {
    var s = cleanSettings(settings);
    if (st.phase === "focus") {
        var c = st.cycle + (completed ? 1 : 0);
        return { phase: completed && c >= s.cycles ? "long" : "short", cycle: c };
    }
    return { phase: "focus", cycle: st.phase === "long" ? 0 : st.cycle };
}
function enter(st, settings, nx, running, now) {
    var d = durationMs(settings, nx.phase);
    return { v: 1, phase: nx.phase, cycle: Math.min(nx.cycle, cleanSettings(settings).cycles), running: running, endsAt: running ? now + d : 0, remainingMs: d };
}

function start(st, now) {
    if (st.running) return st;
    var r = Math.max(1000, st.remainingMs);
    return { v: 1, phase: st.phase, cycle: st.cycle, running: true, endsAt: now + r, remainingMs: r };
}
function pause(st, now) {
    if (!st.running) return st;
    return { v: 1, phase: st.phase, cycle: st.cycle, running: false, endsAt: 0, remainingMs: remaining(st, now) };
}
function toggle(st, now) { return st.running ? pause(st, now) : start(st, now); }
function reset(settings) { return fresh(settings); }
// skip: the phase ends NOW without counting; the next one keeps the running / paused state
function skip(st, settings, now) {
    var nx = following(st, settings, false);
    return { state: enter(st, settings, nx, st.running, now), event: { completed: false, phase: st.phase, next: nx.phase, late: false, seconds: 0 } };
}
// finish: the phase ran out. late = it ran out a long time ago (shell not running, computer asleep): counted once, silent, the next phase waits paused
function finish(st, settings, now) {
    var late = st.running && now - st.endsAt > GRACE_MS;
    var nx = following(st, settings, true);
    var auto = cleanSettings(settings).auto_next && !late;
    var secs = st.phase === "focus" ? Math.round(durationMs(settings, "focus") / 1000) : 0;
    return { state: enter(st, settings, nx, auto, now), event: { completed: true, phase: st.phase, next: nx.phase, late: late, seconds: secs } };
}
// is it time? (the service asks on every wake-up and on every second of a visible widget)
function due(st, now) { return st.running && now >= st.endsAt; }

// the saved state of the last run: validated; a running phase that has ended meanwhile is finished (once), a clock that jumped back is clamped
function restore(raw, settings, now) {
    var st = fresh(settings), ev = null;
    try {
        if (raw && raw.v === 1 && PHASES.indexOf(raw.phase) >= 0) {
            st = { v: 1, phase: raw.phase, cycle: Math.max(0, Math.min(11, Math.round(Number(raw.cycle) || 0))), running: raw.running === true,
                   endsAt: Number(raw.endsAt) || 0, remainingMs: Number(raw.remainingMs) || 0 };
            var full = durationMs(settings, st.phase);
            if (st.running) {
                if (!(st.endsAt > 0)) st = pause({ v: 1, phase: st.phase, cycle: st.cycle, running: true, endsAt: now + full, remainingMs: full }, now);
                else if (st.endsAt - now > full + 3600000) st = { v: 1, phase: st.phase, cycle: st.cycle, running: true, endsAt: now + full, remainingMs: full };
            } else if (!(st.remainingMs > 0) || st.remainingMs > full) st.remainingMs = full;
            // it ended while nobody was looking (shell not running, computer asleep): counted once, silent, the next phase waits paused
            if (due(st, now)) { var r = finish(st, settings, now); st = r.state.running ? pause(r.state, now) : r.state; ev = r.event; ev.late = true; }
        }
    } catch (e) { st = fresh(settings); }
    return { state: st, event: ev };
}

// ---- statistics: { v: 1, days: { "YYYY-MM-DD": { sessions, focus_seconds } } }, only completed focus phases, the last 365 days
function dateKey(d) { return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2); }
function cleanStats(raw) {
    var out = { v: 1, days: {} };
    if (!raw || typeof raw !== "object" || raw.v !== 1 || !raw.days || typeof raw.days !== "object") return null;
    for (var k in raw.days) {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(k)) continue;
        var d = raw.days[k] || {};
        var s = Math.round(Number(d.sessions)), f = Math.round(Number(d.focus_seconds));
        if (isFinite(s) && isFinite(f) && s >= 0 && f >= 0) out.days[k] = { sessions: s, focus_seconds: f };
    }
    return out;
}
function addSession(stats, key, seconds) {
    var out = { v: 1, days: Object.assign({}, stats.days) };
    var d = out.days[key] || { sessions: 0, focus_seconds: 0 };
    out.days[key] = { sessions: d.sessions + 1, focus_seconds: d.focus_seconds + Math.max(0, Math.round(seconds)) };
    return prune(out, key);
}
function prune(stats, todayKey) {
    var keys = Object.keys(stats.days).sort();
    if (keys.length <= KEEP_DAYS) return stats;
    var out = { v: 1, days: {} };
    keys.slice(keys.length - KEEP_DAYS).forEach(function (k) { out.days[k] = stats.days[k]; });
    return out;
}
function today(stats, key) { var d = stats.days[key]; return d ? { sessions: d.sessions, minutes: Math.round(d.focus_seconds / 60), seconds: d.focus_seconds } : { sessions: 0, minutes: 0, seconds: 0 }; }

// ---- text: "24:59", "1:05:00"
function clock(ms) {
    var s = Math.ceil(Math.max(0, ms) / 1000), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
    return (h > 0 ? h + ":" + ("0" + m).slice(-2) : ("0" + m).slice(-2)) + ":" + ("0" + r).slice(-2);
}
function fraction(st, settings, now) {          // 1 = full, 0 = done (the ring shows what is LEFT)
    var full = durationMs(settings, st.phase);
    return full > 0 ? Math.max(0, Math.min(1, remaining(st, now) / full)) : 0;
}
function describe(st, settings, now) {
    return { phase: st.phase, cycle: st.cycle, cycles: cleanSettings(settings).cycles, running: st.running, remaining_ms: remaining(st, now), remaining: clock(remaining(st, now)), state: st.running ? "running" : "paused" };
}
