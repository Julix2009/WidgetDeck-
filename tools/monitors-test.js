// Multi-monitor logic tests (no UI): node tools/monitors-test.js   - invented monitors only, no real serial numbers.
const fs = require('fs'), path = require('path'), cp = require('child_process'), os = require('os');
const src = fs.readFileSync(path.join(__dirname, '..', 'qml', 'core', 'MonitorModel.js'), 'utf8').replace('.pragma library', '');
const M = new Function(src + '; return {slug,baseKey,uniqueKeys,convert,fit,gridPos,cellsToPx,pxToCells};')();
let fail = 0; const ok = (n, c, v) => { if (!c) { fail++; console.log('FAIL', n, JSON.stringify(v)); } else console.log('ok  ', n); };

// ---- stable keys
const a = M.baseKey({ make: 'Examplia', model: 'EX-27Q', serial: 'S12345', description: 'Examplia EX-27Q S12345 (DP-1)' }, 'DP-1');
const a2 = M.baseKey({ make: 'Examplia', model: 'EX-27Q', serial: 'S12345', description: 'Examplia EX-27Q S12345 (DP-3)' }, 'DP-3');
ok('same monitor on another connector keeps its key (serial)', a === a2 && a === 'examplia-ex-27q-s12345', [a, a2]);
const d1 = M.baseKey({ make: 'Examplia', model: 'EX-24', serial: '0', description: 'Examplia EX-24 (HDMI-A-1)' }, 'HDMI-A-1');
const d2 = M.baseKey({ make: 'Examplia', model: 'EX-24', serial: '', description: 'Examplia EX-24 (HDMI-A-2)' }, 'HDMI-A-2');
ok('no serial: the description without the connector', d1 === 'examplia-ex-24' && d2 === d1, [d1, d2]);
const k = M.uniqueKeys([{ base: d1, name: 'HDMI-A-1' }, { base: d2, name: 'HDMI-A-2' }, { base: a, name: 'DP-1' }]);
ok('two identical monitors without serial stay apart (connector suffix), a unique one has no suffix', k[0] === 'examplia-ex-24@hdmi-a-1' && k[1] === 'examplia-ex-24@hdmi-a-2' && k[2] === a, k);
ok('headless / unknown: the connector name', M.baseKey({ description: '', serial: '' }, 'HEAD-2') === 'head-2' && M.baseKey(null, 'WAYLAND-1') === 'wayland-1' && M.baseKey(null, '') === 'monitor', 0);

// ---- cells <-> px (widgets.json v3)
const px = M.cellsToPx({ x: 2, y: 3.5, w: 19, h: 9 }, 20, [0, 36]);
ok('cells to px with the origin of the usable area', px.x === 40 && px.y === 106 && px.w === 380 && px.h === 180, px);
const back = M.pxToCells(px, 20, [0, 36]);
ok('px to cells is the exact inverse', back.x === 2 && back.y === 3.5 && back.w === 19 && back.h === 9, back);
const u24 = M.pxToCells({ x: 240, y: 72, w: 480, h: 240 }, 24, [0, 0]);
ok('another cell size per monitor', u24.x === 10 && u24.y === 3 && u24.w === 20 && u24.h === 10, u24);

// ---- moving between monitors of different size
const A = { x: 0, y: 0, w: 2560, h: 1440 }, B = { x: 0, y: 0, w: 1920, h: 1080 }, C = { x: 0, y: 40, w: 3840, h: 2120 };
const w1 = { x: 1280 - 190, y: 720 - 90, w: 380, h: 180 };                      // centred on A
const m1 = M.convert(w1, A, B, false, 20);
ok('relative place is kept (centre stays centre), size stays', Math.abs(m1.x + m1.w / 2 - 960) <= 10 && Math.abs(m1.y + m1.h / 2 - 540) <= 10 && m1.w === 380 && m1.h === 180, m1);
const m2 = M.convert({ x: 2400, y: 1300, w: 380, h: 180 }, A, B, false, 20);
ok('a widget near the edge lands inside the smaller monitor', m2.x + m2.w <= 1920 && m2.y + m2.h <= 1080 && m2.x >= 0, m2);
const m3 = M.convert({ x: 100, y: 100, w: 380, h: 180 }, A, C, false, 20);
ok('onto a bigger monitor with a reserved top zone: inside the usable area', m3.y >= 40 && m3.x % 20 === 0 && (m3.y - 40) % 20 === 0, m3);
const m4 = M.convert({ x: 100, y: 100, w: 380, h: 180 }, A, C, true, 20);
ok('"all monitors": same offset from the area origin', m4.x === 100 && m4.y === 140, m4);
const big = M.convert({ x: 0, y: 0, w: 5000, h: 3000 }, A, B, false, 20);
ok('a widget bigger than the target is shrunk to the area', big.w === 1920 && big.h === 1080, big);
ok('grid snapping uses the target monitor cell', M.convert({ x: 333, y: 333, w: 200, h: 100 }, A, A, true, 24).x % 24 === 0, 0);

