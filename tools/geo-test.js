// Tests of the coordinate input rules, QML (core/Geo.js) and shell (sysmon/common.sh: coord): node tools/geo-test.js
const fs = require('fs'), path = require('path'), cp = require('child_process');
const root = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(root, 'qml', 'core', 'Geo.js'), 'utf8').split('\n').slice(1).join('\n');
const G = new Function(src + '; return {parseCoord};')();
let fail = 0; const ok = (n, c, v) => { if (!c) { fail++; console.log('FAIL', n, JSON.stringify(v)); } else console.log('ok  ', n); };
const cases = [['50,9375', 90, 50.9375], ['6.9603', 180, 6.9603], [' -33,5 ', 90, -33.5], ['+48.2', 90, 48.2], ['0', 90, 0], ['180', 180, 180],
    ['', 90, null], ['abc', 90, null], ['50.9abc', 90, null], ['1,234.5', 180, null], ['91', 90, null], ['-181', 180, null], ['50 9', 90, null]];
for (const [text, max, want] of cases) {
    const n = G.parseCoord(text, max);
    ok('qml ' + JSON.stringify(text), want === null ? Number.isNaN(n) : n === want, n);
    if (text === '50 9') continue;      // the scripts drop all white space, they only ever get stored values
    const r = cp.spawnSync('bash', ['-c', '. "$1"; coord "$2" "$3"', '_', path.join(root, 'qml', 'widgets', 'sysmon', 'common.sh'), text, String(max)],
        { env: Object.assign({}, process.env, { XDG_CACHE_HOME: fs.mkdtempSync('/tmp/geo-test-') }), encoding: 'utf8' });
    ok('sh  ' + JSON.stringify(text), want === null ? r.status !== 0 : r.status === 0 && Number(r.stdout) === want, [r.status, r.stdout]);
}
console.log(fail ? fail + ' failed' : 'ALL OK');
process.exit(fail ? 1 : 0);
