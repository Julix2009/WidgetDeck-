// Reusable glass background + container for ONE widget / panel.
//
//   style.mode = "frosted": translucent card, the blur comes from Hyprland (layerrule on the window)
//   style.mode = "liquid" : Liquid Glass (glass.frag, derived from MacShell, MIT - see NOTICE.md; same pipeline idea as its widget layer):
//                           backdrop item (wallpaper placed at the real screen position) -> Gaussian pre-blur
//                           (MultiEffect) -> refraction shader.
//
// The panel item itself is the glass rectangle. The shader draws a 10 px shadow band around it; the hosting
// window has to leave that much room (the desktop windows leave `padPx`).
// Children are placed inside the panel (default property).
//
// Performance: backdrop texture, blur and shader output are cached (live: false, layer) and only refreshed when
// geometry, wallpaper or a parameter changes - not per frame.
import QtQuick
import QtQuick.Effects
import "Defaults.js" as D

Item {
    id: root

    required property var style           // resolved style (Defaults.resolveStyle)
    required property var backend         // GlassBackend
    required property var wall            // Wallpaper
    property real screenX: 0              // position of this glass rectangle on the monitor (logical px)
    property real screenY: 0
    property size screenSize: Qt.size(2560, 1600)
    property var peers: []                // other glass rectangles: [{x,y,w,h,style}] in screen coordinates
    property real padPx: 56               // room the hosting window leaves around the panel
    property bool interactive: true       // hover / press springs
    property Item backdrop: null          // optional backdrop item (live capture); default = wallpaper
    // Shared mode (many glass surfaces fed by ONE blurred wallpaper texture of the whole screen; not used by the desktop widgets),
    // every surface samples it by its absolute screen position (screenX/screenY, kept up to date by the owner).
    // null = this panel renders its own backdrop crop (desktop widgets, builder).
    property Item shared: null
    property bool pulseOnResize: true
    property real stretchX: 0             // drag velocity feeding the squish (set by the builder)
    property real stretchY: 0
    property alias pointerInside: hh.hovered
    default property alias content: contentArea.data
    // Overlay: items here sit ABOVE the glass and BELOW the content, in the unscaled glass layer (rain beads, ...).
    property alias overlay: overlayArea.data
    // the panel's own blurred wallpaper crop, for overlays that refract the same backdrop (non-shared mode)
    readonly property var bdTexture: backdropLoader.item ? backdropLoader.item.blurred : null
    readonly property size bdSize: backdropLoader.item ? Qt.size(backdropLoader.item.outW, backdropLoader.item.outH) : Qt.size(1, 1)

    readonly property bool liquid: style.mode === "liquid" && backend.ready
    readonly property bool panelReady: !liquid || (backdropLoader.item !== null && backdropLoader.item.ready)
    // The glass is a SHAPE: its size animates (gw/gh), the backdrop texture stays glued to the screen. Nothing here is
    // scaled as a bitmap. The shader item has a fixed size (panel + growRoom), the glass is centred inside it.
    readonly property real growRoom: (interactive && style.mode === "liquid") ? 32 : 0
    property real hv: 0                   // hover amount 0..1 (spring)
    readonly property real hs_: (style.hover_on === false ? 0 : 1) * (style.hover_strength !== undefined ? style.hover_strength : 1)
    readonly property real hoverGrow: 0.03 * hs_ * hv
    readonly property real gw: Math.max(2, Math.min(width * (1 + hoverGrow) * sx, width + 2 * growRoom))
    readonly property real gh: Math.max(2, Math.min(height * (1 + hoverGrow) * sy, height + 2 * growRoom))
    property real radiusOverride: -1       // hosts that follow a moving item pass its radius here (a style change would re-evaluate every binding)
    readonly property real eRadius: Math.max(1, Math.min(radiusOverride >= 0 ? radiusOverride : style.radius, gh / 2, gw / 2))
    // concentric corners: inner radius = outer radius - padding
    readonly property real innerRadius: Math.max(3, eRadius - contentPad)
    property real contentPad: Math.round(1.1 * style.font_size)

    // ───────────── merged panels share the group average so no seam shows (merge = 0 -> own style only) ─────────────
    function group() {
        var cx = screenX + width / 2, cy = screenY + height / 2, own = style, nb = [];
        if (own.merge > 0) for (var i = 0; i < peers.length; i++) {
            var p = peers[i], ps = p.style;
            if (!ps || ps.mode !== "liquid") continue;
            var k = Math.min(own.merge, ps.merge);
            if (k <= 0) continue;
            var gx = Math.max(Math.abs((p.x + p.w / 2) - cx) - (p.w + width) / 2, 0);
            var gy = Math.max(Math.abs((p.y + p.h / 2) - cy) - (p.h + height) / 2, 0);
            var gap = Math.sqrt(gx * gx + gy * gy);
            if (gap >= 1.6 * k) continue;
            nb.push({ gap: gap, cx: (p.x + p.w / 2) - cx, cy: (p.y + p.h / 2) - cy, hx: p.w / 2, hy: p.h / 2,
                      r: Math.min(ps.radius, p.h / 2, p.w / 2), k: 2.6 * k, st: ps, w: p.w, h: p.h });
        }
        nb.sort(function (a, b) { return a.gap - b.gap; });
        return nb.slice(0, 4);
    }
    readonly property var noNeighbors: []                  // one shared empty array: no binding churn while a surface moves
    // merge == 0 (the default): never touch screenX / the peers -> a moving surface does not re-evaluate the shader bindings
    readonly property var nbList: (liquid && style.merge > 0) ? group() : noNeighbors
    function avg(key) {
        var s = Number(style[key]), n = 1;
        for (var i = 0; i < nbList.length; i++) { s += Number(nbList[i].st[key]); n++; }
        return s / n;
    }
    // smallest edge of the group: the bezel is derived from min(w,h)
    readonly property real gMin: {
        var m = Math.min(gw, gh);
        for (var i = 0; i < nbList.length; i++) m = Math.min(m, Math.min(nbList[i].w, nbList[i].h));
        return m;
    }
    readonly property bool gDark: style.dark === true
    property real lightPulse: 0           // content-driven highlight movement (e.g. music widget on song change)
    property real pointerKick: 0          // degrees the highlight drifts towards the pointer (only with light_follow)
    // hover: the highlight moves a little (the glass looks thicker) - the backdrop does not move
    readonly property real lightDeg: avg("light_angle") + ((style.light_follow && nbList.length === 0) ? pointerKick : 0) + lightPulse + 5 * hs_ * hv

    // ───────────── backdrop pipeline (same idea as the MacShell widget layer) ─────────────
    readonly property real shaderPad: 10
    readonly property real itemPad: shaderPad + growRoom        // shader item = panel + itemPad on every side
    readonly property real srcMargin: 72
    readonly property real blurPxStyle: avg("blur")
    readonly property real ds: blurPxStyle >= 8 ? 0.5 : 1.0
    readonly property real bn: Math.min(1.0, blurPxStyle * 1.4 * ds / 64.0)
    readonly property string sig: [screenX, screenY, width, height, blurPxStyle, wall.url, screenSize.width, screenSize.height, backdrop ? 1 : 0].join("|")

    Loader {
        id: backdropLoader
        active: root.liquid && root.shared === null
        sourceComponent: Item {
            id: gl
            property alias blurred: blurredSrc
            property alias bsrc: bsrcItem
            readonly property real outW: root.width + 2 * (root.itemPad + root.srcMargin)
            readonly property real outH: root.height + 2 * (root.itemPad + root.srcMargin)

            // A hidden ShaderEffectSource with live:false only renders once; scheduleUpdate() is not honoured later.
            // So an update = live for a short moment (both stages), then frozen again: no per-frame rendering at rest.
            property bool updating: false
            property bool ready: false          // first backdrop rendered: only then the glass fades in (no placeholder flash)
            function refresh() { updating = true; freezeTimer.restart(); }
            Timer { id: freezeTimer; interval: 350; onTriggered: { gl.updating = false; if (wallImg.status === Image.Ready) gl.ready = true; } }
            Timer { interval: 2500; running: true; onTriggered: gl.ready = true }     // wallpaper missing / unreadable: show anyway

            Item {
                id: backdropItem
                width: gl.outW; height: gl.outH
                Rectangle {          // placeholder while no wallpaper is available
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#2f6bff" }
                        GradientStop { position: 0.5; color: "#b44cff" }
                        GradientStop { position: 1.0; color: "#ff8a3d" }
                    }
                }
                Image {
                    id: wallImg
                    x: -(root.screenX - root.itemPad - root.srcMargin)
                    y: -(root.screenY - root.itemPad - root.srcMargin)
                    width: root.screenSize.width
                    height: root.screenSize.height
                    source: root.wall.url
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: root.screenSize.width
                    smooth: true
                    onStatusChanged: if (status === Image.Ready) Qt.callLater(gl.refresh)
                }
            }
            ShaderEffectSource {
                id: bsrcItem
                sourceItem: root.backdrop ? root.backdrop : backdropItem
                sourceRect: root.backdrop ? Qt.rect(root.screenX - root.itemPad - root.srcMargin, root.screenY - root.itemPad - root.srcMargin, gl.outW, gl.outH) : Qt.rect(0, 0, 0, 0)
                hideSource: true
                live: gl.updating
                visible: false
                textureSize: Qt.size(Math.max(1, Math.round(gl.outW * root.ds)), Math.max(1, Math.round(gl.outH * root.ds)))
            }
            MultiEffect {
                id: blurFx
                source: bsrcItem
                width: gl.outW * root.ds
                height: gl.outH * root.ds
                blurEnabled: true
                blurMax: 64
                blur: root.bn
                autoPaddingEnabled: false
                visible: false
            }
            ShaderEffectSource { id: blurredSrc; sourceItem: blurFx; live: gl.updating; visible: false }
            Connections {
                target: root.backdrop
                ignoreUnknownSignals: true
                function onFrame() { gl.refresh(); }
            }
            Connections { target: root; function onSigChanged() { Qt.callLater(gl.refresh); } }
            Component.onCompleted: Qt.callLater(refresh)
        }
    }

    // ───────────── spring physics (hover / press / drag stretch / resize pop) ─────────────
    property real sx: 1
    property real sy: 1
    property real vx: 0
    property real vy: 0
    property real stX: 0                  // decaying squish from drag velocity
    property real stY: 0
    property bool hoverOverride: false     // the builder drives these itself
    property bool pressOverride: false
    property real kickOverride: 0
    readonly property bool wantsHover: (hh.hovered && interactive) || hoverOverride
    readonly property bool pressed: (tap.pressed && interactive) || pressOverride
    // targets of the shape springs (hover has its own spring `hv`; it grows the glass about its centre)
    function targetX() { var t = pressed ? 1.045 : 1.0; return t * (1 + stX - 0.5 * stY); }
    function targetY() { var t = pressed ? 0.935 : 1.0; return t * (1 + stY - 0.5 * stX); }
    property real hvv: 0                  // velocity of the hover spring
    function wake() { if (liquid && !fa.running) fa.running = true; }
    onWantsHoverChanged: wake()
    onPressedChanged: wake()
    onStretchXChanged: { stX = Math.min(0.09, Math.max(stX, Math.abs(stretchX) * 0.0045)); wake(); }
    onStretchYChanged: { stY = Math.min(0.09, Math.max(stY, Math.abs(stretchY) * 0.0045)); wake(); }
    function pulse(rx, ry) {
        if (!liquid) return;
        sx = Math.max(0.5, Math.min(1.5, rx)); sy = Math.max(0.5, Math.min(1.5, ry)); vx = 0; vy = 0; wake();
    }
    property real _pw: width
    property real _ph: height
    onWidthChanged: { if (pulseOnResize && _pw > 0 && width > 0 && liquid) pulse(_pw / width, sy); _pw = width; }
    onHeightChanged: { if (pulseOnResize && _ph > 0 && height > 0 && liquid) pulse(sx, _ph / height); _ph = height; }
    FrameAnimation {
        id: fa
        onTriggered: {
            var dt = Math.min(frameTime, 0.033), decay = Math.exp(-dt * 11);
            root.stX *= decay; root.stY *= decay;
            var tx = root.targetX(), ty = root.targetY(), K = 230, C = 15;
            root.vx += (K * (tx - root.sx) - C * root.vx) * dt; root.sx += root.vx * dt;
            root.vy += (K * (ty - root.sy) - C * root.vy) * dt; root.sy += root.vy * dt;
            // hover spring: stiffness follows the configured duration (440 ms = the classic feel)
            var f = 440 / Math.max(120, root.style.hover_duration || 440), th = root.wantsHover ? 1 : 0;
            root.hvv += (230 * f * f * (th - root.hv) - 15 * f * root.hvv) * dt; root.hv += root.hvv * dt;
            if (Math.abs(root.sx - tx) < 5e-4 && Math.abs(root.sy - ty) < 5e-4 && Math.abs(root.vx) < 5e-3
                && Math.abs(root.vy) < 5e-3 && root.stX < 4e-4 && root.stY < 4e-4
                && Math.abs(root.hv - th) < 5e-4 && Math.abs(root.hvv) < 5e-3) {
                root.sx = tx; root.sy = ty; root.vx = 0; root.vy = 0; root.hv = th; root.hvv = 0; running = false;
            }
        }
    }
    HoverHandler {
        id: hh
        enabled: root.interactive
        onPointChanged: {
            if (!root.liquid || !root.style.light_follow) return;
            var p = point.position;
            root.pointerKick = hh.hovered ? Math.round(((p.x / Math.max(1, root.width) - 0.5) * 16 + (p.y / Math.max(1, root.height) - 0.5) * 8) / 2) * 2 : 0;
        }
        onHoveredChanged: if (!hovered) root.pointerKick = 0
    }
    TapHandler { id: tap; enabled: root.interactive; gesturePolicy: TapHandler.WithinBounds; grabPermissions: PointerHandler.ApprovesTakeOverByAnything }

    // ───────────── visuals ─────────────
    // No scale transform anywhere on the glass: it would stretch the sampled backdrop with it.
    Item {
        id: body
        anchors.fill: parent

        // frosted glass: translucent card; Hyprland blurs what is behind the window
        Loader {
            id: frostedLoader
            anchors.fill: parent
            active: !root.liquid
            sourceComponent: Item {
                Rectangle {
                    id: frCard
                    anchors.fill: parent
                    radius: root.style.radius
                    color: Qt.rgba(D.hexRgb(root.style.bg)[0], D.hexRgb(root.style.bg)[1], D.hexRgb(root.style.bg)[2], root.style.bg_alpha)
                    border.width: 1
                    border.color: Qt.rgba(D.hexRgb(root.style.border_color)[0], D.hexRgb(root.style.border_color)[1], D.hexRgb(root.style.border_color)[2], root.style.border_alpha)
                    layer.enabled: true
                    visible: false
                    Rectangle {   // sheen
                        visible: root.style.glass
                        anchors.fill: parent
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.11) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.02) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                        }
                    }
                }
                MultiEffect {
                    anchors.fill: frCard
                    source: frCard
                    shadowEnabled: root.style.shadow > 0
                    shadowColor: "black"
                    shadowOpacity: Math.min(1, root.style.shadow)
                    shadowBlur: 1.0
                    shadowVerticalOffset: 8
                    autoPaddingEnabled: true
                }
            }
        }

        // liquid glass: refraction shader, rendered into a cached layer (runs again only when an input changes)
        ShaderEffect {
            id: fx
            readonly property bool srcReady: root.shared ? root.shared.ready : (backdropLoader.item !== null && backdropLoader.item.ready)
            visible: root.liquid && (root.shared !== null || backdropLoader.item !== null) && opacity > 0.001
            opacity: srcReady ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
            x: -root.itemPad; y: -root.itemPad                   // fixed in screen space (the glass is drawn centred in it)
            width: root.width + 2 * root.itemPad
            height: root.height + 2 * root.itemPad
            layer.enabled: visible
            layer.smooth: true
            fragmentShader: root.backend.ready ? root.backend.shaderUrl : ""

            property variant src: root.shared ? root.shared.blurred : (backdropLoader.item ? backdropLoader.item.blurred : null)
            property vector2d itemSize: Qt.vector2d(width, height)
            property vector2d glassSize: Qt.vector2d(root.gw, root.gh)
            // shared: the texture IS the screen, the item's top-left on screen is the offset -> absolute sampling
            property vector2d srcSize: root.shared ? Qt.vector2d(root.shared.screenW, root.shared.screenH)
                                                   : (backdropLoader.item ? Qt.vector2d(backdropLoader.item.outW, backdropLoader.item.outH) : Qt.vector2d(1, 1))
            property vector2d srcOffset: root.shared ? Qt.vector2d(root.screenX - root.itemPad, root.screenY - root.itemPad)
                                                     : Qt.vector2d(root.srcMargin, root.srcMargin)
            property vector2d lightDir: {
                var a = root.lightDeg * Math.PI / 180;
                return Qt.vector2d(Math.cos(a), Math.sin(a));
            }
            property real pad: root.itemPad
            property real radius: root.eRadius
            property real bezel: Math.min(root.gMin * 0.36, 26) * root.avg("bezel")
            property real hoverRefr: 1 + 0.10 * root.hs_ * root.hv         // the lens gets a little thicker on hover
            property real thickness: 30 * root.avg("refraction") * hoverRefr
            property real dispersion: 0.06 * root.avg("aberration")
            property real magnify: 0.08 * root.avg("refraction") * Math.min(1, 90 / root.gh)
            property real rim: root.avg("highlight")
            property real grain: root.avg("grain") * 0.15
            property real blurPx: 1.0
            property real tintMix: root.gDark ? Math.min(0.92, 0.25 + root.avg("bg_alpha") * 0.8)
                                              : Math.min(0.92, 0.45 + root.avg("bg_alpha") * 0.9)
            property real saturation: root.avg("saturation")
            property real dark: root.gDark ? 1 : 0
            property real debug: 0
            property real shadowAmt: root.avg("shadow")
            property vector4d themeTint: {
                var c = D.hexRgb(root.style.tint_color);
                return Qt.vector4d(c[0], c[1], c[2], root.avg("theme_tint"));
            }
            property real nbCount: root.nbList.length
            property vector4d nb0: root.nbList.length > 0 ? Qt.vector4d(root.nbList[0].cx, root.nbList[0].cy, root.nbList[0].hx, root.nbList[0].hy) : Qt.vector4d(0, 0, 0, 0)
            property vector4d nb1: root.nbList.length > 1 ? Qt.vector4d(root.nbList[1].cx, root.nbList[1].cy, root.nbList[1].hx, root.nbList[1].hy) : Qt.vector4d(0, 0, 0, 0)
            property vector4d nb2: root.nbList.length > 2 ? Qt.vector4d(root.nbList[2].cx, root.nbList[2].cy, root.nbList[2].hx, root.nbList[2].hy) : Qt.vector4d(0, 0, 0, 0)
            property vector4d nb3: root.nbList.length > 3 ? Qt.vector4d(root.nbList[3].cx, root.nbList[3].cy, root.nbList[3].hx, root.nbList[3].hy) : Qt.vector4d(0, 0, 0, 0)
            property vector4d nbR: Qt.vector4d(root.nbList.length > 0 ? root.nbList[0].r : 0, root.nbList.length > 1 ? root.nbList[1].r : 0,
                                               root.nbList.length > 2 ? root.nbList[2].r : 0, root.nbList.length > 3 ? root.nbList[3].r : 0)
            property vector4d nbK: Qt.vector4d(root.nbList.length > 0 ? root.nbList[0].k : 0, root.nbList.length > 1 ? root.nbList[1].k : 0,
                                               root.nbList.length > 2 ? root.nbList[2].k : 0, root.nbList.length > 3 ? root.nbList[3].k : 0)
            onStatusChanged: if (status === ShaderEffect.Error && root.backend.ready) { console.log("[widgetdeck-glass] shader error:", log); root.backend.state = "failed"; }
        }

        Item { id: overlayArea; anchors.fill: parent }

        // content (text, icons, cover, visualizer) may grow with the glass - it is NOT the background
        Item {
            id: contentArea
            anchors.fill: parent
            transform: Scale {
                origin.x: contentArea.width / 2; origin.y: contentArea.height / 2
                xScale: root.liquid ? Math.sqrt(root.gw / root.width * root.gh / root.height) : 1
                yScale: xScale
            }
        }
    }
}
