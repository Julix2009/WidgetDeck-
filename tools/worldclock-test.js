// World clock tests (no UI): node tools/worldclock-test.js   (re-runs itself with several local time zones: TZ=...)
// Checks the logic in qml/widgets/clock/WorldClock.js and the tzdata helper qml/widgets/clock/worldclock.sh.
const fs = require('fs'), path = require('path'), cp = require('child_process');
const dir = path.join(__dirname, '..', 'qml', 'widgets', 'clock');
const src = fs.readFileSync(path.join(dir, 'WorldClock.js'), 'utf8').replace('.pragma library', '');
const W = new Function(src + '; return {parseZones,cityOf,offsetMinutes,parseOffsets,offsetAt,stale,zoned,dayShift,dayMark,line};')();
const ZONES = ['UTC', 'Europe/Vienna', 'Pacific/Auckland', 'America/Los_Angeles'];
if (!process.env.WORLDCLOCK_TEST_CHILD) {
    let bad = 0;
    for (const tz of ZONES) { const r = cp.spawnSync('node', [__filename], { env: Object.assign({}, process.env, { TZ: tz, WORLDCLOCK_TEST_CHILD: '1' }), encoding: 'utf8' }); process.stdout.write(r.stdout + r.stderr); if (r.status) bad++; }
    process.exit(bad ? 1 : 0);
}
const TZ = process.env.TZ;
let fail = 0; const ok = (n, c, v) => { if (!c) { fail++; console.log('FAIL', '[' + TZ + ']', n, JSON.stringify(v)); } else console.log('ok  ', '[' + TZ + ']', n); };
const pad = n => (n < 10 ? '0' : '') + n;
const hm = d => pad(d.getHours()) + ':' + pad(d.getMinutes());

// ---- setting
const z = W.parseZones(' Asia/Tokyo, America/New_York=NYC;America/Argentina/Buenos_Aires\nasia/tokyo, Asia/Tokyo , Europe/Paris=, Pacific/Auckland, UTC, Europe/London ');
ok('parseZones: zones in order, duplicates dropped, at most 6', JSON.stringify(z.map(x => x.zone)) === JSON.stringify(['Asia/Tokyo', 'America/New_York', 'America/Argentina/Buenos_Aires', 'asia/tokyo', 'Europe/Paris', 'Pacific/Auckland']), z);
ok('parseZones: own label, city from the zone name', z[0].label === 'Tokyo' && z[1].label === 'NYC' && z[2].label === 'Buenos Aires' && z[4].label === 'Paris', z);
ok('parseZones: empty setting', W.parseZones('').length === 0 && W.parseZones(undefined).length === 0 && W.parseZones(' , ;').length === 0);
ok('parseZones: spaces inside a name become underscores', W.parseZones('America/Los Angeles')[0].zone === 'America/Los_Angeles');

// ---- offsets
ok('offsetMinutes', W.offsetMinutes('+0930') === 570 && W.offsetMinutes('-0500') === -300 && W.offsetMinutes('+0000') === 0 && isNaN(W.offsetMinutes('x')) && isNaN(W.offsetMinutes('')));
// New York switches to summer time at 07:00 UTC on 8 March 2026 (-0500 -> -0400)
const t0 = Date.UTC(2026, 2, 8, 6, 50) / 1000;
const out = ['America/New_York\t' + t0 + '\t-0500', 'America/New_York\t' + (t0 + 600) + '\t-0400', 'America/New_York\t' + (t0 + 1500) + '\t-0400', 'No/Such\tbad', 'Broken\tline\tx', ''].join('\n');
const o = W.parseOffsets(out);
ok('parseOffsets: samples, unknown zone = null, broken lines skipped', o['America/New_York'].length === 3 && o['No/Such'] === null && o.Broken === undefined, o);
ok('offsetAt: before the change', W.offsetAt(o['America/New_York'], Date.UTC(2026, 2, 8, 6, 59, 59)) === -300);
ok('offsetAt: after the change', W.offsetAt(o['America/New_York'], Date.UTC(2026, 2, 8, 7, 0)) === -240);
ok('offsetAt: before the first sample = the first one', W.offsetAt(o['America/New_York'], 0) === -300);
ok('offsetAt: no samples', isNaN(W.offsetAt(null, 0)) && isNaN(W.offsetAt([], 0)));
ok('stale: samples too old / fresh', W.stale(o['America/New_York'], Date.UTC(2026, 2, 8, 8)) && !W.stale(o['America/New_York'], Date.UTC(2026, 2, 8, 7, 10)) && W.stale(undefined, 0));

