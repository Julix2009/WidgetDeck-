// F1 widget logic tests (no UI): node tools/f1-test.js   (re-runs itself with several time zones: TZ=...)
const fs = require('fs'), path = require('path'), cp = require('child_process');
const dir = path.join(__dirname, '..', 'qml', 'widgets', 'f1');
const load = f => fs.readFileSync(path.join(dir, f), 'utf8').replace('.pragma library', '');
const M = new Function(load('Model.js') + '; return {sessionsOf,stateOf,champion,parts,tickMs,timeText,dateText,use12h,flag,iso2,raceName,countryName,fit,remindersDue,shiftPath,raceStart,raceEnd,isSprint,ymdLocal};')();
const C = new Function(load('circuits.js') + '; return CIRCUITS;')();
const ZONES = ['UTC', 'Europe/Vienna', 'Pacific/Auckland', 'America/Los_Angeles'];
if (!process.env.F1_TEST_CHILD) {
    let bad = 0;
    for (const tz of ZONES) { const r = cp.spawnSync('node', [__filename], { env: Object.assign({}, process.env, { TZ: tz, F1_TEST_CHILD: '1' }), encoding: 'utf8' }); process.stdout.write(r.stdout); if (r.status) bad++; }
    process.exit(bad ? 1 : 0);
}
const TZ = process.env.TZ;
let fail = 0; const ok = (n, c, v) => { if (!c) { fail++; console.log('FAIL', '[' + TZ + ']', n, JSON.stringify(v)); } else console.log('ok  ', '[' + TZ + ']', n); };
const DS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], MS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// a weekend taken from the real calendar shape (UTC); it crosses the end of daylight saving time in Europe (25 Oct 2026)
const wk = { round: 18, name: 'United States Grand Prix', circuitId: 'americas', date: '2026-10-25', cancelled: false, sessions: [
    { key: 'FirstPractice', start: '2026-10-23T17:30:00Z', date: '2026-10-23' }, { key: 'SecondPractice', start: '2026-10-23T21:00:00Z', date: '2026-10-23' },
    { key: 'ThirdPractice', start: '2026-10-24T17:30:00Z', date: '2026-10-24' }, { key: 'Qualifying', start: '2026-10-24T23:00:00Z', date: '2026-10-24' },
    { key: 'Race', start: '2026-10-25T20:00:00Z', date: '2026-10-25' }] };
const next = { round: 19, name: 'Mexico City Grand Prix', circuitId: 'rodriguez', date: '2026-11-01', sessions: [{ key: 'Race', start: '2026-11-01T20:00:00Z', date: '2026-11-01' }] };
const prev = { round: 17, name: 'Singapore Grand Prix', circuitId: 'marina_bay', date: '2026-10-11', sessions: [{ key: 'Race', start: '2026-10-11T12:00:00Z', date: '2026-10-11' }] };
const data = { races: [prev, wk, next], standings: [{ pos: 1, name: 'A B' }], standings_round: 19, last: { round: 17 } };

// ---- UTC -> local, per zone (the expected values are written out by hand, not computed with the same code)
const exp = {
    'UTC':                 { fp1: 'Fri Oct 23 17:30', quali: 'Sat Oct 24 23:00', race: 'Sun Oct 25 20:00' },
    'Europe/Vienna':       { fp1: 'Fri Oct 23 19:30', quali: 'Sun Oct 25 01:00', race: 'Sun Oct 25 21:00' },       // +2 (summer time) on Friday / Saturday night, +1 after the change at 01:00 UTC
    'Pacific/Auckland':    { fp1: 'Sat Oct 24 06:30', quali: 'Sun Oct 25 12:00', race: 'Mon Oct 26 09:00' },       // +13: the race is on Monday there
    'America/Los_Angeles': { fp1: 'Fri Oct 23 10:30', quali: 'Sat Oct 24 16:00', race: 'Sun Oct 25 13:00' }        // -7 (summer time until 1 Nov)
}[TZ];
const ss = M.sessionsOf(wk, new Date('2026-10-20T00:00:00Z'));
const loc = s => M.dateText(s.start, DS, MS, 'en') + ' ' + M.timeText(s.start, false);
ok('first practice, local', loc(ss[0]) === exp.fp1, loc(ss[0]));
ok('qualifying near midnight UTC: the LOCAL date is shown', loc(ss[3]) === exp.quali, loc(ss[3]));
ok('race, local (week day and date follow the zone, also over the daylight-saving change)', loc(ss[4]) === exp.race, loc(ss[4]));
ok('German date format', M.dateText(ss[4].start, ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'], MS, 'de').match(/^[A-Z][a-z] \d+\.\d+\.$/) !== null, M.dateText(ss[4].start, ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'], MS, 'de'));
ok('12 h clock', M.timeText(new Date('2026-10-25T20:00:00Z'), true).match(/^\d+:00 (AM|PM)$/) !== null && M.timeText(new Date(2026, 9, 25, 0, 5), true) === '12:05 AM' && M.timeText(new Date(2026, 9, 25, 12, 5), true) === '12:05 PM', 0);
ok('24 h clock', M.timeText(new Date(2026, 9, 25, 7, 5), false) === '07:05', 0);
ok('system format detection', M.use12h('auto', 'h:mm AP') === true && M.use12h('auto', 'HH:mm') === false && M.use12h('12h', 'HH:mm') === true && M.use12h('24h', 'h:mm AP') === false, 0);

