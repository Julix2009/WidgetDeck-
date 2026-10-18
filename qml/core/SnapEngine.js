.pragma library
// Snap grid + smart guides for desktop-widget placement. Pure functions: no QML, no state - the builder (StageCanvas), the
// store (clamping, migration) and the IPC test hooks all use THIS file, so there is exactly one snapping logic.
//
// Coordinates: logical px of ONE monitor, absolute from its top-left corner (the same numbers as widgets.json / the layer-shell
// margins). `area` = the usable area of that monitor {x, y, w, h}: the monitor minus reserved zones (top bar ...). The grid starts
// at area.x / area.y. A rect is {x, y, w, h}.
//
// Snapping order (per axis, independent): smart guides win when one is within `threshold`, otherwise the grid. Guides are
// the edges and centres of the other widgets, the area edges (inset by `margin`), the screen centre, and equal gaps.

var DEFAULTS = { cell: 20, grid: true, snap: true, threshold: 9, margin: 24, overlap: false };

function norm(g) {
    var o = {}, k;
    for (k in DEFAULTS) o[k] = (g && g[k] !== undefined) ? g[k] : DEFAULTS[k];
    o.cell = Math.max(8, Math.min(64, Math.round(Number(o.cell)) || 20));
    o.threshold = Math.max(2, Math.min(24, Number(o.threshold) || 9));
    o.margin = Math.max(0, Math.min(200, Number(o.margin)));
    if (!isFinite(o.margin)) o.margin = 24;
    o.grid = o.grid !== false; o.snap = o.snap !== false; o.overlap = o.overlap === true;
    return o;
}

function gridPos(v, org, cell) { return org + Math.round((v - org) / cell) * cell; }
function gridCeil(v, cell) { return Math.max(cell, Math.ceil(v / cell - 1e-9) * cell); }
function overlaps(a, b) { return a.x < b.x + b.w - 0.01 && a.x + a.w > b.x + 0.01 && a.y < b.y + b.h - 0.01 && a.y + a.h > b.y + 0.01; }
function bbox(rs) {
    var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    for (var i = 0; i < rs.length; i++) { x0 = Math.min(x0, rs[i].x); y0 = Math.min(y0, rs[i].y); x1 = Math.max(x1, rs[i].x + rs[i].w); y1 = Math.max(y1, rs[i].y + rs[i].h); }
    return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}
// keep a rect inside the area (and shrink it when it is bigger than the area)
function fit(r, area) {
    var w = Math.min(r.w, area.w), h = Math.min(r.h, area.h);
    return { x: Math.max(area.x, Math.min(area.x + area.w - w, r.x)), y: Math.max(area.y, Math.min(area.y + area.h - h, r.y)), w: w, h: h };
}
// the coordinate pieces of one axis: p = start, s = size, q = cross start, t = cross size
function ax(r, vert) { return vert ? { p: r.y, s: r.h, q: r.x, t: r.w } : { p: r.x, s: r.w, q: r.y, t: r.h }; }

