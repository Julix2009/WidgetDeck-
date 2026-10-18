// Album cover with A/B/C layers. A new cover is loaded in the background (a free layer) and only blended in when it
// is Ready - never an empty frame. Rapid skipping: the newest wanted cover wins, running animations are retargeted,
// not restarted, and a layer is only reused once it is invisible (no stacking, no popping).
import QtQuick
import QtQuick.Effects

Item {
    id: cs
    property string source: ""             // wanted cover url ("" = none -> fallback)
    property bool sourceKnown: false
    property color accent: "#8ab4ff"
    property bool animate: true
    property string animStyle: "slide"     // crossfade | slide | zoom
    property int dur: 440
    property real zoom: 0.06
    property real blurAmount: 0.5
    property int dir: 0                    // -1 previous, +1 next, 0 none (set by the widget before `source` changes)
    property real radius: 16
    property bool playing: true
    property bool glowOn: false
    property bool started: false
    property string shownUrl: ""
    readonly property int effDur: animate ? dur : 0
    readonly property bool busy: l0.moving || l1.moving || l2.moving
    property int cur: -1
    property string want: ""
    property bool hasWant: false
    property int wantDir: 0

    function lay(i) { return i === 0 ? l0 : (i === 1 ? l1 : l2); }
    function freeIndex() {
        for (var i = 0; i < 3; i++) { var L = lay(i); if (i !== cur && L.opacity < 0.02 && !L.entered) return i; }
        return -1;
    }
    function place() {
        if (!started || !hasWant) return;
        if (cur >= 0 && lay(cur).url === want) return;                       // already showing
        for (var j = 0; j < 3; j++) if (lay(j).pending && lay(j).url === want) return;   // already loading
        var f = freeIndex();
        if (f < 0) return;                                                    // retried when a layer becomes free
        var L = lay(f);
        L.pending = true;
        L.url = want;
        if (L.loaded) layerLoaded(L);
    }
    function layerLoaded(L) {
        if (!L.pending) return;
        L.pending = false;
        if (L.url !== want) { L.url = ""; place(); return; }                 // superseded while loading
        var i = L === l0 ? 0 : (L === l1 ? 1 : 2), old = cur, first = old < 0;
        var d = first ? 0 : wantDir;
        var off = (animStyle === "slide") ? width * 0.24 : 0;
        var s = (animStyle === "crossfade") ? 0 : zoom;
        cur = i;
        shownUrl = L.url;
        L.enter(d * off, 1 + s);
        if (old >= 0) lay(old).exit(-d * off, 1 - s);
    }
    function layerFreed() {
        for (var i = 0; i < 3; i++) { var L = lay(i); if (i !== cur && !L.pending && !L.entered && L.opacity < 0.02 && L.url !== "") L.url = ""; }
        place();
    }
    onSourceChanged: { want = source; hasWant = true; wantDir = dir; place(); }
    onSourceKnownChanged: if (sourceKnown) { want = source; hasWant = true; wantDir = dir; place(); }
    onStartedChanged: place()

    // soft glow behind the cover (follows the cover colours when "Farben aus dem Albumcover" is on)
    Rectangle {
        visible: cs.glowOn
        anchors.centerIn: parent
        width: parent.width * 1.0; height: parent.height * 1.0; radius: cs.radius
        color: cs.accent
        opacity: 0.55
        layer.enabled: cs.glowOn
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 48; blur: 1.0; scale: 1.25 }
    }

    // pause: the cover settles back a little (Apple Music style)
    property real restScale: (cs.animate && !cs.playing) ? 0.93 : 1
    Behavior on restScale { SpringAnimation { spring: 3.2; damping: 0.32; epsilon: 0.0008 } }

    Item {
        id: holder
        anchors.fill: parent
        scale: cs.restScale

        // soft shadow (follows the pause shrink with the holder)
        RectangularShadow {
            anchors.fill: parent
            radius: cs.radius
            blur: 18
            offset: Qt.point(0, 4)
            color: Qt.rgba(0, 0, 0, 0.45)
        }
        // content is clipped to a rounded rect by the mask below
        Item {
            id: clipBox
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: maskRect; autoPaddingEnabled: false }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(cs.accent, 1.1) }
                    GradientStop { position: 1.0; color: Qt.darker(cs.accent, 1.9) }
                }
            }
            CoverLayer { id: l0; anchors.fill: parent; stack: cs; onFreed: cs.layerFreed() }
            CoverLayer { id: l1; anchors.fill: parent; stack: cs; onFreed: cs.layerFreed() }
            CoverLayer { id: l2; anchors.fill: parent; stack: cs; onFreed: cs.layerFreed() }
        }
        Rectangle { id: maskRect; anchors.fill: parent; radius: cs.radius; visible: false; layer.enabled: true }
    }
}