// ---- wallpaper per output (core/wallpaper.sh --all) with invented tool answers
const T = fs.mkdtempSync(path.join(os.tmpdir(), 'wdmon-')), bin = path.join(T, 'bin'); fs.mkdirSync(bin);
const sh = (name, body) => { fs.writeFileSync(path.join(bin, name), '#!/bin/sh\n' + body + '\n'); fs.chmodSync(path.join(bin, name), 0o755); };
const img = n => { const p = path.join(T, n); fs.writeFileSync(p, 'x'); return p; };
const left = img('left.png'), right = img('right.png'), one = img('one.png');
const run = (env) => cp.execFileSync('bash', [path.join(__dirname, '..', 'qml', 'core', 'wallpaper.sh'), '--all'], { env: Object.assign({ PATH: bin + ':/usr/bin:/bin', HOME: T, XDG_CONFIG_HOME: T + '/cfg' }, env || {}) }).toString().trim().split('\n').filter(Boolean).map(l => l.split('\t'));
sh('awww', 'printf ": DP-1: 2560x1440, scale: 1, currently displaying: image: ' + left + '\\n: DP-2: 1920x1080, scale: 1, currently displaying: image: ' + right + '\\n"');
let r = run();
ok('awww: one line per output', r.length === 2 && r[0][0] === 'DP-1' && r[0][2] === left && r[1][0] === 'DP-2' && r[1][2] === right && r[0][1] === 'awww', r);
fs.unlinkSync(path.join(bin, 'awww'));
sh('hyprctl', 'case "$*" in *listactive*) printf "DP-1 = ' + left + '\\nDP-2 = ' + right + '\\n";; esac');
r = run();
ok('hyprpaper listactive: per output', r.length === 2 && r[0][0] === 'DP-1' && r[1][2] === right, r);
fs.unlinkSync(path.join(bin, 'hyprctl'));
fs.mkdirSync(path.join(T, 'cfg', 'hypr'), { recursive: true });
fs.writeFileSync(path.join(T, 'cfg', 'hypr', 'hyprpaper.conf'), 'preload = ' + left + '\nwallpaper = DP-1,' + left + '\nwallpaper = DP-2,' + right + '\n');
r = run();
ok('hyprpaper.conf (old syntax): per monitor', r.length === 2 && r[0][0] === 'DP-1' && r[1][0] === 'DP-2' && r[1][2] === right, r);
fs.writeFileSync(path.join(T, 'cfg', 'hypr', 'hyprpaper.conf'), 'wallpaper {\n    monitor = DP-1\n    path = ' + left + '\n}\nwallpaper {\n    monitor =\n    path = ' + one + '\n}\n');
r = run();
ok('hyprpaper.conf (new syntax): per monitor, empty monitor = everywhere', r.length === 2 && r[0][0] === 'DP-1' && r[1][0] === '*' && r[1][2] === one, r);
fs.unlinkSync(path.join(T, 'cfg', 'hypr', 'hyprpaper.conf'));
fs.mkdirSync(path.join(T, 'cfg', 'wpaperd'), { recursive: true });
fs.writeFileSync(path.join(T, 'cfg', 'wpaperd', 'config.toml'), '[default]\npath = "' + one + '"\n\n[DP-2]\npath = "' + right + '"\n');
r = run();
ok('wpaperd config: [default] = everywhere, a section per output', r.length === 2 && r[0][0] === '*' && r[1][0] === 'DP-2' && r[1][2] === right, r);
fs.rmSync(T, { recursive: true, force: true });
process.exit(fail ? 1 : 0);