// ─────────────────────────────────────── move ───────────────────────────────────────
// Candidate LINES of one axis: { pos, pair: 's'|'c'|'e'|'*', kind, ref } (ref = the rect that carries the line, or null)
function lines(vert, others, area, g, screenSize) {
    var out = [], i, a, o;
    for (i = 0; i < others.length; i++) {
        o = ax(others[i], vert);
        out.push({ pos: o.p, pair: "*", kind: "edge", ref: others[i] }, { pos: o.p + o.s / 2, pair: "*", kind: "center", ref: others[i] },
                 { pos: o.p + o.s, pair: "*", kind: "edge", ref: others[i] });
    }
    a = ax(area, vert);
    out.push({ pos: a.p + g.margin, pair: "s", kind: "margin", ref: null }, { pos: a.p + a.s - g.margin, pair: "e", kind: "margin", ref: null },
             { pos: a.p + a.s / 2, pair: "c", kind: "screen", ref: null });
    if (screenSize) out.push({ pos: (vert ? screenSize.height : screenSize.width) / 2, pair: "c", kind: "screen", ref: null });
    return out;
}
// equal-gap targets for the START of the moving rect on one axis. `row` = the other widgets that share the cross range.
function gapTargets(vert, r, others) {
    var m = ax(r, vert), row = [], i, out = [];
    for (i = 0; i < others.length; i++) {
        var o = ax(others[i], vert);
        if (o.q < m.q + m.t - 0.01 && o.q + o.t > m.q + 0.01) row.push({ rect: others[i], p: o.p, s: o.s });
    }
    row.sort(function (a, b) { return a.p - b.p; });
    var gaps = [];
    for (i = 0; i + 1 < row.length; i++) {
        var g = row[i + 1].p - (row[i].p + row[i].s);
        if (g > 0.5) gaps.push({ a: row[i], b: row[i + 1], g: g });
    }
    // (a) the moving rect repeats a gap that already exists, on either side of a neighbour
    for (i = 0; i < row.length; i++) for (var k = 0; k < gaps.length; k++) {
        var G = gaps[k];
        out.push({ pos: row[i].p + row[i].s + G.g, kind: "gap", gap: G.g, ref: row[i].rect, side: 1, via: G });
        out.push({ pos: row[i].p - G.g - m.s, kind: "gap", gap: G.g, ref: row[i].rect, side: -1, via: G });
    }
    // (b) the moving rect sits in the middle between two neighbours: both gaps equal
    for (i = 0; i + 1 < row.length; i++) {
        var free = row[i + 1].p - (row[i].p + row[i].s) - m.s;
        if (free >= 0) out.push({ pos: row[i].p + row[i].s + free / 2, kind: "gap", gap: free / 2, ref: row[i].rect, side: 0, a: row[i], b: row[i + 1] });
    }
    return out;
}
function bestLine(vert, r, cand, thr) {          // nearest guide for the rect's start / centre / end
    var m = ax(r, vert), best = null, i, j, own = [{ k: "s", v: m.p }, { k: "c", v: m.p + m.s / 2 }, { k: "e", v: m.p + m.s }];
    for (i = 0; i < cand.length; i++) for (j = 0; j < 3; j++) {
        var c = cand[i]; if (c.pair !== "*" && c.pair !== own[j].k) continue;
        var d = c.pos - own[j].v;
        if (Math.abs(d) <= thr && (best === null || Math.abs(d) < Math.abs(best.d) - 1e-9)) best = { d: d, line: c, own: own[j].k };
    }
    return best;
}
// gap candidates are START targets: compare with the rect's start only
function bestGap(vert, r, cand, thr) {
    var m = ax(r, vert), best = null;
    for (var i = 0; i < cand.length; i++) { var d = cand[i].pos - m.p; if (Math.abs(d) <= thr && (best === null || Math.abs(d) < Math.abs(best.d) - 1e-9)) best = { d: d, gap: cand[i] }; }
    return best;
}

// r = the dragged rect (or the bounding box of a group), others = widgets that do not move.
// noSnap = the modifier key is held (free placement: nothing snaps).
// Returns { x, y, guides:[{vert, pos, from, to}], gaps:[{vert, from, to, at, size}], snapX, snapY: ""|"guide"|"grid" }
function move(r, others, area, g, screenSize, noSnap) {
    var res = { x: r.x, y: r.y, guides: [], gaps: [], snapX: "", snapY: "" };
    if (noSnap) return res;
    var thr = g.threshold, cx = lines(false, others, area, g, screenSize), cy = lines(true, others, area, g, screenSize);
    var bx = bestLine(false, r, cx, thr), by = bestLine(true, r, cy, thr);
    var rr = { x: r.x + (bx ? bx.d : 0), y: r.y + (by ? by.d : 0), w: r.w, h: r.h };
    // equal gaps (use the already snapped cross position)
    var gx = bestGap(false, rr, gapTargets(false, rr, others), thr), gy = bestGap(true, rr, gapTargets(true, rr, others), thr);
    if (gx && (!bx || Math.abs(gx.d) <= Math.abs(bx.d) + 1e-9) && bx === null) bx = { d: gx.d, gap: gx.gap };
    else if (gx && bx && Math.abs(gx.d) < Math.abs(bx.d) - 0.5) bx = { d: gx.d, gap: gx.gap };
    if (gy && by === null) by = { d: gy.d, gap: gy.gap };
    else if (gy && by && Math.abs(gy.d) < Math.abs(by.d) - 0.5) by = { d: gy.d, gap: gy.gap };
    var x = r.x, y = r.y;
    if (bx) { x += bx.d; res.snapX = "guide"; } else if (g.snap) { x = gridPos(r.x, area.x, g.cell); res.snapX = "grid"; }
    if (by) { y += by.d; res.snapY = "guide"; } else if (g.snap) { y = gridPos(r.y, area.y, g.cell); res.snapY = "grid"; }
    res.x = x; res.y = y;
    res.guides = guideLines({ x: x, y: y, w: r.w, h: r.h }, cx, cy, others);
    res.gaps = gapMarks({ x: x, y: y, w: r.w, h: r.h }, bx && bx.gap ? bx.gap : null, by && by.gap ? by.gap : null);
    return res;
}
// every candidate line that now coincides with a line of the rect becomes a drawn guide (spanning the rect and the carriers)
function guideLines(r, cx, cy, others) {
    var out = [], seen = {};
    function scan(vert, cand) {
        var m = ax(r, vert), own = [m.p, m.p + m.s / 2, m.p + m.s];
        for (var i = 0; i < cand.length; i++) {
            var c = cand[i];
            if (c.kind === "margin" || c.kind === "screen") { var okm = (c.pair === "s" && Math.abs(own[0] - c.pos) < 0.5) || (c.pair === "e" && Math.abs(own[2] - c.pos) < 0.5) || (c.pair === "c" && Math.abs(own[1] - c.pos) < 0.5); if (!okm) continue; }
            else if (!(Math.abs(own[0] - c.pos) < 0.5 || Math.abs(own[1] - c.pos) < 0.5 || Math.abs(own[2] - c.pos) < 0.5)) continue;
            var key = (vert ? "y" : "x") + Math.round(c.pos * 2);
            var lo = m.q, hi = m.q + m.t;
            if (c.ref) { var o = ax(c.ref, vert); lo = Math.min(lo, o.q); hi = Math.max(hi, o.q + o.t); }
            if (seen[key]) { seen[key].from = Math.min(seen[key].from, lo); seen[key].to = Math.max(seen[key].to, hi); continue; }
            seen[key] = { vert: vert, pos: c.pos, from: lo, to: hi, kind: c.kind };
            out.push(seen[key]);
        }
    }
    scan(false, cx); scan(true, cy);
    return out;
}
function gapMarks(r, gx, gy) {
    var out = [];
    function mark(vert, G) {
        if (!G) return;
        var m = ax(r, vert), mid = m.q + m.t / 2;
        if (G.side === 0) {
            out.push({ vert: vert, from: G.a.p + G.a.s, to: m.p, at: mid, size: m.p - (G.a.p + G.a.s) }, { vert: vert, from: m.p + m.s, to: G.b.p, at: mid, size: G.b.p - (m.p + m.s) });
        } else if (G.side === 1) {
            out.push({ vert: vert, from: G.ref ? ax(G.ref, vert).p + ax(G.ref, vert).s : m.p - G.gap, to: m.p, at: mid, size: G.gap });
            if (G.via) out.push({ vert: vert, from: G.via.a.p + G.via.a.s, to: G.via.b.p, at: (G.via.a.rect ? ax(G.via.a.rect, vert).q + ax(G.via.a.rect, vert).t / 2 : mid), size: G.via.g });
        } else {
            out.push({ vert: vert, from: m.p + m.s, to: m.p + m.s + G.gap, at: mid, size: G.gap });
            if (G.via) out.push({ vert: vert, from: G.via.a.p + G.via.a.s, to: G.via.b.p, at: (G.via.a.rect ? ax(G.via.a.rect, vert).q + ax(G.via.a.rect, vert).t / 2 : mid), size: G.via.g });
        }
    }
    mark(false, gx); mark(true, gy);
    return out;
}

