// Monitor logic without UI (tested by tools/monitors-test.js): stable keys, cells <-> px, moving a widget between monitors of different size.
.pragma library

function slug(t) { return String(t || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); }

// stable identity of a monitor: make + model + serial when it reports a serial, else its description without the trailing "(DP-1)", else the connector
function baseKey(h, name) {
    if (h) {
        var serial = String(h.serial || "").trim();
        if (h.model && serial !== "" && serial !== "0") return slug((h.make || "") + " " + h.model + " " + serial);
        var d = String(h.description || "").replace(/\s*\([^()]*\)\s*$/, "");
        if (d !== "") return slug(d);
    }
    return slug(name) || "monitor";
}
// several monitors with the same base key (identical models, no serial) get the connector as a suffix, so they stay apart
function uniqueKeys(items) {         // items: [{ base, name }] -> [key]
    var counts = {}, i;
    for (i = 0; i < items.length; i++) counts[items[i].base] = (counts[items[i].base] || 0) + 1;
    return items.map(function (m) { return counts[m.base] > 1 ? m.base + "@" + slug(m.name) : m.base; });
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function fit(r, a) {                 // a rectangle into an area (size first, then position)
    var w = Math.min(r.w, a.w), h = Math.min(r.h, a.h);
    return { x: clamp(r.x, a.x, a.x + a.w - w), y: clamp(r.y, a.y, a.y + a.h - h), w: w, h: h };
}
function gridPos(v, org, cell) { return org + Math.round((v - org) / cell) * cell; }

// a widget rectangle (px of monitor A) -> px of monitor B. keepOffset: same offset from the top-left of the usable area ("all monitors");
// otherwise the centre keeps its RELATIVE place (a stand-in for a missing monitor, copy / move to another resolution). The size stays (clamped).
function convert(c, a, b, keepOffset, cell) {
    var r;
    if (keepOffset) r = { x: c.x - a.x + b.x, y: c.y - a.y + b.y, w: c.w, h: c.h };
    else {
        var cx = (c.x + c.w / 2 - a.x) / Math.max(1, a.w), cy = (c.y + c.h / 2 - a.y) / Math.max(1, a.h);
        r = { x: b.x + cx * b.w - c.w / 2, y: b.y + cy * b.h - c.h / 2, w: c.w, h: c.h };
    }
    r = fit(r, b);
    if (cell > 0) { r.x = gridPos(r.x, b.x, cell); r.y = gridPos(r.y, b.y, cell); r = fit(r, b); }
    return r;
}

// widgets.json stores cells relative to the usable area of the widget's monitor: { unit, origin: [x, y] }
function cellsToPx(w, unit, origin) {
    return { x: Math.round(origin[0] + (+w.x || 0) * unit), y: Math.round(origin[1] + (+w.y || 0) * unit), w: Math.round((+w.w || 15) * unit), h: Math.round((+w.h || 8) * unit) };
}
function pxToCells(w, unit, origin) {
    var r4 = function (v) { return Math.round(v * 10000) / 10000; };
    return { x: r4((w.x - origin[0]) / unit), y: r4((w.y - origin[1]) / unit), w: r4(w.w / unit), h: r4(w.h / unit) };
}