// ---- states
const at = s => M.stateOf(data, new Date(s));
ok('before the weekend: the weekend is "upcoming", the first practice is the next session', at('2026-10-20T10:00:00Z').kind === 'upcoming' && at('2026-10-20T10:00:00Z').race.round === 18 && M.sessionsOf(wk, new Date('2026-10-20T10:00:00Z'))[0].state === 'next', at('2026-10-20T10:00:00Z').kind);
ok('a running session wins', (() => { const s = at('2026-10-24T23:20:00Z'); return s.kind === 'running' && s.running.key === 'Qualifying'; })(), 0);
ok('the race is running', (() => { const s = at('2026-10-25T20:30:00Z'); return s.kind === 'running' && s.running.key === 'Race'; })(), 0);
ok('after the race (10 min after the end): "finished", the next race is known', (() => { const s = at('2026-10-25T22:20:00Z'); return s.kind === 'finished' && s.race.round === 18 && s.next.round === 19; })(), at('2026-10-25T22:20:00Z').kind);
ok('6 hours after the end the next race takes over', at('2026-10-26T06:00:00Z').kind === 'upcoming' && at('2026-10-26T06:00:00Z').race.round === 19, at('2026-10-26T06:00:00Z').kind);
ok('season end: no race left', M.stateOf({ races: [prev] }, new Date('2026-12-30T00:00:00Z')).kind === 'seasonend', 0);
ok('no data -> empty', M.stateOf(null, new Date()).kind === 'empty' && M.stateOf({ races: [] }, new Date()).kind === 'empty', 0);
const canc = { races: [prev, Object.assign({}, wk, { cancelled: true }), next] };
ok('a cancelled race is shown as cancelled (no countdown), the next one is named', (() => { const s = M.stateOf(canc, new Date('2026-10-20T00:00:00Z')); return s.kind === 'cancelled' && s.next.round === 19; })(), 0);
const nt = { races: [{ round: 1, name: 'X', circuitId: 'monza', date: '2026-10-25', sessions: [{ key: 'Race', start: null, date: '2026-10-25' }] }] };
ok('race without a time: no countdown target, "open" session, no wrong time', M.raceStart(nt.races[0]) === null && M.sessionsOf(nt.races[0], new Date('2026-10-24T00:00:00Z'))[0].state === 'open' && M.sessionsOf(nt.races[0], new Date('2026-10-24T00:00:00Z'))[0].start === null, 0);
ok('sprint weekend detected', M.isSprint({ sessions: [{ key: 'Sprint' }] }) && !M.isSprint(wk), 0);
ok('champion only when the standings are from the last round', M.champion({ races: [prev, wk, next], standings: [{ name: 'W' }], standings_round: 19 }).name === 'W' && M.champion({ races: [prev, wk, next], standings: [{ name: 'W' }], standings_round: 17 }) === null, 0);

// ---- countdown
const p = M.parts(new Date('2026-10-25T20:00:00Z'), new Date('2026-10-23T14:55:30Z'));
ok('countdown parts', p.d === 2 && p.h === 5 && p.m === 4 && p.s === 30, p);
ok('the clock ticks every second in the last hour, else every minute', M.tickMs(new Date('2026-10-25T20:00:00Z'), new Date('2026-10-25T19:30:00Z')) === 1000 && M.tickMs(new Date('2026-10-25T20:00:00Z'), new Date('2026-10-25T10:00:00Z')) === 60000, 0);
ok('a passed target counts 0, never negative', M.parts(new Date('2026-10-25T20:00:00Z'), new Date('2026-10-26T20:00:00Z')).total === 0, 0);

