.pragma library
// To-do list logic (no UI, no files), tested by tools/todo-test.js. An item is { id, text, done }. Every function returns a NEW array.

var MAX_ITEMS = 200, MAX_TEXT = 300;

function cleanText(t) { return String(t === undefined || t === null ? "" : t).replace(/\s+/g, " ").trim().slice(0, MAX_TEXT); }

// the saved file: { v: 1, items: [...] }. An empty file is an empty list; anything else that cannot be read gives null (the file is then left alone).
function parse(text) {
    if (!text || String(text).trim() === "") return [];
    var o;
    try { o = JSON.parse(text); } catch (e) { return null; }
    if (!o || !Array.isArray(o.items)) return null;
    var out = [], seen = {};
    for (var i = 0; i < o.items.length && out.length < MAX_ITEMS; i++) {
        var it = o.items[i];
        if (!it || typeof it !== "object") continue;
        var t = cleanText(it.text);
        if (t === "") continue;
        var id = typeof it.id === "string" && it.id !== "" ? it.id : "t" + i;
        while (seen[id]) id += "x";
        seen[id] = true;
        out.push({ id: id, text: t, done: it.done === true });
    }
    return out;
}
function serialize(items) { return JSON.stringify({ v: 1, items: items }, null, 2) + "\n"; }

function add(items, text, id) {
    var t = cleanText(text);
    if (t === "" || items.length >= MAX_ITEMS) return items;
    return items.concat([{ id: id, text: t, done: false }]);
}
function toggle(items, id) { return items.map(function (it) { return it.id === id ? { id: it.id, text: it.text, done: !it.done } : it; }); }
function remove(items, id) { return items.filter(function (it) { return it.id !== id; }); }
function removeDone(items) { return items.filter(function (it) { return !it.done; }); }
function openCount(items) { return items.filter(function (it) { return !it.done; }).length; }
// open tasks first, done ones below; inside each group the order in which they were added
function sorted(items, showDone) {
    var open = items.filter(function (it) { return !it.done; });
    return showDone ? open.concat(items.filter(function (it) { return it.done; })) : open;
}
