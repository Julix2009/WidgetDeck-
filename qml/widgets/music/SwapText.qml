// Text that changes with a staggered slide/fade; long text scrolls (marquee) after the transition and restarts
// from the beginning on every change. Two slots; a change while the incoming slot is still animating retargets it.
import QtQuick

Item {
    id: st
    property string text: ""
    property color color: "white"
    property string family: "sans"
    property real pixelSize: 16
    property bool bold: false
    property real textOpacity: 1
    property int stagger: 0
    property int dir: 0
    property bool animate: true
    property int dur: 440
    property real shift: 9
    property bool started: false
    readonly property int effDur: animate ? dur : 0
    property int cur: 0
    property string want: ""
    property bool hasWant: false
    readonly property real pad: 5

    implicitHeight: probe.implicitHeight + 2 * pad
    height: implicitHeight
    clip: true

    Text { id: probe; visible: false; text: "Ag"; font.family: st.family; font.pixelSize: st.pixelSize; font.bold: st.bold; renderType: Text.QtRendering }

    SwapSlot { id: s0; st: st }
    SwapSlot { id: s1; st: st }
    function slot(i) { return i === 0 ? s0 : s1; }

    function setText(t) {
        want = t; hasWant = true;
        if (!started) return;
        if (!swapTimer.running) { swapTimer.interval = Math.max(1, animate ? stagger : 0); swapTimer.start(); }
    }
    onStartedChanged: if (started) { swapTimer.interval = 1; swapTimer.start(); }
    Timer {
        id: swapTimer
        onTriggered: {
            var c = st.slot(st.cur), o = st.slot(1 - st.cur);
            var first = !c.entered && c.text === "";
            if (c.entered && c.text === st.want) return;
            var dx = st.dir * st.shift * 1.4, dy = st.shift;
            if (first) { c.text = st.want; c.enter(0, 0, 0); return; }
            if (o.opacity < 0.03 && !o.entered) {            // free slot: normal swap
                o.text = st.want;
                o.enter(st.dir === 0 ? 0 : dx, dy, st.effDur * 0.2);
                c.exit(st.dir === 0 ? 0 : -dx, -dy);
                st.cur = 1 - st.cur;
            } else if (c.opacity < 0.9) {                    // incoming still animating: retarget it
                c.text = st.want;
                c.armMarquee();
            } else { swapTimer.interval = 40; swapTimer.start(); }
        }
    }
    // style changes (font size, colour) apply to both slots by binding; nothing to do
}
