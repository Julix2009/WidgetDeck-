// Rain beads / snow flakes on a Liquid Glass widget, drawn by ONE shader item (drops.frag) from at most 40 circles.
//
//   Lives in GlassPanel.overlay (above the glass, below the widget content, never scaled) and refracts the panel's own blurred
//   wallpaper crop with the panel's own style numbers, so the beads are made of the same material as the widget.
//   rain: beads form, wait, then run down in stick-slip; snow: flakes drift down, settle and melt.
//   Cost model: dry / hidden / off -> the item is invisible and the timer stopped: zero cost.
//               active -> one uniform update per 50 ms for the drops that actually moved, ONE cached shader layer rendered at
//               logical resolution. The simulation reuses a fixed pool of 40 slots - nothing is created while it runs.
import QtQuick
import QtQuick.Window

Item {
    id: gd
    required property var panel          // the GlassPanel this overlay belongs to
    property string kind: ""              // "rain" | "snow" | "" (dry: nothing is rendered)
    property real density: 1.0            // 0.1 .. 1.0  (1.0 = 40 drops)
    property real unit: 1.0               // size factor of the beads

    anchors.fill: parent
    readonly property int maxDrops: 40
    readonly property bool wanted: kind !== "" && density > 0 && panel.liquid && panel.backend.dropsReady && panel.bdTexture !== null
    readonly property bool showing: wanted && Window.window !== null && Window.window.visible
    readonly property int active: Math.max(4, Math.round(maxDrops * density))
    readonly property var st: panel.style

    property var sState: []     // 0 dead (waiting), 1 forming, 2 resting, 3 moving, 4 fading
    property var sT: []
    property var sX: []
    property var sY: []
    property var sR: []
    property var sR0: []
    property var sA: []
    property var sV: []
    property var sK: []
    property var sKT: []
    property var sDist: []
    property var sRest: []
    property var lX: []
    property var lY: []
    property var lR: []
    property var lA: []
    property double lastMs: 0
    property real warm: 0
    property string simKind: ""

    function rnd() { return Math.random(); }
    function resetPool() {
        for (var i = 0; i < maxDrops; i++) {
            sState[i] = 0; sT[i] = rnd() * 4; sX[i] = 0; sY[i] = 0; sR[i] = 0; sR0[i] = 0; sA[i] = 0; sV[i] = 0; sK[i] = 1; sKT[i] = 0; sDist[i] = 0; sRest[i] = 0;
            lX[i] = -1; lY[i] = -1; lR[i] = -1; lA[i] = -1;
        }
        simKind = kind;
    }
    function spawn(i) {
        var w = fx.width, h = fx.height, u = unit, m = Math.max(10, panel.eRadius * 0.8) + 8;
        if (simKind === "snow") {
            sR0[i] = u * (1.6 + rnd() * 2.6); sR[i] = sR0[i];
            sX[i] = m + rnd() * (w - 2 * m); sY[i] = -sR0[i] * 2; sA[i] = 0;
            sV[i] = u * (14 + rnd() * 20); sK[i] = rnd() * 6.28; sRest[i] = h * (0.12 + rnd() * 0.80);
            sState[i] = 3; sT[i] = 0;
        } else {
            var q = rnd(); sR0[i] = u * (2.4 + q * q * 6.5); sR[i] = sR0[i] * 0.3;
            sX[i] = m + rnd() * (w - 2 * m); sY[i] = m + rnd() * (h - 2 * m); sA[i] = 0;
            sV[i] = 0; sK[i] = 1; sKT[i] = 0; sDist[i] = u * (90 + rnd() * 330);
            sState[i] = 1; sT[i] = 0;
        }
    }
    function step(dt) {
        var w = fx.width, h = fx.height, u = unit, n = active;
        for (var i = 0; i < maxDrops; i++) {
            var st_ = sState[i];
            if (i >= n) {
                if (st_ !== 0 && st_ !== 4) { sState[i] = 4; sT[i] = 0; }
                st_ = sState[i];
            }
            if (st_ === 0) {
                sT[i] -= dt;
                if (sT[i] <= 0 && i < n) spawn(i);
                continue;
            }
            sT[i] += dt;
            if (simKind === "snow") {
                if (st_ === 3) {
                    sA[i] = Math.min(1, sA[i] + dt * 1.2);
                    sY[i] += sV[i] * dt;
                    sX[i] += Math.sin(sT[i] * 1.3 + sK[i]) * u * 9 * dt;
                    if (sY[i] >= sRest[i]) { sState[i] = 2; sT[i] = 0; sK[i] = 3 + rnd() * 7; }
                } else if (st_ === 2) {
                    if (sT[i] > sK[i]) { sState[i] = 4; sT[i] = 0; }
                } else if (st_ === 4) {
                    sA[i] -= dt / 1.4; sR[i] = Math.max(0.2, sR[i] - dt * u * 0.5);
                    if (sA[i] <= 0) { sA[i] = 0; sState[i] = 0; sT[i] = 0.4 + rnd() * 5; }
                }
                continue;
            }
            if (st_ === 1) {
                var f = Math.min(1, sT[i] / 1.3);
                sA[i] = f; sR[i] = sR0[i] * (0.3 + 0.7 * f);
                if (f >= 1) { sState[i] = 2; sT[i] = 0; sK[i] = (0.8 + rnd() * 7.0) * (1.25 - Math.min(1, sR0[i] / (u * 8))); }
            } else if (st_ === 2) {
                if (sT[i] > sK[i]) { sState[i] = 3; sT[i] = 0; sK[i] = 1; sKT[i] = 0; }
            } else if (st_ === 3) {
                sKT[i] -= dt;
                if (sKT[i] <= 0) { var c = rnd(); sK[i] = c < 0.25 ? 0.12 : (c < 0.6 ? 0.6 : (c < 0.9 ? 1.0 : 1.5)); sKT[i] = 0.25 + rnd() * 0.9; }
                var vT = u * (12 + sR0[i] / u * 5) * sK[i];
                sV[i] += (vT - sV[i]) * Math.min(1, dt * 3);
                sY[i] += sV[i] * dt; sDist[i] -= sV[i] * dt;
                sX[i] += Math.sin(sT[i] * 2.1 + i) * 0.25 * u * dt * 6;
                sR[i] = Math.max(sR0[i] * 0.62, sR[i] - dt * u * 0.12);
                if (sDist[i] <= 0 || sY[i] > h - 24 * u) { sState[i] = 4; sT[i] = 0; }
            } else if (st_ === 4) {
                sA[i] -= dt / 0.8;
                if (sA[i] <= 0) { sA[i] = 0; sState[i] = 0; sT[i] = 0.3 + rnd() * 3.5; }
            }
        }
    }
    // write only what changed: resting drops cost nothing
    function push() {
        var snow = simKind === "snow", wa = warm;
        for (var i = 0; i < maxDrops; i++) {
            var a = sA[i] * wa, x = sX[i], y = sY[i], r = sR[i];
            if (Math.abs(x - lX[i]) < 0.05 && Math.abs(y - lY[i]) < 0.05 && Math.abs(r - lR[i]) < 0.02 && Math.abs(a - lA[i]) < 0.004) continue;
            lX[i] = x; lY[i] = y; lR[i] = r; lA[i] = a;
            fx["d" + i] = Qt.vector4d(x, y, a <= 0.003 ? 0 : r, snow ? -a : a);
        }
    }

    Timer {
        interval: 50; repeat: true; running: gd.showing
        onTriggered: {
            var now = Date.now(), dt = gd.lastMs > 0 ? Math.min(0.12, (now - gd.lastMs) / 1000) : 0.05;
            gd.lastMs = now;
            gd.warm = Math.min(1, gd.warm + dt / 1.6);
            if (gd.simKind !== gd.kind) gd.resetPool();
            gd.step(dt);
            gd.push();
        }
    }
    onShowingChanged: { lastMs = 0; if (showing) { warm = 0; resetPool(); } }

    ShaderEffect {
        id: fx
        x: 0; y: 0; width: gd.panel.width; height: gd.panel.height     // exactly the panel; the crop texture is tied to it, so nothing to sync
        visible: gd.showing && gd.warm > 0.01
        layer.enabled: visible                // re-rendered only when a uniform changed (the 50 ms tick), cached in between
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width)), Math.max(1, Math.round(height)))     // logical resolution
        fragmentShader: gd.panel.backend.dropsReady ? gd.panel.backend.dropsUrl : ""

        property variant src: gd.panel.bdTexture
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector2d srcSize: gd.panel.bdSize
        // the texture is the panel's crop; the panel's top-left sits itemPad + srcMargin inside it
        property vector2d srcOffset: Qt.vector2d(gd.panel.itemPad + gd.panel.srcMargin, gd.panel.itemPad + gd.panel.srcMargin)
        property vector2d lightDir: { var a = gd.panel.lightDeg * Math.PI / 180; return Qt.vector2d(Math.cos(a), Math.sin(a)); }
        property real thickness: 30 * gd.panel.avg("refraction")
        property real dispersion: 0.06 * gd.panel.avg("aberration")
        property real rim: gd.panel.avg("highlight")
        property real saturation: gd.panel.avg("saturation")
        property real dark: gd.panel.gDark ? 1 : 0
        property real tintMix: gd.panel.gDark ? Math.min(0.92, 0.25 + gd.panel.avg("bg_alpha") * 0.8) : Math.min(0.92, 0.45 + gd.panel.avg("bg_alpha") * 0.9)
        property real count: gd.active
        property vector4d d0: Qt.vector4d(0, 0, 0, 0)
        property vector4d d1: Qt.vector4d(0, 0, 0, 0)
        property vector4d d2: Qt.vector4d(0, 0, 0, 0)
        property vector4d d3: Qt.vector4d(0, 0, 0, 0)
        property vector4d d4: Qt.vector4d(0, 0, 0, 0)
        property vector4d d5: Qt.vector4d(0, 0, 0, 0)
        property vector4d d6: Qt.vector4d(0, 0, 0, 0)
        property vector4d d7: Qt.vector4d(0, 0, 0, 0)
        property vector4d d8: Qt.vector4d(0, 0, 0, 0)
        property vector4d d9: Qt.vector4d(0, 0, 0, 0)
        property vector4d d10: Qt.vector4d(0, 0, 0, 0)
        property vector4d d11: Qt.vector4d(0, 0, 0, 0)
        property vector4d d12: Qt.vector4d(0, 0, 0, 0)
        property vector4d d13: Qt.vector4d(0, 0, 0, 0)
        property vector4d d14: Qt.vector4d(0, 0, 0, 0)
        property vector4d d15: Qt.vector4d(0, 0, 0, 0)
        property vector4d d16: Qt.vector4d(0, 0, 0, 0)
        property vector4d d17: Qt.vector4d(0, 0, 0, 0)
        property vector4d d18: Qt.vector4d(0, 0, 0, 0)
        property vector4d d19: Qt.vector4d(0, 0, 0, 0)
        property vector4d d20: Qt.vector4d(0, 0, 0, 0)
        property vector4d d21: Qt.vector4d(0, 0, 0, 0)
        property vector4d d22: Qt.vector4d(0, 0, 0, 0)
        property vector4d d23: Qt.vector4d(0, 0, 0, 0)
        property vector4d d24: Qt.vector4d(0, 0, 0, 0)
        property vector4d d25: Qt.vector4d(0, 0, 0, 0)
        property vector4d d26: Qt.vector4d(0, 0, 0, 0)
        property vector4d d27: Qt.vector4d(0, 0, 0, 0)
        property vector4d d28: Qt.vector4d(0, 0, 0, 0)
        property vector4d d29: Qt.vector4d(0, 0, 0, 0)
        property vector4d d30: Qt.vector4d(0, 0, 0, 0)
        property vector4d d31: Qt.vector4d(0, 0, 0, 0)
        property vector4d d32: Qt.vector4d(0, 0, 0, 0)
        property vector4d d33: Qt.vector4d(0, 0, 0, 0)
        property vector4d d34: Qt.vector4d(0, 0, 0, 0)
        property vector4d d35: Qt.vector4d(0, 0, 0, 0)
        property vector4d d36: Qt.vector4d(0, 0, 0, 0)
        property vector4d d37: Qt.vector4d(0, 0, 0, 0)
        property vector4d d38: Qt.vector4d(0, 0, 0, 0)
        property vector4d d39: Qt.vector4d(0, 0, 0, 0)
    }
}
