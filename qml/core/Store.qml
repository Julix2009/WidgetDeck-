// Holds widgets.json (layout) and builder.json (builder settings), keeps them in sync with the files
// (live reload when you edit them by hand) and offers the editing operations the builder uses.
import QtQuick
import Quickshell
import Quickshell.Io
import "Defaults.js" as D
import "SnapEngine.js" as SE
import "MonitorModel.js" as MM
import "../widgets/Registry.js" as R

Scope {
    id: root
    readonly property string dir: (Quickshell.env("WIDGETDECK_DIR") || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/widgetdeck"))

    property var data: ({ version: 3, engine: "auto", wallpaperPath: "", wallpapers: {}, widgets: [] })
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
        // several monitors: primary = key of the main monitor (empty = the one at the origin), unplugged = "wait" | "primary" (what the widgets of a
        // missing monitor do), cross_edge = dragging a widget over a monitor edge moves it to the neighbour, notify = "focused" | "primary" | <key>,
        // bar = "all" | [keys] (monitors that get the bar), osd = same values as notify (volume / brightness indicators of other tools use it)
        monitors: { primary: "", unplugged: "wait", cross_edge: false, notify: "focused", bar: "all" },
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

    // ───────────── monitors ─────────────
    // Positions are plain logical px at runtime (everything else reads them that way): px inside the widget's HOME monitor (0,0 = that monitor's
    // top-left corner). widgets.json stores them in grid cells relative to the usable area of that monitor (see toFile / parseLayout).
    //   widget.monitor = "<monitor key>" | "primary" (default) | "all"      "all" = one instance on every monitor, same offset
    property var mons: []                          // connected monitors (core/Monitors.qml records), set by the shell
    property string primaryKey: ""
    property string selMon: ""                     // the monitor the builder edits
    property var monInfo: ({})                     // last known data per monitor key (also of unplugged ones): { name, desc, area: [x, y, w, h], unit, screen: [w, h], scale }
    property bool monsReady: false
    readonly property bool multi: mons.length > 1
    function monRec(key) { for (var i = 0; i < mons.length; i++) if (mons[i].key === key) return mons[i]; return null; }
    function curKey() { return monRec(selMon) ? selMon : primaryKey; }
    function areaOfKey(key) {
        var m = monRec(key);
        if (m) return { x: m.area.x, y: m.area.y, w: m.area.width, h: m.area.height };
        var i = monInfo[key];
        if (i && i.area) return { x: i.area[0], y: i.area[1], w: i.area[2], h: i.area[3] };
        var p = monRec(primaryKey);
        return p ? { x: p.area.x, y: p.area.y, w: p.area.width, h: p.area.height } : { x: 0, y: 0, w: 2560, h: 1600 };
    }
    function screenOfKey(key) {
        var m = monRec(key);
        if (m) return { width: m.w, height: m.h };
        var i = monInfo[key];
        return i && i.screen ? { width: i.screen[0], height: i.screen[1] } : { width: 2560, height: 1600 };
    }
    function homeKey(w) { var m = w ? w.monitor : ""; return (!m || m === "primary" || m === "all") ? primaryKey : m; }
    function monSettings(key) { var b = builder.monitors; return (b && b[key]) ? b[key] : {}; }
    function gridFor(key) { return SE.norm(Object.assign({}, builder.grid || {}, monSettings(key).grid || {})); }
    property bool needsMigration: false
    property int oldVersion: 2
    property bool areaKnown: false
    property rect area: { mons; selMon; primaryKey; monInfo; var a = areaOfKey(curKey()); return Qt.rect(a.x, a.y, a.w, a.h); }       // usable area of the edited monitor
    property size screen: { mons; selMon; primaryKey; monInfo; var s = screenOfKey(curKey()); return Qt.size(s.width, s.height); }
    readonly property var grid: { builder; mons; selMon; primaryKey; return gridFor(curKey()); }
    function setGrid(key, value) {
        var g = Object.assign({}, builder.grid || {});
        g[key] = value;
        setBuilder("grid", g);
        saveTimer.restart();                // the file carries the cell size: re-express the (unchanged) pixel positions
    }
    // per-monitor overrides (builder.json "monitors": { key: { grid: { cell, margin }, size: "small" | "large" } }); null / "" removes one
    function setMonGrid(mkey, key, value) {
        var all = Object.assign({}, builder.monitors || {}), m = Object.assign({}, all[mkey] || {}), g = Object.assign({}, m.grid || {});
        if (value === null || value === "") delete g[key]; else g[key] = value;
        m.grid = g; all[mkey] = m; setBuilder("monitors", all);
        saveTimer.restart();
    }
    function setMonSize(mkey, which) {
        var all = Object.assign({}, builder.monitors || {}), m = Object.assign({}, all[mkey] || {});
        m.size = which; all[mkey] = m; setBuilder("monitors", all);
    }
    // the shell tells the store which monitors exist (and again whenever that changes: plug, unplug, mode, scale)
    function setMonitors(list, primary) {
        mons = list; primaryKey = primary;
        if (!monRec(selMon)) selMon = primary;
        var info = Object.assign({}, monInfo);
        for (var i = 0; i < list.length; i++) {
            var m = list[i];
            info[m.key] = { name: m.name, desc: m.description || "", area: [m.area.x, m.area.y, m.area.width, m.area.height], screen: [m.w, m.h], scale: m.scale,
                            unit: gridFor(m.key).cell };
        }
        monInfo = info;
        var first = !monsReady;
        monsReady = true; areaKnown = true;
        if (first && pendingText !== "") {
            var t = pendingText; pendingText = "";
            if (t === "__default__") { data = defaultLayout(); widgetIds = data.widgets.map(function (w) { return w.id; }); rev++; geomRev++; saveNow(); }
            else applyText(t);
        }
        if (loaded) { var moved = clampAll(); maybeMigrate(); if (!moved && !first) saveTimer.restart(); }     // a changed monitor list is saved with the layout
    }
    function areaRect() { return { x: area.x, y: area.y, w: area.width, h: area.height }; }
    // the monitors a widget is shown on right now ("all" = every connected one; a missing monitor: wait, or use the primary one - config monitors.unplugged)
    function targetsOf(w) {
        if (w.hidden) return [];
        var m = w.monitor, keys = mons.map(function (k) { return k.key; });
        if (m === "all") return keys;
        if (!m || m === "primary") return primaryKey ? [primaryKey] : [];
        if (keys.indexOf(m) >= 0) return [m];
        return cget("monitors.unplugged", "wait") === "primary" && primaryKey ? [primaryKey] : [];
    }
    function instances() {                         // ["<widget id>|<monitor key>", ...]
        var out = [], w = data.widgets;
        for (var i = 0; i < w.length; i++) { var t = targetsOf(w[i]); for (var j = 0; j < t.length; j++) out.push(w[i].id + "|" + t[j]); }
        return out;
    }
    // position of a widget on another monitor than its home one: "all" keeps the offset, a stand-in for a missing monitor keeps the relative place
    function convertPx(c, fromKey, toKey, keepOffset) { return MM.convert(c, areaOfKey(fromKey), areaOfKey(toKey), keepOffset, gridFor(toKey).cell); }
    function cfgFor(id, mkey) {                    // the geometry of an instance on monitor `mkey`
        var c = cfg(id); if (!c) return null;
        var home = homeKey(c);
        if (mkey === home || !mkey) return c;
        var r = convertPx(c, home, mkey, c.monitor === "all");
        c.x = Math.round(r.x); c.y = Math.round(r.y); c.w = Math.round(r.w); c.h = Math.round(r.h);
        return c;
    }
    // widgets that live on the edited monitor (the builder stage shows these; the other monitors show theirs on the real desktop)
    readonly property var stageIds: { rev; geomRev; mons; selMon; primaryKey; var k = curKey(); return data.widgets.filter(function (w) { return homeKey(w) === k; }).map(function (w) { return w.id; }); }
    function monitorLabel(key) {
        var m = monRec(key); if (m) return m.name;
        var i = monInfo[key]; return i && i.name ? i.name + " (" + I18n.tr("not connected") + ")" : key;
    }
    // keep every widget inside the usable area of ITS monitor (resolution / scale / bar changes never leave one off screen); widgets of a monitor that
    // is not connected keep their saved place untouched
    function clampAll() {
        var moved = false, w = data.widgets, i, changed = [];
        for (i = 0; i < w.length; i++) {
            var hk = homeKey(w[i]); if (!monRec(hk)) continue;
            var f = SE.fit({ x: w[i].x, y: w[i].y, w: w[i].w, h: w[i].h }, areaOfKey(hk));
            if (f.x !== w[i].x || f.y !== w[i].y || f.w !== w[i].w || f.h !== w[i].h) { w[i].x = Math.round(f.x); w[i].y = Math.round(f.y); w[i].w = Math.round(f.w); w[i].h = Math.round(f.h); moved = true; changed.push(i); }
        }
        // pulling widgets in can make them overlap: the moved ones go to the nearest free grid position (unless overlapping is allowed)
        for (var k = 0; k < changed.length; k++) {
            var m = w[changed[k]], mk = homeKey(m), g = gridFor(mk);
            if (g.overlap) continue;
            var others = [];
            for (i = 0; i < w.length; i++) if (i !== changed[k] && homeKey(w[i]) === mk) others.push({ x: w[i].x, y: w[i].y, w: w[i].w, h: w[i].h });
            var nf = SE.nearestFree([{ x: m.x, y: m.y, w: m.w, h: m.h }], others, areaOfKey(mk), g.cell);
            if (nf) { m.x += nf.dx; m.y += nf.dy; }
        }
        if (moved) touchGeom();
        return moved;
    }
    function rectOf(id) { var c = raw(id); return c ? { id: id, x: c.x, y: c.y, w: c.w, h: c.h } : null; }
    function rects(excludeIds) {                   // the widgets of the edited monitor (collisions and guides only concern them)
        var out = [], w = data.widgets, ex = excludeIds || [], k = curKey();
        for (var i = 0; i < w.length; i++) if (ex.indexOf(w[i].id) < 0 && homeKey(w[i]) === k) out.push({ id: w[i].id, x: w[i].x, y: w[i].y, w: w[i].w, h: w[i].h });
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
        var g = grid, a = areaRect(), done = [], w = data.widgets, i, ck = curKey();
        for (i = 0; i < w.length; i++) {
            if (homeKey(w[i]) !== ck) continue;
            var r = { x: SE.gridPos(w[i].x, a.x, g.cell), y: SE.gridPos(w[i].y, a.y, g.cell), w: SE.gridCeil(w[i].w, g.cell), h: SE.gridCeil(w[i].h, g.cell) };
            r = SE.fit(r, a);
            if (!g.overlap) { var nf = SE.nearestFree([r], done, a, g.cell); if (nf) { r.x += nf.dx; r.y += nf.dy; } }
            w[i].x = r.x; w[i].y = r.y; w[i].w = r.w; w[i].h = r.h; done.push(r);
        }
        touchGeom();
    }
    function resetLayout() {                       // the edited monitor only when there are several, else everything
        var k = curKey(), keep = multi ? data.widgets.filter(function (w) { return homeKey(w) !== k; }) : [];
        data = Object.assign({}, data, { widgets: keep.concat(defaultLayout(k).widgets) });
        widgetIds = data.widgets.map(function (w) { return w.id; });
        rev++; geomRev++;
        saveNow();
    }
    function resetAllLayouts() {                   // every monitor, also the saved places of unplugged ones
        var pk = primaryKey;
        monInfo = Object.fromEntries(Object.entries(monInfo).filter(function (e) { return !!monRec(e[0]); }));
        data = Object.assign({}, data, { widgets: defaultLayout(pk).widgets });
        widgetIds = data.widgets.map(function (w) { return w.id; });
        rev++; geomRev++;
        saveNow();
    }

    // first-run assistant: replaces the layout with the chosen widget types, flowing in columns over the usable area of each monitor.
    // monMap: { type: "primary" | "all" | <monitor key> } (several monitors only; default everything on the primary one)
    function setupLayout(types, scale, mode, monMap) {
        var list = [], groups = {}, order = [], i;
        for (i = 0; i < types.length; i++) {
            var tg = multi && monMap && monMap[types[i]] && monMap[types[i]] !== "all" ? monMap[types[i]] : primaryKey;
            if (!groups[tg]) { groups[tg] = []; order.push(tg); }
            groups[tg].push(types[i]);
        }
        for (var gi = 0; gi < order.length; gi++) {
            var mk = order[gi], gr = gridFor(mk), c = gr.cell, a = areaOfKey(mk), x = a.x + 4 * c, top = a.y + 3 * c, y = top, colW = 0;
            for (i = 0; i < groups[mk].length; i++) {
                var type = groups[mk][i], ti = allTypes[type]; if (!ti) continue;
                var w = SE.gridCeil(ti.size[0] * scale, c), h = SE.gridCeil(ti.size[1] * scale, c);
                if (colW > 0 && y + h > a.y + a.h - c) { x += colW + 2 * c; y = top; colW = 0; }
                var st = Object.assign({ mode: mode }, D.MODE_PRESETS[mode] || {});
                if (scale !== 1) st.font_size = Math.round(16 * scale);
                var o = { id: uid(type), type: type, x: x, y: y, w: w, h: h, style: st, props: {} };
                if (multi) o.monitor = (monMap && monMap[type] === "all") ? "all" : mk;
                list.push(o);
                y += h + 2 * c; colW = Math.max(colW, w);
            }
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
    function defaultLayout(mkey) {
        // a tidy column on the grid: cell-multiple sizes, two cells apart, starting four cells in from the usable area
        var k = mkey || primaryKey, c = gridFor(k).cell, a = areaOfKey(k), y = a.y + 3 * c;
        var mk = function (t) {
            var s = R.TYPES[t].size, w = SE.gridCeil(s[0], c), h = SE.gridCeil(s[1], c);
            var o = { id: uid(t), type: t, x: a.x + 4 * c, y: y, w: w, h: h, style: {}, props: {} };
            if (multi) o.monitor = k;
            y += h + 2 * c;
            return o;
        };
        return { version: 3, engine: "auto", wallpaperPath: "", wallpapers: {},
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
        var me = raw(id), hk = me ? homeKey(me) : "";
        for (var i = 0; i < w.length; i++) {
            if (w[i].id === id || homeKey(w[i]) !== hk) continue;
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
        var id = uid(type), k = curKey(), sz = t.size, pref = monSettings(k).size;
        if (pref && t.sizes && t.sizes[pref]) sz = t.sizes[pref];                // optional default size per monitor (large for a 4K screen, small for a side screen)
        var o = { id: id, type: type, x: Math.round(x), y: Math.round(y), w: sz[0], h: sz[1], style: {}, props: {} };
        if (multi) o.monitor = k;
        data.widgets.push(o);
        touch(true);
        return id;
    }
    function setHidden(id, hidden) { var c = raw(id); if (!c) return; if (hidden) c.hidden = true; else delete c.hidden; touch(true); }
    // ---- monitor assignment of one widget
    function setMonitor(id, value) {              // value: a monitor key | "primary" | "all"
        var c = raw(id); if (!c) return;
        var old = homeKey(c);
        c.monitor = value;
        var nk = homeKey(c);
        if (nk !== old) { var r = convertPx(c, old, nk, false); c.x = Math.round(r.x); c.y = Math.round(r.y); c.w = Math.round(r.w); c.h = Math.round(r.h); }
        touch(true);
    }
    function copyToMonitor(id, key) {
        var c = raw(id); if (!c) return "";
        var n = JSON.parse(JSON.stringify(c)), old = homeKey(c);
        n.id = uid(c.type); n.monitor = key;
        var r = convertPx(c, old, key, false); n.x = Math.round(r.x); n.y = Math.round(r.y); n.w = Math.round(r.w); n.h = Math.round(r.h);
        data.widgets.push(n);
        touch(true);
        return n.id;
    }
    function monitorAtGlobal(gx, gy) { for (var i = 0; i < mons.length; i++) { var m = mons[i]; if (gx >= m.x && gx < m.x + m.w && gy >= m.y && gy < m.y + m.h) return m; } return null; }
    // a group dragged over a monitor edge: it lands on the neighbour with its centre where the pointer went (cx / cy in that monitor's px)
    function moveIdsToMonitor(ids, starts, bb, key, cx, cy) {
        var a = areaOfKey(key), g = gridFor(key);
        for (var i = 0; i < ids.length; i++) {
            var c = raw(ids[i]), st = starts[ids[i]]; if (!c || !st) continue;
            c.monitor = key;
            var r = SE.fit({ x: cx + (st.x - (bb.x + bb.w / 2)), y: cy + (st.y - (bb.y + bb.h / 2)), w: st.w, h: st.h }, a);
            if (g.snap) { r.x = SE.gridPos(r.x, a.x, g.cell); r.y = SE.gridPos(r.y, a.y, g.cell); r = SE.fit(r, a); }
            c.x = Math.round(r.x); c.y = Math.round(r.y); c.w = Math.round(r.w); c.h = Math.round(r.h);
        }
        selMon = key;
        touch(true);
    }
    // copy the whole layout of one monitor to another (positions are converted to the other resolution; the target's own widgets are replaced)
    function transferLayout(fromKey, toKey) {
        if (fromKey === toKey) return 0;
        var src = data.widgets.filter(function (w) { return homeKey(w) === fromKey && w.monitor !== "all"; });
        var keep = data.widgets.filter(function (w) { return homeKey(w) !== toKey || w.monitor === "all"; });
        for (var i = 0; i < src.length; i++) {
            var n = JSON.parse(JSON.stringify(src[i])), r = convertPx(src[i], fromKey, toKey, false);
            n.id = uid(n.type); n.monitor = toKey; n.x = Math.round(r.x); n.y = Math.round(r.y); n.w = Math.round(r.w); n.h = Math.round(r.h);
            keep.push(n);
        }
        data.widgets = keep;
        touch(true);
        return src.length;
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
    property string pendingText: ""                // a layout file read before the monitors are known: parsed as soon as they are
    function parseLayout(text) {
        if (!monsReady) { pendingText = text; return true; }
        return applyText(text);
    }
    function applyText(text) {
        try {
            var o = JSON.parse(text);
            if (!o || !Array.isArray(o.widgets)) return false;
            var ver = o.version || 1, cells = ver >= 2, fileMons = (ver >= 3 && o.monitors) ? o.monitors : {}, primFile = o.primary || "";
            var legU = Number(o.unit) || 20, legOrg = Array.isArray(o.origin) ? o.origin : [0, 0];
            var info = Object.assign({}, monInfo), k;
            for (k in fileMons) if (!monRec(k)) info[k] = fileMons[k];                // places of monitors that are not connected right now
            monInfo = info;
            for (var i = 0; i < o.widgets.length; i++) {
                var w = o.widgets[i];
                if (cells) {         // v2 / v3: grid cells relative to the usable area of the widget's monitor -> logical px
                    var hk = (w.monitor && w.monitor !== "primary" && w.monitor !== "all") ? w.monitor : (primFile || primaryKey), fm = fileMons[hk], u = legU, org = legOrg;
                    if (ver >= 3) {
                        if (fm) { u = Number(fm.unit) || 20; org = fm.origin || [0, 0]; }
                        else { u = gridFor(hk).cell; var ha = areaOfKey(hk); org = [ha.x, ha.y]; }
                    }
                    w.x = Math.round(org[0] + (+w.x || 0) * u); w.y = Math.round(org[1] + (+w.y || 0) * u);
                    w.w = Math.round((+w.w || 15) * u); w.h = Math.round((+w.h || 8) * u);
                } else {
                    w.x = +w.x || 0; w.y = +w.y || 0; w.w = +w.w || 300; w.h = +w.h || 150;
                }
                w.style = w.style || {}; w.props = w.props || {};
            }
            needsMigration = ver < 3; oldVersion = ver;
            // the old single-monitor choice (a connector name) becomes the preferred primary monitor when there are several
            if (ver < 3 && multi && o.monitor && configLoaded && !cget("monitors.primary", "")) { var lm = null; for (var q = 0; q < mons.length; q++) if (mons[q].name === o.monitor) lm = mons[q]; if (lm) setConfig("monitors.primary", lm.key); }
            o.version = 3; delete o.unit; delete o.origin; delete o.monitor; delete o.monitors; delete o.primary;
            o.wallpapers = o.wallpapers || {};
            data = o;
            widgetIds = o.widgets.map(function (w) { return w.id; });
            rev++; geomRev++;
            return true;
        } catch (e) { console.log("[widgetdeck] layout error:", e); return false; }
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
            if (!root.loaded) {
                if (!root.monsReady) root.pendingText = "__default__";
                else { root.data = root.defaultLayout(); root.widgetIds = root.data.widgets.map(function (w) { return w.id; }); root.rev++; root.geomRev++; root.saveNow(); }
                root.loaded = true;
            }
        }
        onFileChanged: reload()
    }
    // widgets.json v3: x / y / w / h in grid cells relative to the usable area of the widget's own monitor ("monitors": { key: { unit, origin, ... } } holds
    // that area and the cell size, also of monitors that are unplugged right now), "primary" = the main monitor when it was saved. A layout stays coherent
    // when the cell size changes (it is re-expressed, not moved).
    function toFile() {
        var info = Object.assign({}, monInfo), i, k;
        for (i = 0; i < mons.length; i++) {
            k = mons[i].key;
            var a = areaOfKey(k);
            info[k] = Object.assign({}, info[k] || {}, { name: mons[i].name, desc: mons[i].description || "", area: [a.x, a.y, a.w, a.h], origin: [a.x, a.y], unit: gridFor(k).cell, screen: [mons[i].w, mons[i].h], scale: mons[i].scale });
        }
        for (k in info) if (!info[k].origin && info[k].area) info[k] = Object.assign({}, info[k], { origin: [info[k].area[0], info[k].area[1]] });
        var o = Object.assign({}, data, { version: 3, primary: primaryKey, monitors: info });
        delete o.monitor;
        var r4 = function (v) { return Math.round(v * 10000) / 10000; };
        o.widgets = data.widgets.map(function (w) {
            var hk = homeKey(w), fi = info[hk] || { unit: gridFor(hk).cell, origin: [areaOfKey(hk).x, areaOfKey(hk).y] };
            var u = Number(fi.unit) || 20, org = fi.origin || [0, 0];
            var n = Object.assign({}, w);
            n.x = r4((w.x - org[0]) / u); n.y = r4((w.y - org[1]) / u); n.w = r4(w.w / u); n.h = r4(w.h / u);
            return n;
        });
        return o;
    }
    // first start with an older file (px, or cells without monitors): back it up, then rewrite it as v3 (exactly the same positions)
    function maybeMigrate() {
        if (!needsMigration || !loaded || !areaKnown) return;
        needsMigration = false;
        // the backup must be finished BEFORE the new file is written
        bak.command = ["sh", "-c", "f=\"$1/widgets.json\"; [ -f \"$f\" ] && cp -n \"$f\" \"$f.v$2-backup-$(date +%Y%m%d-%H%M%S)\"; exit 0", "sh", dir, String(oldVersion)];
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
