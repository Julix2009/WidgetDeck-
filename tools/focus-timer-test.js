// Focus timer logic tests (no UI): node tools/focus-timer-test.js   (re-runs itself under several time zones: the "today" of the statistics is the LOCAL date)
const fs = require('fs'), path = require('path'), cp = require('child_process');
const src = fs.readFileSync(path.join(__dirname, '..', 'qml', 'widgets', 'focustimer', 'Model.js'), 'utf8').replace('.pragma library', '');
const M = new Function(src + '; return {durationMs,cleanSettings,fresh,remaining,start,pause,toggle,reset,skip,finish,due,restore,dateKey,cleanStats,addSession,today,clock,fraction,describe,GRACE_MS};')();
const ZONES = ['UTC', 'Europe/Vienna', 'Pacific/Auckland', 'America/Los_Angeles'];
if (!process.env.FT_TEST_CHILD) {
    let bad = 0;
    for (const tz of ZONES) { const r = cp.spawnSync('node', [__filename], { env: Object.assign({}, process.env, { TZ: tz, FT_TEST_CHILD: '1' }), encoding: 'utf8' }); process.stdout.write(r.stdout); if (r.status !== 0) bad++; }
    process.exit(bad ? 1 : 0);
}
const TZ = process.env.TZ;
let fail = 0; const ok = (n, c, v) => { if (!c) { fail++; console.log('FAIL', '[' + TZ + ']', n, JSON.stringify(v)); } else console.log('ok  ', '[' + TZ + ']', n); };
const S = { focus_min: 25, short_min: 5, long_min: 15, cycles: 4, auto_next: false, debug_fast: false };
const T0 = Date.UTC(2026, 9, 22, 10, 0, 0);

// ---- durations and settings
ok('defaults: 25 / 5 / 15 minutes', M.durationMs(S, 'focus') === 1500000 && M.durationMs(S, 'short') === 300000 && M.durationMs(S, 'long') === 900000, 0);
ok('debug switch: phases of seconds', M.durationMs({ debug_fast: true }, 'focus') === 10000 && M.durationMs({ debug_fast: true }, 'short') === 4000, 0);
const bad = M.cleanSettings({ focus_min: -3, short_min: 'x', long_min: 1e9, cycles: 0, auto_next: 'yes' });
ok('broken settings fall back to limits / defaults', bad.focus_min === 1 && bad.short_min === 5 && bad.long_min === 120 && bad.cycles === 1 && bad.auto_next === false, bad);
ok('a fresh timer is a paused focus phase of the full length', (() => { const f = M.fresh(S); return f.phase === 'focus' && !f.running && f.remainingMs === 1500000 && f.cycle === 0; })(), 0);

// ---- start / pause: the remaining time comes from the end time, not from ticks
let st = M.start(M.fresh(S), T0);
ok('start sets an end time', st.running && st.endsAt === T0 + 1500000, st);
ok('remaining time at +10 min', M.remaining(st, T0 + 600000) === 900000, 0);
st = M.pause(st, T0 + 600000);
ok('pause stores the remaining time', !st.running && st.remainingMs === 900000, st);
ok('pausing for an hour does not change it', M.remaining(st, T0 + 4000000) === 900000, 0);
st = M.start(st, T0 + 4000000);
ok('resume ends after the remaining time', st.endsAt === T0 + 4000000 + 900000, st);
ok('toggle = start / pause', M.toggle(M.fresh(S), T0).running === true && M.toggle(M.start(M.fresh(S), T0), T0 + 1000).running === false, 0);
ok('start twice / pause twice change nothing', M.start(M.start(M.fresh(S), T0), T0 + 5000).endsAt === T0 + 1500000 && M.pause(M.fresh(S), T0).remainingMs === 1500000, 0);
ok('not due before the end, due at the end', !M.due(M.start(M.fresh(S), T0), T0 + 1499999) && M.due(M.start(M.fresh(S), T0), T0 + 1500000), 0);

