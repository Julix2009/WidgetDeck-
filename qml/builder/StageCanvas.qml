// Center panel: a scaled copy of the desktop. The real widget components are shown (WYSIWYG, same glass
// shader); the stage is simply scaled down, so every pixel value stays in real screen coordinates.
//
// This is the "edit mode": widgets are only movable here (the desktop windows have no drag code at all).
//   * snap grid (cell from the settings, starts at the usable area = below the bar) and smart guides: core/SnapEngine.js
//   * multi-selection (Shift+click, rubber band), group move, align / distribute bar, arrow keys
//   * collisions: red frame while the position would be invalid; on release the widget jumps to the nearest free grid position
//   * Alt held while dragging = free placement (nothing snaps)
// The grid and the guides are drawn here only (a light overlay of the stage); the desktop itself never gets them.
import QtQuick
import "../core"
import "../core/SnapEngine.js" as SE
import "../widgets"

Item {
    id: cv
    required property var store
    required property var theme
    required property var th
    required property var backend
    required property var wall
    property size screenSize: Qt.size(2560, 1600)
    property string sel: ""                  // primary selection (shown in the props panel)
    property var sels: []                    // all selected ids
    signal selectionRequested(var ids, string primary)

    readonly property real barH: 38
    readonly property real zoom: Math.max(0.05, Math.min((width - 8) / screenSize.width, (height - barH - 8) / screenSize.height))
    readonly property var grid: store.grid
    readonly property rect area: store.area
    property var drag: null                  // {mode: move|resize|band, ids, starts, bb, mx, my, primary, lastValid, lx, ly}
    property var guides: []                  // [{vert, pos, from, to, kind}]
    property var gaps: []                    // [{vert, from, to, at, size}]
    property bool invalid: false
    property string hoverId: ""
    readonly property real minW: 80
    readonly property real minH: 50

    function hostFor(id) {
        for (var i = 0; i < rep.count; i++) { var it = rep.itemAt(i); if (it && it.cfg && it.cfg.id === id) return it; }
        return null;
    }
    function idAt(x, y) {
        var ids = store.widgetIds;
        for (var i = ids.length - 1; i >= 0; i--) {
            var c = store.cfg(ids[i]);
            if (c && x >= c.x && x <= c.x + c.w && y >= c.y && y <= c.y + c.h) return ids[i];
        }
        return "";
    }
    function areaR() { return store.areaRect(); }
    function scr() { return { width: screenSize.width, height: screenSize.height }; }
    // gx/gy are root-window coordinates (from the palette drag)
    function stagePoint(gx, gy) { return stage.mapFromItem(null, gx, gy); }
    function containsGlobal(gx, gy) { var p = wrap.mapFromItem(null, gx, gy); return p.x >= 0 && p.y >= 0 && p.x <= wrap.width && p.y <= wrap.height; }
    function dropAt(type, gx, gy) {
        var p = stagePoint(gx, gy), t = store.typeInfo(type);
        if (!t) return;
        var a = areaR(), g = grid, w = Math.min(t.size[0], a.w), h = Math.min(t.size[1], a.h);
        var r = { x: p.x - w / 2, y: p.y - h / 2, w: w, h: h }, oth = store.rects([]);
        var m = SE.move(r, oth, a, g, scr(), false);
        var f = SE.fit({ x: m.x, y: m.y, w: w, h: h }, a);
        if (!g.overlap) { var nf = SE.nearestFree([f], oth, a, g.cell); if (nf) { f.x += nf.dx; f.y += nf.dy; } }
        var id = store.add(type, f.x, f.y);
        var o = {}; o[id] = { w: f.w, h: f.h }; store.setGeomMany(o);
        selectionRequested([id], id);
    }
    // palette click / IPC: a new widget at the first free grid position near the top-left of the usable area
    function addAtFree(type) {
        var t = store.typeInfo(type);
        if (!t) return "";
        var a = areaR(), g = grid, w = Math.min(t.size[0], a.w), h = Math.min(t.size[1], a.h);
        var f = SE.fit({ x: SE.gridPos(a.x + 3 * g.cell, a.x, g.cell), y: SE.gridPos(a.y + 3 * g.cell, a.y, g.cell), w: w, h: h }, a);
        if (!g.overlap) { var nf = SE.nearestFree([f], store.rects([]), a, g.cell); if (nf) { f.x += nf.dx; f.y += nf.dy; } }
        var id = store.add(type, f.x, f.y);
        return id;
    }
    // arrow keys: move the selection by n grid cells (clamped to the usable area)
    function nudge(dxCells, dyCells) {
        if (sels.length === 0) return;
        var a = areaR(), rs = [], i;
        for (i = 0; i < sels.length; i++) { var r = store.rectOf(sels[i]); if (r) rs.push(r); }
        if (rs.length === 0) return;
        var bb = SE.bbox(rs), c = grid.cell;
        var nx = Math.max(a.x, Math.min(a.x + a.w - bb.w, bb.x + dxCells * c)), ny = Math.max(a.y, Math.min(a.y + a.h - bb.h, bb.y + dyCells * c));
        var map = {};
        for (i = 0; i < rs.length; i++) map[rs[i].id] = { x: rs[i].x + (nx - bb.x), y: rs[i].y + (ny - bb.y) };
        store.setGeomMany(map);
    }
    // align / distribute the selection (toolbar and IPC)
    function alignSel(kind) {
        var rs = [], i;
        for (i = 0; i < sels.length; i++) { var r = store.rectOf(sels[i]); if (r) rs.push(r); }
        if (rs.length < 2) return;
        var out = SE.align(rs, kind), map = {};
        for (i = 0; i < out.length; i++) map[out[i].id] = { x: out[i].x, y: out[i].y };
        store.setGeomMany(map);
    }
    function distributeSel(vert) {
        var rs = [], i;
        for (i = 0; i < sels.length; i++) { var r = store.rectOf(sels[i]); if (r) rs.push(r); }
        if (rs.length < 3) return;
        var out = SE.distribute(rs, vert), map = {};
        for (i = 0; i < out.length; i++) map[out[i].id] = { x: out[i].x, y: out[i].y };
        store.setGeomMany(map);
    }

    // ───────────── the interaction (the IPC test hooks call these same functions) ─────────────
    function pressAt(x, y, mods) {
        var id = idAt(x, y), shift = (mods & Qt.ShiftModifier) !== 0;
        if (id === "") {
            var keep = shift ? sels.slice() : [];
            drag = { mode: "band", x0: x, y0: y, keep: keep };
            if (!shift) selectionRequested([], "");
            return;
        }
        if (shift) {
            var s = sels.slice(), k = s.indexOf(id);
            if (k >= 0) s.splice(k, 1); else s.push(id);
            selectionRequested(s, k >= 0 ? (s.length ? s[s.length - 1] : "") : id);
            drag = null; return;
        }
        var c = store.cfg(id), inSel = sels.indexOf(id) >= 0;
        var handle = (id === sel && sels.length <= 1 && x > c.x + c.w - ma.handleZone && y > c.y + c.h - ma.handleZone);
        if (!inSel) selectionRequested([id], id); else if (sel !== id) selectionRequested(sels.slice(), id);
        var ids0 = handle ? [id] : (inSel ? sels.slice() : [id]), ids = [], starts = {}, list = [];
        for (var i = 0; i < ids0.length; i++) { var r = store.rectOf(ids0[i]); if (r) { ids.push(ids0[i]); starts[ids0[i]] = r; list.push(r); } }
        if (list.length === 0) return;
        drag = { mode: handle ? "resize" : "move", ids: ids, starts: starts, bb: SE.bbox(list), mx: x, my: y, primary: id, lastValid: null, lx: 0, ly: 0 };
    }
    function moveTo(x, y, mods) {
        var d = drag; if (!d) return;
        var a = areaR(), g = grid, free = (mods & Qt.AltModifier) !== 0, dx = x - d.mx, dy = y - d.my, i;
        if (d.mode === "band") {
            var bx = Math.min(d.x0, x), by = Math.min(d.y0, y), bw = Math.abs(x - d.x0), bh = Math.abs(y - d.y0);
            band.x = bx; band.y = by; band.width = bw; band.height = bh; band.visible = bw > 3 || bh > 3;
            var ids = d.keep.slice(), all = store.widgetIds;
            for (i = 0; i < all.length; i++) {
                var c = store.cfg(all[i]);
                if (c && c.x < bx + bw && c.x + c.w > bx && c.y < by + bh && c.y + c.h > by && ids.indexOf(all[i]) < 0) ids.push(all[i]);
            }
            selectionRequested(ids, ids.length ? ids[ids.length - 1] : "");
            return;
        }
        var oth = store.rects(d.ids);
        if (d.mode === "move") {
            var raw = { x: d.bb.x + dx, y: d.bb.y + dy, w: d.bb.w, h: d.bb.h };
            var res = SE.move(raw, oth, a, g, scr(), free);
            var nx = Math.max(a.x, Math.min(a.x + a.w - d.bb.w, res.x)), ny = Math.max(a.y, Math.min(a.y + a.h - d.bb.h, res.y));
            var sx = nx - d.bb.x, sy = ny - d.bb.y, map = {}, moved = [];
            for (i = 0; i < d.ids.length; i++) {
                var st = d.starts[d.ids[i]];
                map[d.ids[i]] = { x: st.x + sx, y: st.y + sy };
                moved.push({ x: st.x + sx, y: st.y + sy, w: st.w, h: st.h });
            }
            store.setGeomMany(map);
            var h0 = hostFor(d.primary); if (h0) { h0.stretchX = sx - d.lx; h0.stretchY = sy - d.ly; }
            d.lx = sx; d.ly = sy;
            guides = res.guides; gaps = res.gaps;
            invalid = !g.overlap && SE.collides(moved, oth);
        } else {
            var st0 = d.starts[d.primary];
            var maxW = a.x + a.w - st0.x, maxH = a.y + a.h - st0.y;
            var rr = SE.resize({ x: st0.x, y: st0.y, w: Math.max(minW, st0.w + dx), h: Math.max(minH, st0.h + dy) }, oth, a, g, scr(), free, minW, minH);
            var nw = Math.max(minW, Math.min(maxW, rr.w)), nh = Math.max(minH, Math.min(maxH, rr.h));
            var out = {}; out[d.primary] = { w: nw, h: nh }; store.setGeomMany(out);
            guides = rr.guides; gaps = [];
            invalid = !g.overlap && SE.collides([{ x: st0.x, y: st0.y, w: nw, h: nh }], oth);
            if (!invalid) d.lastValid = { w: nw, h: nh };
        }
    }
    function release() {
        var d = drag;
        drag = null;                          // first: the settle animation of a correction is enabled while no drag is active
        if (d && (d.mode === "move" || d.mode === "resize") && invalid && !grid.overlap) {
            var a = areaR(), oth = store.rects(d.ids);
            if (d.mode === "move") {
                var rs = [], i;
                for (i = 0; i < d.ids.length; i++) rs.push(store.rectOf(d.ids[i]));
                var nf = SE.nearestFree(rs, oth, a, grid.cell), map = {};
                for (i = 0; i < rs.length; i++) map[rs[i].id] = nf ? { x: rs[i].x + nf.dx, y: rs[i].y + nf.dy } : { x: d.starts[rs[i].id].x, y: d.starts[rs[i].id].y };
                store.setGeomMany(map);
            } else {
                var lv = d.lastValid || { w: d.starts[d.primary].w, h: d.starts[d.primary].h };
                var o = {}; o[d.primary] = { w: lv.w, h: lv.h };
                store.setGeomMany(o);
            }
        }
        if (d && d.ids) for (var j = 0; j < d.ids.length; j++) { var h = hostFor(d.ids[j]); if (h) { h.stretchX = 0; h.stretchY = 0; } }
        guides = []; gaps = []; invalid = false; band.visible = false;
    }

    // window coordinates of the stage origin + zoom (test hooks map desktop px to pointer positions with this)
    function stageGeom() { var p = stage.mapToItem(null, 0, 0); return { x: p.x, y: p.y, zoom: zoom }; }

    // ───────────── toolbar: align / distribute + the three placement switches ─────────────
    Item {
        id: bar
        x: 0; y: 0; width: parent.width; height: cv.barH
        readonly property int n: cv.sels.length
        Row {
            anchors.verticalCenter: parent.verticalCenter; spacing: 4
            Repeater {
                model: [["left", "Links"], ["hcenter", "Mitte"], ["right", "Rechts"], ["top", "Oben"], ["vcenter", "Mitte ↕"], ["bottom", "Unten"]]
                delegate: GButton {
                    required property var modelData
                    th: cv.th; label: modelData[1]; pad: 9; implicitHeight: 28
                    opacity: bar.n >= 2 ? 1 : 0.38
                    onClicked: cv.alignSel(modelData[0])
                }
            }
            Item { width: 6; height: 1 }
            GButton { th: cv.th; label: "Verteilen ↔"; pad: 9; implicitHeight: 28; opacity: bar.n >= 3 ? 1 : 0.38; onClicked: cv.distributeSel(false) }
            GButton { th: cv.th; label: "Verteilen ↕"; pad: 9; implicitHeight: 28; opacity: bar.n >= 3 ? 1 : 0.38; onClicked: cv.distributeSel(true) }
        }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 4
            GButton { th: cv.th; label: "Raster"; pad: 9; implicitHeight: 28; checked: cv.grid.grid; onClicked: cv.store.setGrid("grid", !cv.grid.grid) }
            GButton { th: cv.th; label: "Einrasten"; pad: 9; implicitHeight: 28; checked: cv.grid.snap; onClicked: cv.store.setGrid("snap", !cv.grid.snap) }
            GButton { th: cv.th; label: "Überlappen"; pad: 9; implicitHeight: 28; checked: cv.grid.overlap; onClicked: cv.store.setGrid("overlap", !cv.grid.overlap) }
        }
    }

    Item {
        id: wrap
        x: (parent.width - width) / 2; y: cv.barH + (parent.height - cv.barH - height) / 2
        width: screenSize.width * cv.zoom
        height: screenSize.height * cv.zoom
        clip: true

        Item {
            id: stage
            width: screenSize.width; height: screenSize.height
            scale: cv.zoom; transformOrigin: Item.TopLeft

            Rectangle { anchors.fill: parent; color: "#14161c" }
            Image {
                anchors.fill: parent
                source: cv.wall.url
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 1280
            }

            // ── edit-mode overlay, below the widgets: the reserved strip (bar) and the snap grid ──
            Rectangle {                                       // reserved zone (the bar): nothing can be placed there
                visible: cv.grid.grid && cv.area.y > 0
                x: 0; y: 0; width: stage.width; height: cv.area.y; color: Qt.rgba(0, 0, 0, 0.28)
            }
            Rectangle {                                       // usable area, inset by the edge margin
                visible: cv.grid.grid
                x: cv.area.x + cv.grid.margin; y: cv.area.y + cv.grid.margin
                width: cv.area.width - 2 * cv.grid.margin; height: cv.area.height - 2 * cv.grid.margin
                color: "transparent"; border.width: 1 / cv.zoom; border.color: Qt.rgba(1, 1, 1, 0.10)
            }
            Canvas {
                id: dots
                visible: cv.grid.grid
                x: cv.area.x; y: cv.area.y; width: cv.area.width; height: cv.area.height
                opacity: 0.22
                readonly property real cell: cv.grid.cell
                readonly property real zoomK: cv.zoom
                onCellChanged: requestPaint()
                onZoomKChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                onPaint: {
                    var c = getContext("2d");
                    c.reset(); c.fillStyle = "#ffffff";
                    // a dot is ~1.5 physical px whatever the zoom; when the cells get closer than 7 px on screen only every k-th point is drawn
                    var k = Math.max(1, Math.ceil(7 / (cell * zoomK))), r = Math.max(1.4, 1.6 / zoomK), step = cell * k;
                    for (var gx = 0; gx <= width + 0.5; gx += step) for (var gy = 0; gy <= height + 0.5; gy += step) c.fillRect(gx - r / 2, gy - r / 2, r, r);
                }
            }

            Repeater {
                id: rep
                model: cv.store.loaded ? cv.store.widgetIds : []
                delegate: WidgetHost {
                    required property string modelData
                    required property int index
                    store: cv.store; theme: cv.theme; backend: cv.backend; wall: cv.wall
                    cfg: { cv.store.geomRev; return cv.store.cfg(modelData) || ({ id: modelData, type: "clock", x: 0, y: 0, w: 10, h: 10, style: {}, props: {} }); }
                    x: cfg.x; y: cfg.y
                    // the glass samples the wallpaper by the host's own (animated) position: the background never swims against the glass
                    screenX: x; screenY: y
                    // a short settle animation after a correction (collision jump, align, nudge); none while the pointer drags
                    Behavior on x { enabled: cv.drag === null; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: cv.drag === null; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    z: index
                    screenSize: cv.screenSize
                    padPx: 56
                    interactive: false
                    hoverOverride: cv.hoverId === modelData
                    pressOverride: cv.drag !== null && cv.drag.ids !== undefined && cv.drag.ids.indexOf(modelData) >= 0
                    pulseOnResize: cv.drag === null || cv.drag.mode !== "resize"
                }
            }

            // ── above the widgets: smart guides, gap marks ──
            Repeater {
                model: cv.guides
                delegate: Rectangle {
                    required property var modelData
                    x: modelData.vert ? modelData.from : modelData.pos - 0.5 / cv.zoom
                    y: modelData.vert ? modelData.pos - 0.5 / cv.zoom : modelData.from
                    width: modelData.vert ? modelData.to - modelData.from : 1 / cv.zoom
                    height: modelData.vert ? 1 / cv.zoom : modelData.to - modelData.from
                    z: 4500
                    color: Qt.rgba(1, 1, 1, modelData.kind === "margin" || modelData.kind === "screen" ? 0.38 : 0.62)
                }
            }
            Repeater {
                model: cv.gaps
                delegate: Item {
                    required property var modelData
                    z: 4600
                    x: modelData.vert ? modelData.at : Math.min(modelData.from, modelData.to)
                    y: modelData.vert ? Math.min(modelData.from, modelData.to) : modelData.at
                    width: modelData.vert ? 1 / cv.zoom : Math.abs(modelData.to - modelData.from)
                    height: modelData.vert ? Math.abs(modelData.to - modelData.from) : 1 / cv.zoom
                    Rectangle { anchors.fill: parent; color: Qt.rgba(1, 1, 1, 0.8) }
                    Rectangle {
                        anchors.centerIn: parent
                        width: lab.implicitWidth + 10 / cv.zoom; height: lab.implicitHeight + 4 / cv.zoom; radius: height / 2
                        color: Qt.rgba(0.05, 0.06, 0.08, 0.78)
                        Text { id: lab; anchors.centerIn: parent; text: Math.round(modelData.size) + " px"; color: "white"; font.family: cv.th.font; font.pixelSize: 11 / cv.zoom }
                    }
                }
            }

            // ── selection frames (red while the position would be invalid) + the resize handle ──
            Repeater {
                model: cv.sels
                delegate: Rectangle {
                    required property string modelData
                    readonly property var c: { cv.store.geomRev; return cv.store.cfg(modelData); }
                    visible: c !== null
                    z: 5000
                    x: c ? c.x : 0; y: c ? c.y : 0; width: c ? c.w : 0; height: c ? c.h : 0
                    color: "transparent"
                    border.color: cv.invalid ? cv.th.danger : cv.th.accent; border.width: 2 / cv.zoom
                    radius: (c ? Math.min(cv.store.styleOf(modelData).radius, c.h / 2) : 0) + 3
                    Rectangle {
                        visible: modelData === cv.sel && cv.sels.length <= 1
                        width: 16 / cv.zoom; height: width; radius: width / 2
                        x: parent.width - width - 8 / cv.zoom; y: parent.height - height - 8 / cv.zoom
                        color: cv.invalid ? cv.th.danger : cv.th.accent; border.color: "#0b0c10"; border.width: 2 / cv.zoom
                    }
                }
            }
            Rectangle {                                       // rubber band
                id: band
                visible: false; z: 5100
                color: Qt.rgba(Qt.color(cv.th.accent).r, Qt.color(cv.th.accent).g, Qt.color(cv.th.accent).b, 0.14)
                border.color: cv.th.accent; border.width: 1 / cv.zoom
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            readonly property real handleZone: 30     // stage px in the lower-right corner

            onPositionChanged: mouse => {
                var x = mouse.x / cv.zoom, y = mouse.y / cv.zoom;
                if (!pressed) {
                    cv.hoverId = cv.idAt(x, y);
                    var h = cv.hoverId !== "" ? cv.hostFor(cv.hoverId) : null;
                    if (h) { var c = h.cfg; h.kickOverride = Math.round((((x - c.x) / c.w - 0.5) * 16 + ((y - c.y) / c.h - 0.5) * 8) / 2) * 2; }
                    return;
                }
                cv.moveTo(x, y, mouse.modifiers);
            }
            onExited: { cv.hoverId = ""; }
            onPressed: mouse => cv.pressAt(mouse.x / cv.zoom, mouse.y / cv.zoom, mouse.modifiers)
            onReleased: cv.release()
        }
    }
}
