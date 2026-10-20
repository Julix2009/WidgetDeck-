// Weather card logic tests (no UI): node tools/weathercard-test.js
const fs = require('fs'), path = require('path'), cp = require('child_process');
const src = fs.readFileSync(path.join(__dirname, '..', 'qml', 'widgets', 'weathercard', 'Model.js'), 'utf8').split('\n').slice(1).join('\n');
const M = new Function(src + '; return {KINDS,VARIANTS,variantKey,kindOf,isKind,layersFor,skyColors,use12h,hourLabel,weekday,model,dayRange};')();
let fail = 0; const ok = (n, c, v) => { if (!c) { fail++; console.log('FAIL', n, JSON.stringify(v)); } else console.log('ok  ', n); };
// every WMO code Open-Meteo can send maps to a known kind; unknown input falls back, never empty
const WMO = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99];
ok('all WMO codes map to a known kind', WMO.every(c => M.isKind(M.kindOf(c))), WMO.filter(c => !M.isKind(M.kindOf(c))));
ok('unknown codes -> unknown (neutral icon)', [undefined, null, '', 'x', 4, 100, -1].every(c => M.kindOf(c) === 'unknown'), 0);
ok('code families', M.kindOf(0) === 'clear' && M.kindOf(2) === 'partly' && M.kindOf(63) === 'rain' && M.kindOf(82) === 'heavy_rain' && M.kindOf(95) === 'thunder' && M.kindOf(99) === 'hail' && M.kindOf(66) === 'sleet' && M.kindOf(73) === 'snow' && M.kindOf(53) === 'drizzle' && M.kindOf(45) === 'fog', 0);
// every kind has an icon set for day and night (incl. unknown input) and the Blender scene description makes exactly these layers
let bad = [];
for (const k of M.KINDS.concat(['nonsense'])) for (const d of [true, false]) { const key = M.variantKey(k, d); if (!M.VARIANTS[key] || !M.layersFor(k, d).length) bad.push(k + d); }
ok('every kind (day / night, and unknown input) has an icon set with layers', bad.length === 0, bad);
let scenes = null;
try { scenes = JSON.parse(cp.execFileSync('python3', ['-I', path.join(__dirname, 'blender', 'icon_scenes.py')]).toString()); } catch (e) { scenes = null; }
if (scenes) ok('Blender scenes (tools/blender/icon_scenes.py) match the widget icon sets', JSON.stringify(Object.keys(scenes).sort()) === JSON.stringify(Object.keys(M.VARIANTS).sort()) && Object.keys(scenes).every(k => JSON.stringify(scenes[k]) === JSON.stringify(M.VARIANTS[k])), Object.keys(scenes).filter(k => JSON.stringify(scenes[k]) !== JSON.stringify(M.VARIANTS[k])));
// the rendered sprites: every variant / layer / angle frame exists (when the sprites are present)
const icons = path.join(__dirname, '..', 'qml', 'widgets', 'weathercard', 'icons3d');
if (fs.existsSync(path.join(icons, 'manifest.json'))) {
    const man = JSON.parse(fs.readFileSync(path.join(icons, 'manifest.json'), 'utf8')); let miss = [];
    for (const [k, ids] of Object.entries(M.VARIANTS)) {
        if (!fs.existsSync(path.join(icons, k, 'small.png'))) miss.push(k + '/small');
        for (const l of ids.concat(['shadow'])) for (let y = 0; y < man.yaw.length; y++) for (let p = 0; p < man.pitch.length; p++) if (!fs.existsSync(path.join(icons, k, l, y + '_' + p + '.png'))) miss.push(k + '/' + l + '/' + y + '_' + p);
    }
    ok('all sprite frames exist (' + man.yaw.length + ' x ' + man.pitch.length + ' angles per layer)', miss.length === 0, miss.slice(0, 5));
    ok('widget and renderer agree on the angle grid (5 x 3)', man.yaw.length === 5 && man.pitch.length === 3, [man.yaw.length, man.pitch.length]);
} else console.log('skip  (no rendered sprites present)');
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