// ---- a whole set: focus, short, focus, short, focus, short, focus, LONG, then focus with cycle 0
let s = M.start(M.fresh(S), T0), now = T0, phases = [], events = [];
for (let i = 0; i < 9; i++) {
    now = s.endsAt; const r = M.finish(s, S, now); events.push(r.event); phases.push(r.state.phase + ':' + r.state.cycle); s = M.start(r.state, now);
}
ok('four focus phases lead to the long break, then a new set', phases.join(' ') === 'short:1 focus:1 short:2 focus:2 short:3 focus:3 long:4 focus:0 short:1', phases);
ok('only focus phases carry seconds (for the statistics)', events.filter(e => e.seconds > 0).length === 5 && events[0].seconds === 1500 && events[1].seconds === 0, events.map(e => e.seconds));
ok('events tell what ended', events[0].phase === 'focus' && events[0].next === 'short' && events[6].next === 'long' && events[7].phase === 'long', events.map(e => e.phase + '>' + e.next));
ok('different cycle count (2): long break after the second focus', (() => { const c = { cycles: 2 }; let a = M.start(M.fresh(c), T0), seq = []; for (let i = 0; i < 3; i++) { const r = M.finish(a, c, a.endsAt); seq.push(r.state.phase); a = M.start(r.state, a.endsAt); } return seq.join() === 'short,focus,long'; })(), 0);

// ---- auto next
let a1 = M.start(M.fresh(S), T0), r1 = M.finish(a1, S, a1.endsAt);
ok('auto off: the next phase waits, paused, with its full time', !r1.state.running && r1.state.remainingMs === 300000, r1.state);
const SA = Object.assign({}, S, { auto_next: true });
let a2 = M.start(M.fresh(SA), T0), r2 = M.finish(a2, SA, a2.endsAt + 500);
ok('auto on: the next phase runs at once', r2.state.running && r2.state.endsAt === a2.endsAt + 500 + 300000 && !r2.event.late, r2.state);
let r3 = M.finish(a2, SA, a2.endsAt + M.GRACE_MS + 1000);
ok('auto on but the end was long ago (asleep): late, next phase paused, silent', r3.event.late && !r3.state.running, r3);
ok('standby of two hours: one completed phase only', (() => { const r = M.finish(M.start(M.fresh(SA), T0), SA, T0 + 7200000); return r.event.completed && r.state.phase === 'short' && r.state.cycle === 1; })(), 0);

// ---- skip and reset
let k1 = M.skip(M.start(M.fresh(S), T0), S, T0 + 1000);
ok('skip a focus phase: no point for the set, no seconds, the break starts running', !k1.event.completed && k1.event.seconds === 0 && k1.state.phase === 'short' && k1.state.cycle === 0 && k1.state.running, k1);
let k2 = M.skip(M.fresh(S), S, T0);
ok('skip while paused stays paused', !k2.state.running && k2.state.phase === 'short', k2.state);
let k3 = M.skip(Object.assign(M.fresh(S), { phase: 'long', cycle: 4 }), S, T0);
ok('skip the long break: a new set', k3.state.phase === 'focus' && k3.state.cycle === 0, k3.state);
ok('reset: paused focus phase, cycle 0', (() => { const r = M.reset(S); return r.phase === 'focus' && !r.running && r.cycle === 0 && r.remainingMs === 1500000; })(), 0);

