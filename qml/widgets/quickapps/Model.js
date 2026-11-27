.pragma library
// Quick apps logic (no UI), tested by tools/quickapps-test.js. A widget stores the ids of its desktop entries, at most MAX.

var MAX = 6;

function clean(list) {
    var out = [];
    if (!Array.isArray(list)) return out;
    for (var i = 0; i < list.length && out.length < MAX; i++)
        if (typeof list[i] === "string" && list[i] !== "" && out.indexOf(list[i]) < 0) out.push(list[i]);
    return out;
}
function add(list, id) { var l = clean(list); return typeof id === "string" && id !== "" && l.length < MAX && l.indexOf(id) < 0 ? l.concat([id]) : l; }
function remove(list, id) { return clean(list).filter(function (x) { return x !== id; }); }

// the grid for n apps: one row up to three, 2x2 for four, 3x2 for five and six
function columns(n) { return n <= 3 ? Math.max(1, n) : (n === 4 ? 2 : 3); }
function rows(n) { return n <= 3 ? 1 : 2; }
// the size of the widget in logical px; never narrower than two tiles, so the header always fits
function sizeFor(n) { return [Math.max(2, columns(n)) * 100 + 40, rows(n) * 100 + 60]; }

// installed apps that match what was typed: names that start with it first, then names that contain it, then description and keywords
function filter(entries, query) {
    var q = String(query || "").trim().toLowerCase(), ranked = [];
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (!e || e.noDisplay || !e.name) continue;
        var n = e.name.toLowerCase(), rank = 0;
        if (q !== "") {
            var more = [e.genericName || "", e.comment || "", e.id || ""].concat(Array.prototype.slice.call(e.keywords || [])).join(" ").toLowerCase();
            rank = n.indexOf(q) === 0 ? 0 : n.indexOf(q) > 0 ? 1 : more.indexOf(q) >= 0 ? 2 : -1;
        }
        if (rank >= 0) ranked.push({ e: e, rank: rank, n: n });
    }
    ranked.sort(function (a, b) { return a.rank - b.rank || (a.n < b.n ? -1 : a.n > b.n ? 1 : 0); });
    return ranked.map(function (x) { return x.e; });
}