// ─────────────────────────────────────── resize (bottom-right handle) ───────────────────────────────────────
// Width / height snap to: edges and centres of other widgets (right / bottom edge), the same size as another widget, the area edge
// (inset by margin), else a multiple of the grid cell. Returns { w, h, guides, snapW, snapH, sameW, sameH }
function resize(r, others, area, g, screenSize, noSnap, minW, minH) {
    var res = { w: Math.max(minW, r.w), h: Math.max(minH, r.h), guides: [], snapW: "", snapH: "" };
    if (noSnap) return res;
    var thr = g.threshold;
    function axis(vert) {
        var m = ax(r, vert), end = m.p + Math.max(vert ? minH : minW, m.s), best = null, i, d, c;
        var cand = lines(vert, others, area, g, screenSize);
        for (i = 0; i < cand.length; i++) {
            c = cand[i]; if (c.pair === "s") continue;
            d = c.pos - end;
            if (Math.abs(d) <= thr && (best === null || Math.abs(d) < Math.abs(best.d) - 1e-9)) best = { d: d, kind: c.kind, ref: c.ref, pos: c.pos };
        }
        for (i = 0; i < others.length; i++) {                  // same size as a neighbour
            var o = ax(others[i], vert); d = (m.p + o.s) - end;
            if (Math.abs(d) <= thr && (best === null || Math.abs(d) < Math.abs(best.d) - 1e-9)) best = { d: d, kind: "size", ref: others[i], pos: m.p + o.s };
        }
        var size = Math.max(vert ? minH : minW, m.s), how = "";
        if (best) { size += best.d; how = "guide"; }
        else if (g.snap) { size = Math.max(vert ? minH : minW, Math.round(size / g.cell) * g.cell); how = "grid"; }
        return { size: size, how: how, best: best };
    }
    var aw = axis(false), ah = axis(true);
    res.w = aw.size; res.h = ah.size; res.snapW = aw.how; res.snapH = ah.how;
    res.sameW = aw.best && aw.best.kind === "size" ? aw.best.ref : null; res.sameH = ah.best && ah.best.kind === "size" ? ah.best.ref : null;
    var fin = { x: r.x, y: r.y, w: res.w, h: res.h };
    if (aw.best && aw.best.kind !== "size") res.guides.push({ vert: false, pos: r.x + res.w, from: Math.min(r.y, aw.best.ref ? aw.best.ref.y : r.y), to: Math.max(r.y + res.h, aw.best.ref ? aw.best.ref.y + aw.best.ref.h : r.y + res.h), kind: aw.best.kind });
    if (ah.best && ah.best.kind !== "size") res.guides.push({ vert: true, pos: r.y + res.h, from: Math.min(r.x, ah.best.ref ? ah.best.ref.x : r.x), to: Math.max(r.x + res.w, ah.best.ref ? ah.best.ref.x + ah.best.ref.w : r.x + res.w), kind: ah.best.kind });
    if (res.sameW) res.guides.push({ vert: false, pos: r.x + res.w, from: Math.min(r.y, res.sameW.y), to: Math.max(r.y + res.h, res.sameW.y + res.sameW.h), kind: "size" });
    if (res.sameH) res.guides.push({ vert: true, pos: r.y + res.h, from: Math.min(r.x, res.sameH.x), to: Math.max(r.x + res.w, res.sameH.x + res.sameH.w), kind: "size" });
    return res;
}