// ---- restore after a restart of the shell
const saved = JSON.parse(JSON.stringify(M.start(M.fresh(S), T0)));
let rs = M.restore(saved, S, T0 + 60000);
ok('restart in the middle of a phase: it goes on', rs.state.running && rs.state.endsAt === saved.endsAt && !rs.event && M.remaining(rs.state, T0 + 60000) === 1440000, rs);
rs = M.restore(saved, S, T0 + 1500000 + 3600000);
ok('the phase ended while the shell was not running: counted once, silent, next phase paused', rs.event && rs.event.completed && rs.event.late && rs.event.phase === 'focus' && rs.state.phase === 'short' && !rs.state.running && rs.state.cycle === 1, rs);
rs = M.restore(JSON.parse(JSON.stringify(M.start(M.fresh(SA), T0))), SA, T0 + 1500000 + 3000);
ok('same with auto-next on: also paused (nobody was there)', rs.event.late && !rs.state.running && rs.state.remainingMs === 300000, rs.state);
rs = M.restore(JSON.parse(JSON.stringify(M.pause(M.start(M.fresh(S), T0), T0 + 300000))), S, T0 + 99999999);
ok('a paused timer stays as it was (days later)', !rs.state.running && rs.state.remainingMs === 1200000 && !rs.event, rs);
rs = M.restore(saved, S, T0 - 7 * 86400000);
ok('the clock moved back a week: the phase is clamped to its full length', rs.state.running && rs.state.endsAt - (T0 - 7 * 86400000) === 1500000, rs.state);
for (const junk of [null, undefined, 5, 'x', {}, { v: 2 }, { v: 1, phase: 'bogus' }, { v: 1, phase: 'focus', running: true, endsAt: 'NaN', remainingMs: -5, cycle: 'a' }, { v: 1, phase: 'short', running: false, remainingMs: 1e12, cycle: -4 }]) {
    const r = M.restore(junk, S, T0);
    if (!(r.state && ['focus', 'short', 'long'].indexOf(r.state.phase) >= 0 && r.state.remainingMs > 0 && r.state.remainingMs <= 1500000 && r.state.cycle >= 0 && r.state.cycle <= 11)) ok('broken state file -> a sane timer: ' + JSON.stringify(junk), false, r);
}
ok('broken state files (null, wrong version, NaN, negative, huge) all give a sane timer', true, 0);

// ---- statistics
const key = M.dateKey(new Date(2026, 9, 22, 23, 59, 59)), key2 = M.dateKey(new Date(2026, 9, 23, 0, 0, 1));
ok('the day is the LOCAL date, also just before / after midnight', key === '2026-10-22' && key2 === '2026-10-23', [key, key2]);
let stats = { v: 1, days: {} };
stats = M.addSession(stats, key, 1500); stats = M.addSession(stats, key, 1500); stats = M.addSession(stats, key2, 600);
ok('sessions and seconds add up per day', M.today(stats, key).sessions === 2 && M.today(stats, key).minutes === 50 && M.today(stats, key2).minutes === 10 && M.today(stats, '2020-01-01').sessions === 0, stats);
let big = { v: 1, days: {} }; for (let i = 0; i < 400; i++) big.days[M.dateKey(new Date(2025, 0, 1 + i))] = { sessions: 1, focus_seconds: 60 };
big = M.addSession(big, '2026-10-22', 60);
ok('only the last 365 days are kept', Object.keys(big.days).length === 365 && big.days['2026-10-22'] && !big.days['2025-01-01'], Object.keys(big.days).length);
const cs = M.cleanStats({ v: 1, days: { '2026-10-22': { sessions: 2, focus_seconds: 3000 }, 'garbage': { sessions: 1 }, '2026-10-23': { sessions: -1, focus_seconds: 5 }, '2026-10-24': { sessions: 'x', focus_seconds: 1 } } });
ok('damaged entries are dropped, good ones kept', cs && Object.keys(cs.days).join() === '2026-10-22', cs);
ok('a damaged / foreign statistics file -> null (the service backs it up and starts a new one)', M.cleanStats(null) === null && M.cleanStats({ v: 2, days: {} }) === null && M.cleanStats([]) === null && M.cleanStats('x') === null && M.cleanStats({ v: 1 }) === null, 0);
ok('add never mutates the old object', (() => { const o = { v: 1, days: { a: { sessions: 1, focus_seconds: 1 } } }; M.addSession(o, '2026-10-22', 5); return Object.keys(o.days).length === 1 && o.days.a.sessions === 1; })(), 0);

// ---- text and ring
ok('clock text', M.clock(1500000) === '25:00' && M.clock(59001) === '01:00' && M.clock(1) === '00:01' && M.clock(0) === '00:00' && M.clock(3900000) === '1:05:00' && M.clock(-5) === '00:00', 0);
ok('the ring shows what is left', M.fraction(M.fresh(S), S, T0) === 1 && Math.abs(M.fraction(M.start(M.fresh(S), T0), S, T0 + 750000) - 0.5) < 1e-9 && M.fraction(M.start(M.fresh(S), T0), S, T0 + 9e9) === 0, 0);
const d = M.describe(M.start(M.fresh(S), T0), S, T0 + 1000);
ok('status text data', d.phase === 'focus' && d.running && d.state === 'running' && d.remaining === '24:59' && d.cycles === 4, d);
process.exit(fail ? 1 : 0);
