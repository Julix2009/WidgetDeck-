// Holds widgets.json (layout) and builder.json (builder settings), keeps them in sync with the files
// (live reload when you edit them by hand) and offers the editing operations the builder uses.
import QtQuick
import Quickshell
import Quickshell.Io
import "Defaults.js" as D
import "SnapEngine.js" as SE
import "../widgets/Registry.js" as R

Scope {
    id: root
    readonly property string dir: (Quickshell.env("WIDGETDECK_DIR") || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/widgetdeck"))

    property var data: ({ version: 1, monitor: null, engine: "auto", wallpaperPath: "", widgets: [] })
    property var builder: D.BUILDER_DEFAULT
    property var userTypes: ({})          // plugin types discovered in ~/.config/widgetdeck/widgets/
    property int rev: 0                   // bumped on every change: bindings depend on it
    property var widgetIds: []            // ids only: a Variants model that does not churn while values change
    property bool loaded: false
    property int geomRev: 0               // bumped by every change (rev AND geometry): position / size readers depend on this one

    // ───────────── config.json: setup, location, units, language, modules, update ─────────────
    // Shared with the data scripts (sysmon/*.sh read the same file). Edited in the builder (Settings) and by the first-run assistant.
    //   { "setup": {"done": false}, "location": { "auto": true, "lat": null, "lon": null, "name": "" }, "units": "auto|metric|imperial",
    //     "time_format": "auto|24h|12h", "language": "auto|en|de", "modules": { "widgets": true, "builder": true, "bar": false, "notifications": false },
    //     "update": { "check": true, "channel": "main" } }
    readonly property var configDefaults: ({
        setup: { done: false },
        location: { auto: true, lat: null, lon: null, name: "" },
        units: "auto", time_format: "auto", language: "auto",
        modules: { widgets: true, builder: true, bar: false, notifications: false },
        update: { check: true, channel: "main" }
    })
    property var config: JSON.parse(JSON.stringify(configDefaults))
    property int configRev: 0                 // bumped AFTER the file was written / read: widgets that depend on it fetch again
    property bool configLoaded: false
    property string clast: ""
    function mergeDefaults(def, o) {          // deep: the user's values win, missing keys come from the defaults
        var r = Array.isArray(def) ? def.slice() : Object.assign({}, def);
        for (var k in o) {
            if (def[k] !== null && typeof def[k] === "object" && !Array.isArray(def[k]) && o[k] !== null && typeof o[k] === "object") r[k] = mergeDefaults(def[k], o[k]);
            else r[k] = o[k];
        }
        return r;
    }
    function cget(key, fallback) {            // key like "modules.bar"
        var p = key.split("."), o = config;
        for (var i = 0; i < p.length; i++) { if (o === null || typeof o !== "object" || o[p[i]] === undefined) return fallback; o = o[p[i]]; }
        return o === null ? fallback : o;
    }
    function setConfig(key, value) {          // key like "location.lat"
        var c = JSON.parse(JSON.stringify(config)), p = key.split("."), o = c;
        for (var i = 0; i < p.length - 1; i++) { if (typeof o[p[i]] !== "object" || o[p[i]] === null) o[p[i]] = {}; o = o[p[i]]; }
        o[p[p.length - 1]] = value;
        config = c;
        csaveTimer.restart();
    }
    FileView {
        id: cfile
        path: root.dir + "/config.json"
        watchChanges: true
        atomicWrites: true
        onLoaded: {
            var t = text();
            if (t === root.clast) return;                       // our own save echoing back
            try { var o = JSON.parse(t); if (o && typeof o === "object") { root.config = root.mergeDefaults(root.configDefaults, o); root.configRev++; } } catch (e) { }
            root.configLoaded = true;
        }
        onLoadFailed: error => { root.configLoaded = true; }
        onFileChanged: reload()
    }
    Timer {
        id: csaveTimer; interval: 300
        onTriggered: { var t = JSON.stringify(root.config, null, 2) + "\n"; root.clast = t; cfile.setText(t); cbump.restart(); }
    }
    Timer { id: cbump; interval: 400; onTriggered: root.configRev++ }      // the scripts read the file: wait until it is on disk

    // ───────────── snap grid (see SnapEngine.js) ─────────────
    // Positions are plain logical px at runtime (everything else reads them that way); widgets.json stores them in grid cells.
    property rect area: Qt.rect(0, 0, 2560, 1600)       // usable area of the monitor: below the bar, without reserved zones
    property size screen: Qt.size(2560, 1600)
    property bool areaKnown: false
    property bool needsMigration: false
    readonly property var grid: { builder; return SE.norm(builder.grid); }
    function setGrid(key, value) {
        var g = Object.assign({}, builder.grid || {});
        g[key] = value;
        setBuilder("grid", g);
        saveTimer.restart();                // the file carries the cell size: re-express the (unchanged) pixel positions
    }
    function setArea(sw, sh, ax, ay, aw, ah) {
        var changed = screen.width !== sw || screen.height !== sh || area.x !== ax || area.y !== ay || area.width !== aw || area.height !== ah;
        screen = Qt.size(sw, sh);
        area = Qt.rect(ax, ay, aw, ah);
        areaKnown = true;
        if (loaded && (changed || needsMigration)) { clampAll(); maybeMigrate(); }
    }
    function areaRect() { return { x: area.x, y: area.y, w: area.width, h: area.height }; }
    // keep every widget inside the usable area (resolution / scale / bar changes never leave one off screen)
    function clampAll() {
        var a = areaRect(), moved = false, w = data.widgets, i, changed = [];
        for (i = 0; i < w.length; i++) {
            var f = SE.fit({ x: w[i].x, y: w[i].y, w: w[i].w, h: w[i].h }, a);
            if (f.x !== w[i].x || f.y !== w[i].y || f.w !== w[i].w || f.h !== w[i].h) { w[i].x = Math.round(f.x); w[i].y = Math.round(f.y); w[i].w = Math.round(f.w); w[i].h = Math.round(f.h); moved = true; changed.push(i); }
        }
        // pulling widgets in can make them overlap: the moved ones go to the nearest free grid position (unless overlapping is allowed)
        if (moved && !grid.overlap) {
            for (var k = 0; k < changed.length; k++) {
                var m = w[changed[k]], others = [];
                for (i = 0; i < w.length; i++) if (i !== changed[k]) others.push({ x: w[i].x, y: w[i].y, w: w[i].w, h: w[i].h });
                var nf = SE.nearestFree([{ x: m.x, y: m.y, w: m.w, h: m.h }], others, a, grid.cell);
                if (nf) { m.x += nf.dx; m.y += nf.dy; }
            }
        }
        if (moved) touchGeom();
        return moved;
    }
    function rectOf(id) { var c = raw(id); return c ? { id: id, x: c.x, y: c.y, w: c.w, h: c.h } : null; }
    function rects(excludeIds) {
        var out = [], w = data.widgets, ex = excludeIds || [];
        for (var i = 0; i < w.length; i++) if (ex.indexOf(w[i].id) < 0) out.push({ id: w[i].id, x: w[i].x, y: w[i].y, w: w[i].w, h: w[i].h });
        return out;
    }
    // one write for many widgets: { id: {x, y, w, h} }
    // smooth size change (width and height, no scale transform): used by the Small / Large buttons of widgets that declare `sizes`
    // size table lookup: a type may override its sizes per skin (`skinSizes: { <skin>: { small, large } }`, chosen by the widget prop `skin`)
    function sizeFor(id, which) {
        var c = raw(id), t = c ? typeInfo(c.type) : null; if (!t || !t.sizes) return null;
        var sk = c.props ? c.props.skin : undefined, o = (t.skinSizes && sk && t.skinSizes[sk]) ? t.skinSizes[sk] : t.sizes;
        return o[which] || null;
    }
    property var sizeAnim: null
    function animateGeom(id, target, ms) {
        var c = raw(id); if (!c || !target) return;
        sizeAnim = { id: id, w0: c.w, h0: c.h, w1: target[0], h1: target[1], t0: Date.now(), ms: ms || 320 };
        sizeTimer.restart();
    }
    Timer {
        id: sizeTimer; interval: 16; repeat: true
        onTriggered: {
            var a = root.sizeAnim; if (!a) { stop(); return; }
            var t = Math.min(1, (Date.now() - a.t0) / a.ms), e = 1 - Math.pow(1 - t, 3);
            root.setGeom(a.id, { w: a.w0 + (a.w1 - a.w0) * e, h: a.h0 + (a.h1 - a.h0) * e });
            if (t >= 1) { stop(); root.sizeAnim = null; root.clampAll(); }
        }
    }
    function setGeomMany(map) {
        var any = false;
        for (var id in map) { var c = raw(id); if (!c) continue; for (var k in map[id]) { var v = Math.round(map[id][k]); if (c[k] !== v) { c[k] = v; any = true; } } }
        if (any) touchGeom();
    }
    // every widget onto the grid: top-left corner and size to multiples of the cell; overlaps are resolved when they are not allowed
    function snapAll() {
        var g = grid, a = areaRect(), done = [], w = data.widgets, i;
        for (i = 0; i < w.length; i++) {
            var r = { x: SE.gridPos(w[i].x, a.x, g.cell), y: SE.gridPos(w[i].y, a.y, g.cell), w: SE.gridCeil(w[i].w, g.cell), h: SE.gridCeil(w[i].h, g.cell) };
            r = SE.fit(r, a);
            if (!g.overlap) { var nf = SE.nearestFree([r], done, a, g.cell); if (nf) { r.x += nf.dx; r.y += nf.dy; } }
            w[i].x = r.x; w[i].y = r.y; w[i].w = r.w; w[i].h = r.h; done.push(r);
        }
        touchGeom();
    }
    function resetLayout() {
        data = Object.assign({}, data, { widgets: defaultLayout().widgets });
        widgetIds = data.widgets.map(function (w) { return w.id; });
        rev++; geomRev++;
        saveNow();
    }

    // first-run assistant: replaces the layout with the chosen widget types, flowing in columns over the usable area
    function setupLayout(types, scale, mode) {
        var c = grid.cell, a = areaRect(), x = a.x + 4 * c, top = a.y + 3 * c, y = top, colW = 0, list = [];
        for (var i = 0; i < types.length; i++) {
            var ti = allTypes[types[i]]; if (!ti) continue;
            var w = SE.gridCeil(ti.size[0] * scale, c), h = SE.gridCeil(ti.size[1] * scale, c);
            if (colW > 0 && y + h > a.y + a.h - c) { x += colW + 2 * c; y = top; colW = 0; }
            var st = Object.assign({ mode: mode }, D.MODE_PRESETS[mode] || {});
            if (scale !== 1) st.font_size = Math.round(16 * scale);
            list.push({ id: uid(types[i]), type: types[i], x: x, y: y, w: w, h: h, style: st, props: {} });
            y += h + 2 * c; colW = Math.max(colW, w);
        }
        data = Object.assign({}, data, { widgets: list });
        widgetIds = list.map(function (w) { return w.id; });
        rev++; geomRev++;
        clampAll();
        saveNow();
    }

    readonly property var allTypes: {
        var t = {}, k;
        for (k in R.TYPES) t[k] = R.TYPES[k];
        for (k in userTypes) t[k] = userTypes[k];
        return t;
    }

    function uid(type) { return type + "-" + Math.random().toString(16).slice(2, 8); }
    function defaultLayout() {
        // a tidy column on the grid: cell-multiple sizes, two cells apart, starting four cells in from the usable area
        var c = grid.cell, a = areaRect(), y = a.y + 3 * c;
        var mk = function (t) {
            var s = R.TYPES[t].size, w = SE.gridCeil(s[0], c), h = SE.gridCeil(s[1], c);
            var o = { id: uid(t), type: t, x: a.x + 4 * c, y: y, w: w, h: h, style: {}, props: {} };
            y += h + 2 * c;
            return o;
        };
        return { version: 2, monitor: null, engine: "auto", wallpaperPath: "",
                 widgets: [mk("clock"), mk("sysmon"), mk("music"), mk("visualizer")] };
    }

    // ───────────── lookup ─────────────
    // raw = the stored object (mutators edit this one); cfg = a fresh shallow copy for readers, so that bindings that
    // depend on it really see a change (QML does not notify when the very same object is returned again)
    function raw(id) {
        var w = data.widgets;
        for (var i = 0; i < w.length; i++) if (w[i].id === id) return w[i];
        return null;
    }
    function cfg(id) { var c = raw(id); return c ? Object.assign({}, c) : null; }
    function typeInfo(type) { return allTypes[type] || null; }
    function styleOf(id) {
        var c = raw(id);
        if (!c) return D.resolveStyle({});
        var t = typeInfo(c.type);
        return D.resolveStyle(c.style, t ? t.style : null);
    }
    function propsOf(id) {
        var c = raw(id);
        return c ? R.resolveProps(c.type, c.props, userTypes) : ({});
    }
    function peers(id) {
        var out = [], w = data.widgets;
        for (var i = 0; i < w.length; i++) {
            if (w[i].id === id) continue;
            out.push({ x: w[i].x, y: w[i].y, w: w[i].w, h: w[i].h, style: styleOf(w[i].id) });
        }
        return out;
    }

    // ───────────── editing ─────────────
    function touch(rebuildIds) {
        data = Object.assign({}, data);     // new reference so bindings on `data` re-evaluate
        if (rebuildIds) widgetIds = data.widgets.map(function (w) { return w.id; });
        rev++; geomRev++;
        saveTimer.restart();
    }
    // a pure geometry change (drag, nudge, align): only readers of x / y / w / h re-evaluate. Styles, props and the Matugen colours
    // of every widget are NOT recomputed on each pointer move (that made all glass items re-evaluate while one widget moved).
    function touchGeom() { geomRev++; saveTimer.restart(); }
    function setGeom(id, patch) {
        var c = raw(id); if (!c) return;
        for (var k in patch) c[k] = Math.round(patch[k]);
        touchGeom();
    }
    function setStyle(id, key, value) {
        var c = raw(id); if (!c) return;
        c.style = Object.assign({}, c.style || {});
        c.style[key] = value;
        if (key === "mode") Object.assign(c.style, D.MODE_PRESETS[value] || {});
        touch(false);
    }
    function applyStyle(id, obj) {
        var c = raw(id); if (!c) return;
        c.style = Object.assign({}, c.style || {}, obj);
        touch(false);
    }
    function setProp(id, key, value) {
        var c = raw(id); if (!c) return;
        c.props = Object.assign({}, c.props || {});
        c.props[key] = value;
        touch(false);
    }
    function add(type, x, y) {
        var t = typeInfo(type); if (!t) return "";
        var id = uid(type);
        data.widgets.push({ id: id, type: type, x: Math.round(x), y: Math.round(y), w: t.size[0], h: t.size[1], style: {}, props: {} });
        touch(true);
        return id;
    }
    function remove(id) {
        data.widgets = data.widgets.filter(function (w) { return w.id !== id; });
        touch(true);
    }
    function duplicate(id) {
        var c = raw(id); if (!c) return "";
        var n = JSON.parse(JSON.stringify(c));
        n.id = uid(c.type); n.x += 32; n.y += 32;
        data.widgets.push(n);
        touch(true);
        return n.id;
    }
    function raise(id) {        // last in the list = on top
        var c = raw(id); if (!c) return;
        var rest = data.widgets.filter(function (w) { return w.id !== id; });
        rest.push(c);
        data.widgets = rest;
        touch(true);
    }
    function setBuilder(key, value) {
        var b = Object.assign({}, builder);
        b[key] = value;
        builder = b;
        bsaveTimer.restart();
    }

    // ───────────── persistence ─────────────
    property string lastWritten: ""
    function parseLayout(text) {
        try {
            var o = JSON.parse(text);
            if (!o || !Array.isArray(o.widgets)) return false;
            var cells = (o.version || 1) >= 2, u = Number(o.unit) || 20, org = Array.isArray(o.origin) ? o.origin : [0, 0];
            for (var i = 0; i < o.widgets.length; i++) {
                var w = o.widgets[i];
                if (cells) {         // v2: grid cells relative to the usable area -> logical px
                    w.x = Math.round(org[0] + (+w.x || 0) * u); w.y = Math.round(org[1] + (+w.y || 0) * u);
                    w.w = Math.round((+w.w || 15) * u); w.h = Math.round((+w.h || 8) * u);
                } else {
                    w.x = +w.x || 0; w.y = +w.y || 0; w.w = +w.w || 300; w.h = +w.h || 150;
                }
                w.style = w.style || {}; w.props = w.props || {};
            }
            needsMigration = !cells;
            o.version = 2; delete o.unit; delete o.origin;
            data = o;
            widgetIds = o.widgets.map(function (w) { return w.id; });
            rev++; geomRev++;
            return true;
        } catch (e) { return false; }
    }
    FileView {
        id: lfile
        path: root.dir + "/widgets.json"
        watchChanges: true
        atomicWrites: true
        onLoaded: {
            var t = text();
            if (t === root.lastWritten) { root.loaded = true; return; }     // our own save echoing back
            if (!root.parseLayout(t)) console.log("[widgetdeck] widgets.json is not valid JSON, keeping the current layout");
            root.loaded = true;
            if (root.areaKnown) { root.clampAll(); root.maybeMigrate(); }
        }
        onLoadFailed: error => {
            if (!root.loaded) { root.data = root.defaultLayout(); root.widgetIds = root.data.widgets.map(function (w) { return w.id; }); root.rev++; root.geomRev++; root.saveNow(); root.loaded = true; }
        }
        onFileChanged: reload()
    }
    // widgets.json v2: x / y / w / h in grid cells (relative to the usable area), "unit" = cell size in px, "origin" = the usable area's
    // top-left. A layout stays coherent when the cell size changes (it is re-expressed, not moved).
    function toFile() {
        var u = grid.cell, o = Object.assign({}, data, { version: 2, unit: u, origin: [area.x, area.y] });
        var r4 = function (v) { return Math.round(v * 10000) / 10000; };
        o.widgets = data.widgets.map(function (w) {
            var n = Object.assign({}, w);
            n.x = r4((w.x - area.x) / u); n.y = r4((w.y - area.y) / u); n.w = r4(w.w / u); n.h = r4(w.h / u);
            return n;
        });
        return o;
    }
    // first start with an old px file: back it up, then rewrite it in cells (exactly the same positions)
    function maybeMigrate() {
        if (!needsMigration || !loaded || !areaKnown) return;
        needsMigration = false;
        // the backup must be finished BEFORE the new file is written
        bak.command = ["sh", "-c", "f=\"$1/widgets.json\"; [ -f \"$f\" ] && cp -n \"$f\" \"$f.px-backup-$(date +%Y%m%d-%H%M%S)\"; exit 0", "sh", dir];
        bak.running = true;
    }
    Process { id: bak; onExited: root.saveNow() }
    Timer { id: migrateFallback; interval: 3000; running: root.needsMigration; onTriggered: { root.areaKnown = true; root.maybeMigrate(); } }
    function saveNow() {
        var t = JSON.stringify(toFile(), null, 2) + "\n";
        lastWritten = t;
        lfile.setText(t);
    }
    Timer { id: saveTimer; interval: 250; onTriggered: root.saveNow() }

    property string blast: ""
    FileView {
        id: bfile
        path: root.dir + "/builder.json"
        watchChanges: true
        atomicWrites: true
        onLoaded: { var t = text(); if (t === root.blast) return; try { root.builder = Object.assign({}, D.BUILDER_DEFAULT, JSON.parse(t)); } catch (e) { } }
        onFileChanged: reload()
    }
    Timer {
        id: bsaveTimer; interval: 250
        onTriggered: { var t = JSON.stringify(root.builder, null, 2) + "\n"; root.blast = t; bfile.setText(t); }
    }

    // ───────────── user widget types ─────────────
    function scanPlugins() { if (!plugProc.running) plugProc.running = true; }
    Component.onCompleted: scanPlugins()
    Process {
        id: plugProc
        command: ["sh", "-c", "for d in \"$1\"/widgets/*/; do [ -f \"$d/widget.json\" ] && [ -f \"$d/Widget.qml\" ] && { printf '%s\\t' \"${d%/}\"; tr -d '\\n' < \"$d/widget.json\"; printf '\\n'; }; done", "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = {}, lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var k = lines[i].indexOf("\t"); if (k < 0) continue;
                    try {
                        var j = JSON.parse(lines[i].substring(k + 1)), dir = lines[i].substring(0, k);
                        j.url = "file://" + dir + "/Widget.qml";
                        j.size = j.size || [320, 160]; j.props = j.props || []; j.label = j.label || dir.split("/").pop();
                        j.glyph = j.glyph || "◇"; j.desc = j.desc || "";
                        t[j.type || dir.split("/").pop()] = j;
                    } catch (e) { console.log("[widgetdeck] bad widget.json in", lines[i].substring(0, k)); }
                }
                root.userTypes = t;
            }
        }
    }
}
