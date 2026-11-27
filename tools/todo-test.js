// To-do list logic tests (no UI): node tools/todo-test.js
const fs = require('fs'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', 'qml', 'widgets', 'todo', 'Model.js'), 'utf8').replace('.pragma library', '');
const M = new Function(src + '; return {parse,serialize,add,toggle,remove,removeDone,openCount,sorted,cleanText,MAX_ITEMS,MAX_TEXT};')();
let fail = 0; const ok = (n, c, v) => { if (!c) { fail++; console.log('FAIL', n, JSON.stringify(v)); } else console.log('ok  ', n); };

ok('an empty file is an empty list', M.parse('').length === 0 && M.parse('  \n').length === 0, 0);
ok('a damaged file gives null, never an empty list', M.parse('{"items":[') === null && M.parse('[]') === null && M.parse('{"v":1}') === null && M.parse('null') === null, 0);
const dirty = M.parse(JSON.stringify({ items: [null, 5, { text: '  ' }, { id: 'a', text: ' two\n lines ' }, { id: 'a', text: 'same id', done: 'yes' }] }));
ok('unusable entries are skipped, text is cleaned, ids stay unique, done is a real boolean',
   dirty.length === 2 && dirty[0].text === 'two lines' && dirty[0].id !== dirty[1].id && dirty[1].done === false, dirty);

let l = M.add(M.add([], 'one', '1'), 'two', '2');
ok('add appends', l.length === 2 && l[1].text === 'two' && !l[1].done, l);
ok('empty text adds nothing', M.add(l, '   ', '3') === l, 0);
ok('long text is cut', M.add([], 'x'.repeat(1000), '1')[0].text.length === M.MAX_TEXT, 0);
let full = []; for (let i = 0; i < M.MAX_ITEMS + 5; i++) full = M.add(full, 't', 'i' + i);
ok('the list has a limit', full.length === M.MAX_ITEMS, full.length);
const t = M.toggle(l, '1');
ok('toggle flips one item and leaves the old array alone', t[0].done && !t[1].done && !l[0].done, t);
ok('open count', M.openCount(t) === 1 && M.openCount(l) === 2, 0);
ok('done tasks go to the bottom, or are hidden', M.sorted(t, true).map(x => x.id).join() === '2,1' && M.sorted(t, false).map(x => x.id).join() === '2', 0);
ok('remove and remove done', M.remove(l, '1').length === 1 && M.removeDone(t).map(x => x.id).join() === '2', 0);
ok('save and load give the same list', JSON.stringify(M.parse(M.serialize(t))) === JSON.stringify(t), 0);
process.exit(fail ? 1 : 0);
