// Analogue clock on a plate with a wavy, flower-like edge: hour dots, hour / minute / second hands, the date in a small pill.
import QtQuick
import "../../core"

Item {
    id: f
    required property var w                       // the ClockWidget (time, style, helpers)
    readonly property real side: Math.min(width, height)
    readonly property real r: side / 2
    readonly property int petals: Math.max(5, Math.min(16, Math.round(Number(w.props.petals || 10))))
    readonly property color cFg: w.style.fg || "#f2f4f8"
    readonly property color cAcc: w.style.accent || "#8ab4ff"
    readonly property color cPlate: w.palette.surface_container || "#1d2027"
    readonly property real h: w.now.getHours() % 12 + w.now.getMinutes() / 60
    readonly property real m: w.now.getMinutes() + w.now.getSeconds() / 60

    Canvas {
        id: plate
        anchors.centerIn: parent
        width: f.side; height: f.side
        property color fill: f.cPlate
        property color edge: f.cAcc
        property int n: f.petals
        rotation: f.w.props.spin === true ? (f.w.now.getSeconds() * 6) / f.n : 0
        Behavior on rotation { enabled: f.w.props.spin === true; RotationAnimation { duration: 900; direction: RotationAnimation.Shortest } }
        onFillChanged: requestPaint()
        onEdgeChanged: requestPaint()
        onNChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext("2d");
            c.reset();
            var cx = width / 2, cy = height / 2, R = width / 2 - 2, wave = R * 0.055;
            c.beginPath();
            for (var i = 0; i <= 360; i++) {
                var a = i * Math.PI / 180, rr = R - wave + wave * Math.cos(a * n);
                var x = cx + rr * Math.cos(a), y = cy + rr * Math.sin(a);
                if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
            }
            c.closePath();
            c.globalAlpha = 0.92; c.fillStyle = fill; c.fill();
            c.globalAlpha = 0.55; c.strokeStyle = edge; c.lineWidth = Math.max(1.5, width * 0.008); c.stroke();
        }
    }
    Repeater {                                    // hour dots, the quarters bigger
        model: 12
        delegate: Rectangle {
            required property int index
            readonly property real a: (index * 30 - 90) * Math.PI / 180
            width: f.side * (index % 3 === 0 ? 0.032 : 0.016); height: width; radius: width / 2
            color: index % 3 === 0 ? f.cAcc : f.cFg; opacity: index % 3 === 0 ? 1 : 0.5
            x: f.width / 2 + Math.cos(a) * f.r * 0.76 - width / 2
            y: f.height / 2 + Math.sin(a) * f.r * 0.76 - height / 2
        }
    }
    component Hand: Rectangle {
        id: hand
        property real len: 0.5
        property real thick: 0.05
        property real angle: 0
        width: f.side * thick; height: f.r * len + width / 2; radius: width / 2
        x: f.width / 2 - width / 2; y: f.height / 2 - height + width / 2
        antialiasing: true
        transform: Rotation { origin.x: width / 2; origin.y: height - width / 2; angle: hand.angle }
    }
    Rectangle {                                   // date pill below the centre
        visible: f.w.props.show_date !== false
        anchors.horizontalCenter: parent.horizontalCenter
        y: f.height / 2 + f.r * 0.26
        width: dt.implicitWidth + f.side * 0.07; height: dt.implicitHeight + f.side * 0.025; radius: height / 2
        color: Qt.alpha(f.cAcc, 0.22)
        GText { id: dt; anchors.centerIn: parent; wstyle: f.w.style; font.bold: true; font.pixelSize: f.side * 0.062; text: f.w.fmt(f.w.now, "%a %e. %b") }
    }
    Item {
        anchors.fill: parent
        Hand { angle: f.h * 30; len: 0.44; thick: 0.052; color: f.cFg }
        Hand { angle: f.m * 6; len: 0.64; thick: 0.036; color: f.cAcc }
        Hand { visible: f.w.props.show_seconds !== false; angle: f.w.now.getSeconds() * 6; len: 0.70; thick: 0.01; color: f.w.palette.error || "#ff8a80" }
    }
    Rectangle { anchors.centerIn: parent; width: f.side * 0.055; height: width; radius: width / 2; color: f.cFg }
    Rectangle { anchors.centerIn: parent; width: f.side * 0.022; height: width; radius: width / 2; color: f.cPlate }
}