// ─────────────────────────────────────── collisions ───────────────────────────────────────
function collides(rects, others) {
    for (var i = 0; i < rects.length; i++) for (var j = 0; j < others.length; j++) if (overlaps(rects[i], others[j])) return true;
    return false;
}
// the nearest grid-aligned shift (dx, dy) for a group of rects that leaves the area valid and overlaps nothing. null = no room.
function nearestFree(rects, others, area, cell) {
    var bb = bbox(rects), best = null, R = Math.ceil(Math.max(area.w, area.h) / cell), r, dx, dy, i;
    function ok(sx, sy) {
        if (bb.x + sx < area.x - 0.01 || bb.y + sy < area.y - 0.01 || bb.x + bb.w + sx > area.x + area.w + 0.01 || bb.y + bb.h + sy > area.y + area.h + 0.01) return false;
        var moved = [];
        for (i = 0; i < rects.length; i++) moved.push({ x: rects[i].x + sx, y: rects[i].y + sy, w: rects[i].w, h: rects[i].h });
        return !collides(moved, others);
    }
    if (ok(0, 0)) return { dx: 0, dy: 0 };
    for (r = 1; r <= R; r++) {
        for (dx = -r; dx <= r; dx++) for (dy = -r; dy <= r; dy++) {
            if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue;
            var d = dx * dx + dy * dy;
            if (best !== null && d >= best.d) continue;
            if (ok(dx * cell, dy * cell)) best = { dx: dx * cell, dy: dy * cell, d: d };
        }
        if (best !== null) return best;
    }
    return null;
}

// ─────────────────────────────────────── align / distribute ───────────────────────────────────────
// rects: [{id, x, y, w, h}] -> [{id, x, y}] new positions. kind: left | hcenter | right | top | vcenter | bottom
function align(rects, kind) {
    var bb = bbox(rects), out = [];
    for (var i = 0; i < rects.length; i++) {
        var r = rects[i], x = r.x, y = r.y;
        if (kind === "left") x = bb.x; else if (kind === "right") x = bb.x + bb.w - r.w; else if (kind === "hcenter") x = Math.round(bb.x + (bb.w - r.w) / 2);
        else if (kind === "top") y = bb.y; else if (kind === "bottom") y = bb.y + bb.h - r.h; else if (kind === "vcenter") y = Math.round(bb.y + (bb.h - r.h) / 2);
        out.push({ id: r.id, x: x, y: y });
    }
    return out;
}
// equal gaps between 3+ widgets along one axis (first and last stay where they are)
function distribute(rects, vert) {
    var rs = rects.slice().sort(function (a, b) { return vert ? a.y - b.y : a.x - b.x; }), n = rs.length, out = [], i;
    if (n < 3) { for (i = 0; i < n; i++) out.push({ id: rs[i].id, x: rs[i].x, y: rs[i].y }); return out; }
    var first = vert ? rs[0].y : rs[0].x, last = vert ? rs[n - 1].y + rs[n - 1].h : rs[n - 1].x + rs[n - 1].w, total = 0;
    for (i = 0; i < n; i++) total += vert ? rs[i].h : rs[i].w;
    // whole-pixel gaps, all exactly equal: the (sub-pixel) remainder moves the last widget by at most (n-1)/2 px
    var gap = Math.round((last - first - total) / (n - 1)), pos = first;
    for (i = 0; i < n; i++) {
        var r = rs[i];
        out.push({ id: r.id, x: vert ? r.x : pos, y: vert ? pos : r.y });
        pos += (vert ? r.h : r.w) + gap;
    }
    return out;
}