// ---- names, flags
ok('German race names', M.raceName('United States Grand Prix', 'de') === 'Großer Preis der USA' && M.raceName('Las Vegas Grand Prix', 'de') === 'Großer Preis von Las Vegas' && M.raceName('Las Vegas Grand Prix', 'en') === 'Las Vegas Grand Prix' && M.raceName('Odd Name', 'de') === 'Odd Name', 0);
ok('flag emoji from the country (regional indicators), unknown country = nothing', M.flag('USA').codePointAt(0) === 0x1F1FA && M.flag('Germany').length === 4 && M.flag('Nowhere') === '', 0);
ok('country names in German', M.countryName('Netherlands', 'de') === 'Niederlande' && M.countryName('Netherlands', 'en') === 'Netherlands', 0);

// ---- outlines
const cal = 'albert_park shanghai suzuka miami villeneuve monaco catalunya red_bull_ring silverstone spa hungaroring zandvoort monza madring baku sepang marina_bay americas rodriguez interlagos vegas losail yas_marina'.split(' ');
ok('every circuit of the 2026 calendar has an outline', cal.every(k => C[k]), cal.filter(k => !C[k]));
let bad = [];
for (const [k, c] of Object.entries(C)) {
    const n = c.pts.length / 2; let maxJump = 0, minx = 1e9, maxx = -1e9, miny = 1e9, maxy = -1e9;
    for (let i = 0; i < n; i++) { const x = c.pts[2 * i], y = c.pts[2 * i + 1]; minx = Math.min(minx, x); maxx = Math.max(maxx, x); miny = Math.min(miny, y); maxy = Math.max(maxy, y); const j = (i + 1) % n; maxJump = Math.max(maxJump, Math.hypot(c.pts[2 * j] - x, c.pts[2 * j + 1] - y)); }
    if (!c.closed || n < 40 || maxJump > 800 || maxx > 1001 || maxy > 1001 || minx < -1 || miny < -1 || Math.max(c.w, c.h) !== 1000) bad.push([k, c.closed, n, Math.round(maxJump)]);
}
ok('all outlines are closed loops of sane size (a long straight is one segment, the loop itself has no gap), inside the 0..1000 box', bad.length === 0, bad);
let badFit = [];
for (const [w, h] of [[200, 100], [100, 200], [90, 90], [400, 120], [120, 400]]) for (const [k, c] of Object.entries(C)) {
    const f = M.fit(c, w, h, 6); if (!f) { badFit.push(k); continue; }
    const nums = f.d.match(/-?\d+(\.\d+)?/g).map(Number); let okb = true;
    for (let i = 0; i < nums.length; i += 2) if (nums[i] < 5.9 || nums[i] > w - 5.9 || nums[i + 1] < 5.9 || nums[i + 1] > h - 5.9) okb = false;
    if (!okb || Math.abs(f.w / f.h - c.w / c.h) > 0.02 || !/ Z$/.test(f.d)) badFit.push([k, w, h]);
}
ok('fitting: inside the area with the padding, aspect ratio kept (wide, narrow and square areas)', badFit.length === 0, badFit.slice(0, 4));
ok('missing outline -> null (the widget shows a stand-in)', M.fit(null, 100, 100, 6) === null && M.fit({ pts: [] }, 100, 100, 6) === null, 0);
ok('shadow path = the same path moved', M.shiftPath('M 10.0 20.0 L 30.0 40.0 Z', 1, 2) === 'M 11.0 22.0 L 31.0 42.0 Z', M.shiftPath('M 10.0 20.0 L 30.0 40.0 Z', 1, 2));

// ---- reminders
const due = M.remindersDue(wk, new Date('2026-10-25T19:50:00Z'), 15, ['Race', 'Qualifying'], []);
ok('a reminder is due 15 minutes before the race, once', due.length === 1 && due[0].key === 'Race' && M.remindersDue(wk, new Date('2026-10-25T19:50:00Z'), 15, ['Race'], [due[0].id]).length === 0 && M.remindersDue(wk, new Date('2026-10-25T19:30:00Z'), 15, ['Race'], []).length === 0, due);
process.exit(fail ? 1 : 0);
