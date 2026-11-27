// Quick apps logic tests (no UI): node tools/quickapps-test.js
const fs = require('fs'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', 'qml', 'widgets', 'quickapps', 'Model.js'), 'utf8').replace('.pragma library', '');
const M = new Function(src + '; return {MAX,clean,add,remove,columns,rows,sizeFor,filter};')();
let fail = 0; const ok = (n, c, v) => { if (!c) { fail++; console.log('FAIL', n, JSON.stringify(v)); } else console.log('ok  ', n); };

ok('broken lists become empty', M.clean(undefined).length === 0 && M.clean('x').length === 0 && M.clean([1, null, '']).length === 0, 0);
ok('no doubles, at most six', M.clean(['a', 'a', 'b', 'c', 'd', 'e', 'f', 'g']).join() === 'a,b,c,d,e,f', 0);
let l = []; for (const id of 'abcdefgh') l = M.add(l, id);
ok('the seventh app is not added', l.length === M.MAX && M.MAX === 6, l);
ok('adding twice changes nothing', M.add(['a'], 'a').length === 1, 0);
ok('remove', M.remove(['a', 'b', 'c'], 'b').join() === 'a,c', 0);
ok('grid: 1, 2, 3 in a row, 4 as 2x2, 5 and 6 as 3x2', [1, 2, 3, 4, 5, 6].map(n => M.columns(n) + 'x' + M.rows(n)).join() === '1x1,2x1,3x1,2x2,3x2,3x2', 0);
ok('every app has a place', [1, 2, 3, 4, 5, 6].every(n => M.columns(n) * M.rows(n) >= n), 0);
ok('sizes grow with the apps', JSON.stringify([0, 1, 2, 3, 4, 5, 6].map(M.sizeFor)) === JSON.stringify([[240, 160], [240, 160], [240, 160], [340, 160], [240, 260], [340, 260], [340, 260]]), [0, 1, 2, 3, 4, 5, 6].map(M.sizeFor));

const apps = [
    { id: 'firefox', name: 'Firefox', genericName: 'Web Browser', keywords: ['internet'] },
    { id: 'zen', name: 'Zen Browser' },
    { id: 'files', name: 'Dolphin', genericName: 'File Manager' },
    { id: 'hidden', name: 'Firewall Helper', noDisplay: true }
];
ok('no query: everything visible, by name', M.filter(apps, '').map(a => a.id).join() === 'files,firefox,zen', M.filter(apps, ''));
ok('name start before name part', M.filter(apps, 'br').map(a => a.id).join() === 'zen,firefox', M.filter(apps, 'br'));
ok('description and keywords are searched, hidden apps never', M.filter(apps, 'internet').map(a => a.id).join() === 'firefox' && M.filter(apps, 'fire').map(a => a.id).join() === 'firefox', 0);
process.exit(fail ? 1 : 0);