// ---- wall time of the zone, independent of the local zone (expected values written out by hand)
const now = new Date(Date.UTC(2026, 10, 27, 23, 30));          // Fri 27 Nov 2026 23:30 UTC
ok('zoned: Tokyo +9 -> Sat 08:30', hm(W.zoned(now.getTime(), 540)) === '08:30' && W.zoned(now.getTime(), 540).getDay() === 6 && W.zoned(now.getTime(), 540).getDate() === 28);
ok('zoned: Kolkata +5:30 -> 05:00', hm(W.zoned(now.getTime(), 330)) === '05:00');
ok('zoned: New York -5 -> Fri 18:30', hm(W.zoned(now.getTime(), -300)) === '18:30' && W.zoned(now.getTime(), -300).getDay() === 5);
// local wall time at that moment: UTC Fri 23:30, Vienna Sat 00:30, Auckland Sat 12:30 (summer time), Los Angeles Fri 15:30
// Tokyo is Sat 08:30, New York Fri 18:30 -> day mark against the local day, written out per zone
const DAYS = { 'UTC': [1, 0], 'Europe/Vienna': [0, -1], 'Pacific/Auckland': [0, -1], 'America/Los_Angeles': [1, 0] };
const [expTokyo, expNY] = DAYS[TZ];
ok('dayShift: against the local calendar day', W.dayShift(now, 540) === expTokyo && W.dayShift(now, -300) === expNY, [W.dayShift(now, 540), W.dayShift(now, -300)]);
// a moment inside a daylight saving gap / overlap of Vienna (29 Mar 2026 01:30 UTC = 03:30 local, 25 Oct 2026 00:30 UTC = 02:30 local, first pass)
ok('zoned: independent of local daylight saving changes', hm(W.zoned(Date.UTC(2026, 2, 29, 1, 30), 540)) === '10:30' && hm(W.zoned(Date.UTC(2026, 9, 25, 0, 30), -240)) === '20:30');
ok('dayMark', W.dayMark(1) === '⁺¹' && W.dayMark(-1) === '⁻¹' && W.dayMark(0) === '');

// ---- the line under the date
const zs = W.parseZones('Asia/Tokyo, America/New_York=NYC, No/Such, Europe/Paris');
const offs = { 'Asia/Tokyo': [[0, 540]], 'America/New_York': [[0, -300]], 'No/Such': null };
const ln = W.line(zs, offs, now, hm);
const parts = ln.split('  ·  ');
ok('line: four entries, no breaking space inside an entry', parts.length === 4 && parts.every(p => p.indexOf(' ') < 0), ln);
ok('line: Tokyo with day mark', parts[0] === 'Tokyo 08:30' + W.dayMark(expTokyo), parts[0]);
ok('line: own label', parts[1] === 'NYC 18:30' + W.dayMark(expNY), parts[1]);
ok('line: unknown zone "?", pending zone "–"', parts[2] === 'Such ?' && parts[3] === 'Paris –', parts);
ok('line: no zones', W.line([], {}, now, hm) === '');
const h12 = d => pad(d.getHours() % 12 === 0 ? 12 : d.getHours() % 12) + ':' + pad(d.getMinutes()) + ' ' + (d.getHours() < 12 ? 'AM' : 'PM');
ok('line: 12 h times keep "AM" / "PM" on the same line', W.line(zs.slice(1, 2), offs, now, h12) === 'NYC\u00a006:30\u00a0PM' + W.dayMark(expNY), W.line(zs.slice(1, 2), offs, now, h12));

// ---- the tzdata helper (needs bash and tzdata, like the widget itself)
const sh = path.join(dir, 'worldclock.sh');
const run = (args, env) => cp.spawnSync('bash', [sh].concat(args), { env: Object.assign({}, process.env, env || {}), encoding: 'utf8' });
const r1 = run(['America/New_York', 'Asia/Tokyo', 'No/Such', '../etc/passwd', 'zone.tab', '-x', 'A B', 'asia/tokyo'], { WORLDCLOCK_NOW: String(t0) });
const h = W.parseOffsets(r1.stdout);
ok('helper: exit 0', r1.status === 0, r1.stderr);
ok('helper: five samples per zone', h['America/New_York'] && h['America/New_York'].length === 5 && h['Asia/Tokyo'].length === 5, r1.stdout);
ok('helper: New York changes at 07:00 UTC', W.offsetAt(h['America/New_York'], Date.UTC(2026, 2, 8, 6, 59)) === -300 && W.offsetAt(h['America/New_York'], Date.UTC(2026, 2, 8, 7, 0)) === -240, r1.stdout);
ok('helper: Tokyo +9', W.offsetAt(h['Asia/Tokyo'], t0 * 1000) === 540);
ok('helper: unknown names, wrong case, paths, non-zone files and options are "bad"', ['No/Such', '../etc/passwd', 'zone.tab', '-x', 'A B', 'asia/tokyo'].every(k => h[k] === null), r1.stdout);
ok('helper: a wrong WORLDCLOCK_NOW prints nothing', run(['UTC'], { WORLDCLOCK_NOW: 'x' }).stdout === '');

process.exit(fail ? 1 : 0);
