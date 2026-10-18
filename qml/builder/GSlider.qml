import QtQuick

Item {
    id: s
    required property var th
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.01
    property int decimals: step >= 1 ? 0 : (step >= 0.1 ? 1 : 2)
    signal moved(real v)
    implicitHeight: 40
    Text { text: s.label; color: s.th.dim; font.family: s.th.font; font.pixelSize: 12 }
    Text { anchors.right: parent.right; text: s.value.toFixed(s.decimals); color: s.th.dim; font.family: s.th.font; font.pixelSize: 12 }
    Rectangle {
        id: track
        y: 24; width: parent.width; height: 5; radius: 3; color: Qt.rgba(1, 1, 1, 0.14)
        Rectangle { width: Math.max(0, knob.x + knob.width / 2); height: parent.height; radius: 3; color: s.th.accent }
        Rectangle {
            id: knob
            width: 16; height: 16; radius: 8; y: -5.5
            x: (s.to > s.from ? (s.value - s.from) / (s.to - s.from) : 0) * (track.width - width)
            color: ma.containsMouse || ma.pressed ? s.th.accent : "white"
            scale: ma.pressed ? 1.25 : 1
            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }
    MouseArea {
        id: ma
        y: 14; width: parent.width; height: 26
        hoverEnabled: true
        function setFrom(mx) {
            var t = Math.max(0, Math.min(1, (mx - knob.width / 2) / (track.width - knob.width)));
            var v = s.from + t * (s.to - s.from);
            v = Math.round(v / s.step) * s.step;
            v = Math.max(s.from, Math.min(s.to, +v.toFixed(4)));
            if (v !== s.value) s.moved(v);
        }
        onPressed: mouse => setFrom(mouse.x)
        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x); }
    }
}
