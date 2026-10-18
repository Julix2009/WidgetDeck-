import QtQuick

Text {
    id: s
    required property var st
    property real tx: 0
    property real ty: 0
    property real mx: 0
    property bool entered: false
    property bool animOn: true
    readonly property real overflow: Math.max(0, implicitWidth - st.width)
    x: tx + mx
    y: st.pad + ty
    opacity: 0
    color: st.color
    font.family: st.family
    font.pixelSize: st.pixelSize
    font.bold: st.bold
    wrapMode: Text.NoWrap
    renderType: Text.QtRendering
    Behavior on opacity { enabled: s.animOn; NumberAnimation { duration: s.entered ? st.effDur * 0.85 : st.effDur * 0.5; easing.type: s.entered ? Easing.OutCubic : Easing.InQuad } }
    Behavior on tx { enabled: s.animOn; NumberAnimation { duration: st.effDur; easing.type: Easing.OutCubic } }
    Behavior on ty { enabled: s.animOn; NumberAnimation { duration: st.effDur; easing.type: s.entered ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.3 } }

    // the new text starts a little after the old one began to leave: the two barely overlap
    function enter(dx, dy, delay) {
        animOn = false; opacity = 0; tx = dx; ty = dy; mx = 0; animOn = true;
        entered = true;
        if (delay > 0) { startT.interval = delay; startT.restart(); } else go();
    }
    function go() { opacity = st.textOpacity; tx = 0; ty = 0; armMarquee(); }
    function exit(dx, dy) { startT.stop(); entered = false; stopMarquee(); opacity = 0; tx = dx; ty = dy; }
    Timer { id: startT; onTriggered: s.go() }

    // marquee: pause -> scroll to the end -> pause -> back; Timers instead of looping animations (nothing runs at rest)
    function stopMarquee() { mTimer.stop(); fwd.stop(); back.stop(); }
    function armMarquee() { stopMarquee(); mx = 0; if (overflow > 1) mTimer.restart(); }
    Timer { id: mTimer; interval: st.effDur + 900; onTriggered: { interval = 1500; if (s.overflow > 1) fwd.restart(); } }
    NumberAnimation { id: fwd; target: s; property: "mx"; to: -s.overflow; duration: Math.max(1200, s.overflow * 28); easing.type: Easing.InOutSine
        onFinished: hold.restart() }
    Timer { id: hold; interval: 1300; onTriggered: back.restart() }
    NumberAnimation { id: back; target: s; property: "mx"; to: 0; duration: 520; easing.type: Easing.OutCubic
        onFinished: { mTimer.interval = 1500; mTimer.restart(); } }
    onOverflowChanged: if (entered) armMarquee()
    }
