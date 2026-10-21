// layout.js <small|large> <width> <height>: "type x y w h" per line - every widget type of the registry, packed in rows (24 px gaps).
const fs = require('fs'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', '..', 'qml', 'widgets', 'Registry.js'), 'utf8').replace('.pragma library', '');
const T = new Function(src + ';return TYPES;')();
const size = process.argv[2] || 'small', W = +process.argv[3] || 2560, H = +process.argv[4] || 1600;
const gap = 24, items = [];
for (const k of Object.keys(T)) { const t = T[k], s = t.sizes ? t.sizes[size] : t.size; items.push([k, s[0], s[1]]); }
items.sort((a, b) => b[2] - a[2]);                                   // tall ones first: tidy rows
let x = gap, y = gap, rowH = 0;
for (const [k, w, h] of items) {
  if (x + w > W - gap) { x = gap; y += rowH + gap; rowH = 0; }
  console.log(k, x, y, w, h);
  x += w + gap; rowH = Math.max(rowH, h);
  if (y + rowH > H - gap) { console.error('layout does not fit: ' + k); process.exit(1); }
}
