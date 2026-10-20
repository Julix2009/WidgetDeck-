// Weather card logic tests (no UI): node tools/weathercard-test.js
const fs = require('fs'), path = require('path'), cp = require('child_process');
const src = fs.readFileSync(path.join(__dirname, '..', 'qml', 'widgets', 'weathercard', 'Model.js'), 'utf8').split('\n').slice(1).join('\n');
const M = new Function(src + '; return {KINDS,kindOf,isKind,layersFor,skyColors,use12h,hourLabel,weekday,model,dayRange};')();
let fail = 0; const ok = (n, c, v) => { if (!c) { fail++; console.log('FAIL', n, JSON.stringify(v)); } else console.log('ok  ', n); };
// every WMO code Open-Meteo can send maps to a known kind; unknown input falls back, never empty
const WMO = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99];
ok('all WMO codes map to a known kind', WMO.every(c => M.isKind(M.kindOf(c))), WMO.filter(c => !M.isKind(M.kindOf(c))));
ok('unknown codes -> unknown (neutral icon)', [undefined, null, '', 'x', 4, 100, -1].every(c => M.kindOf(c) === 'unknown'), 0);
ok('code families', M.kindOf(0) === 'clear' && M.kindOf(2) === 'partly' && M.kindOf(63) === 'rain' && M.kindOf(82) === 'heavy_rain' && M.kindOf(95) === 'thunder' && M.kindOf(99) === 'hail' && M.kindOf(66) === 'sleet' && M.kindOf(73) === 'snow' && M.kindOf(53) === 'drizzle' && M.kindOf(45) === 'fog', 0);
// every kind has a recipe for day and night, every layer names an existing sprite
const sprites = new Set(fs.readdirSync(path.join(__dirname, '..', 'qml', 'widgets', 'weathercard', 'icons')).map(f => f.replace('.png', '')));
let bad = [];
for (const k of M.KINDS.concat(['nonsense'])) for (const d of [true, false]) { const ls = M.layersFor(k, d); if (!ls.length) bad.push(k + d); for (const l of ls) if (!sprites.has(l.s)) bad.push(k + ':' + l.s); }
ok('every kind (day / night, and unknown input) has layers with existing sprites', bad.length === 0, bad);
ok('night variants use the moon, day variants the sun', M.layersFor('clear', false).some(l => l.s === 'moon') && M.layersFor('clear', true).some(l => l.s === 'sun') && !M.layersFor('clear', true).some(l => l.s === 'moon'), 0);
ok('sky colours exist for all kinds', M.KINDS.every(k => [true, false].every(d => M.skyColors(k, d).length === 2)), 0);
// time formats
ok('24 h labels', M.hourLabel('14:00', false) === '14:00' && M.hourLabel('07:30', false) === '07:00' && M.hourLabel('00:00', false) === '00:00', 0);
ok('12 h labels', M.hourLabel('14:00', true) === '2 PM' && M.hourLabel('00:00', true) === '12 AM' && M.hourLabel('12:00', true) === '12 PM' && M.hourLabel('09:00', true) === '9 AM', 0);
ok('system format detection', M.use12h('auto', 'h:mm AP') === true && M.use12h('auto', 'HH:mm') === false && M.use12h('12h', 'HH:mm') === true && M.use12h('24h', 'h:mm AP') === false, 0);
ok('weekday from a date string', M.weekday('2026-10-20') === 2 && M.weekday('2026-10-25') === 0 && M.weekday('bad') === -1, M.weekday('2026-10-20'));
// model from the real script output (invented place): demo coordinates, isolated cache
const T = fs.mkdtempSync('/tmp/wctest-');
let d = null;
try { d = JSON.parse(cp.execFileSync('bash', [path.join(__dirname, '..', 'qml', 'widgets', 'sysmon', 'weather.sh'), '48.2', '16.37'], { env: Object.assign({}, process.env, { WIDGETDECK_DIR: T + '/cfg', XDG_CACHE_HOME: T + '/cache' }), timeout: 30000 }).toString()); } catch (e) { d = null; }
fs.rmSync(T, { recursive: true, force: true });
if (d && d.current_temp !== undefined) {
    const m = M.model(d, 6, 3);
    ok('model: current values', m.temp !== null && m.hi !== null && m.lo !== null && M.isKind(m.kind), m);
    ok('model: 6 hours from now, 3 days', m.hours.length === 6 && m.days.length === 3 && m.hours.every(h => M.isKind(h.kind) && h.temp !== null), m.hours.length);
    ok('model: existing fields of the script are untouched', d.forecast && d.forecast[0] && d.forecast[0].max !== undefined && d.current_icon !== undefined, 0);
} else console.log('skip  (no network: the script output cannot be fetched)');
// missing parts: the model hides what is not there instead of showing error values
const m2 = M.model({ current_temp: '12.4', forecast: [{ max: '15', min: '8' }] }, 6, 3);
ok('model: missing hourly / daily / rain probability', m2 && m2.hours.length === 0 && m2.days.length === 0 && m2.pop === null && m2.kind === 'unknown', m2);
ok('model: no data -> null', M.model(null, 6, 3) === null && M.model({ error: 'offline' }, 6, 3) === null, 0);
const r = M.dayRange([{ min: 3, max: 9 }, { min: 1, max: 12 }, { min: null, max: null }]);
ok('day range', r.lo === 1 && r.hi === 12, r);
process.exit(fail ? 1 : 0);
