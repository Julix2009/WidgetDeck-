// Tests of qml/widgets/timetable/Model.js with the invented demo data. node tools/timetable-test.js
const fs = require('fs'), path = require('path'), cp = require('child_process');
const src = fs.readFileSync(path.join(__dirname, '..', 'qml', 'widgets', 'timetable', 'Model.js'), 'utf8').split('\n').slice(1).join('\n');
const M = new Function(src + '; return {trimRows,entries,currentIndex,nextIndex,progress,remaining,summary,nextSchoolDay,gridRows,weekDays,cell,ymd,mins,addDays};')();
let fail = 0; const ok = (n, c, v) => { if (!c) { fail++; console.log('FAIL', n, JSON.stringify(v)); } else console.log('ok  ', n); };
const demo = JSON.parse(cp.execFileSync('python3', ['-I', path.join(__dirname, '..', 'qml', 'widgets', 'timetable', 'untis.py'), 'demo']).toString());
const L = demo.lessons;
const monday = (() => { const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - ((d.getDay() + 6) % 7)); return d; })();
const at = (dayOffset, hh, mm) => { const d = M.addDays(monday, dayOffset); d.setHours(hh, mm, 0, 0); return d; };

// Monday: slot 6 has three parallel groups
let es = M.entries(L, M.ymd(monday), '');
let s6 = es.find(e => e.start === '13:30');
ok('parallel groups are folded: main + 2 others', s6 && s6.parallel === 2, s6 && s6.parallel);
es = M.entries(L, M.ymd(monday), 'G2');
s6 = es.find(e => e.start === '13:30');
ok('own group G2 is the main lesson', s6 && s6.main.group === 'G2' && s6.parallel === 2, s6 && s6.main);
// a cancelled lesson stays visible
es = M.entries(L, M.ymd(monday), '');
ok('cancelled lesson is kept and marked', es.some(e => e.main.state === 'cancelled'), es.map(e => e.main.state));
// current lesson, progress, remaining
let sm = M.summary(L, at(0, 8, 20), '');
ok('08:20 Monday: lesson 1 is running', sm.kind === 'now' && sm.cur.slot === '1', sm.kind);
ok('progress at 08:20 of 08:00-08:50 = 0.4', Math.abs(M.progress(sm.cur, 8 * 60 + 20) - 0.4) < 1e-9, M.progress(sm.cur, 500));
ok('remaining 30 min', M.remaining(sm.cur, 8 * 60 + 20) === 30, 0);
ok('next lesson is lesson 2', sm.next && sm.next.slot === '2', sm.next && sm.next.slot);
// break between 1 and 2
sm = M.summary(L, at(0, 8, 52), '');
ok('08:52: break, next = lesson 2', sm.kind === 'break' && sm.next.slot === '2', sm.kind);
// before school
sm = M.summary(L, at(0, 7, 10), '');
ok('07:10: before school', sm.kind === 'before' && sm.next.slot === '1', sm.kind);
// lunch break Monday 12:40-13:30
sm = M.summary(L, at(0, 13, 0), '');
ok('13:00: break, next at 13:30', sm.kind === 'break' && sm.next.start === '13:30', sm.next && sm.next.start);
// after school -> free, next school day
sm = M.summary(L, at(0, 17, 0), '');
ok('Monday evening: free, next day = Tuesday', sm.kind === 'free' && M.ymd(sm.nextDay) === M.ymd(M.addDays(monday, 1)), sm.nextDay);
// weekend -> Monday of next week
sm = M.summary(L, at(5, 12, 0), '');
ok('Saturday: free, next = Monday', sm.kind === 'free' && sm.nextDay && sm.nextDay.getDay() === 1, sm.nextDay);
// Wednesday has a free period (no entry at 10:55)
es = M.entries(L, M.ymd(M.addDays(monday, 2)), '');
ok('Wednesday: no lesson 4 (free period)', !es.some(e => e.start === '10:55') && es.some(e => e.start === '11:50'), es.map(e => e.start));
// holiday: nothing in the data
sm = M.summary([], at(1, 9, 0), '');
ok('no lessons at all: free, nothing next', sm.kind === 'free' && sm.next === null, sm);
// exam + changed are carried
es = M.entries(L, M.ymd(M.addDays(monday, 1)), '');
ok('exam state present on Tuesday', es.some(e => e.main.state === 'exam'), es.map(e => e.main.state));
es = M.entries(L, M.ymd(M.addDays(monday, 2)), '');
ok('substitution (teacher) on Wednesday', es.some(e => e.main.state === 'changed' && e.main.subst.teacher), 0);
// week grid rows come from the school grid
const rows = M.gridRows(demo.grid, M.weekDays(monday));
ok('grid rows from the school time grid (7 slots)', rows.length === 7 && rows[0].start === '08:00' && rows[6].end === '15:15', rows.length);
ok('empty leading / trailing grid rows are trimmed', M.trimRows(M.gridRows(demo.grid, M.weekDays(monday)), L, M.weekDays(monday)).length === 7, 0);
ok('cell lookup', M.cell(L, monday, '08:00', '').main.subject === 'M', 0);
process.exit(fail ? 1 : 0);
