// The whole day as a ring: the arc shows how much of the day has passed, a glowing dot marks "now"; time and date in the middle.
import QtQuick
import QtQuick.Shapes
import "../../core"

Item {
    id: d
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property color cAcc: w.tstyle.accent || "#8ab4ff"
    readonly property real side: Math.min(width, height)
    readonly property real stroke: side * 0.045
    readonly property real rad: side / 2 - stroke * 1.4
    readonly property real part: (w.now.getHours() * 3600 + w.now.getMinutes() * 60 + w.now.getSeconds()) / 86400
    readonly property real a: (part * 360 - 90) * Math.PI / 180

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        ShapePath {
            strokeColor: Qt.alpha(d.cFg, 0.16); strokeWidth: d.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: d.width / 2; centerY: d.height / 2; radiusX: d.rad; radiusY: d.rad; startAngle: -90; sweepAngle: 359.9 }
        }
        ShapePath {
            strokeColor: d.cAcc; strokeWidth: d.stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: d.width / 2; centerY: d.height / 2; radiusX: d.rad; radiusY: d.rad; startAngle: -90; sweepAngle: Math.max(0.1, d.part * 360) }
        }
    }
    Repeater {                                    // ticks every three hours
        model: 8
        delegate: Rectangle {
            required property int index
            readonly property real t: (index * 45 - 90) * Math.PI / 180
            width: Math.max(2, d.side * 0.012); height: width; radius: width / 2; color: d.cFg; opacity: 0.5
            x: d.width / 2 + Math.cos(t) * (d.rad - d.stroke * 1.5) - width / 2
            y: d.height / 2 + Math.sin(t) * (d.rad - d.stroke * 1.5) - height / 2
        }
    }
    Rectangle { width: d.stroke * 2.4; height: width; radius: width / 2; color: Qt.alpha(d.cAcc, 0.35); x: d.width / 2 + Math.cos(d.a) * d.rad - width / 2; y: d.height / 2 + Math.sin(d.a) * d.rad - height / 2 }
    Rectangle { width: d.stroke * 1.2; height: width; radius: width / 2; color: d.cFg; x: d.width / 2 + Math.cos(d.a) * d.rad - width / 2; y: d.height / 2 + Math.sin(d.a) * d.rad - height / 2 }
    Column {
        anchors.centerIn: parent
        spacing: d.side * 0.01
        GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: d.w.tstyle; font.bold: true; font.pixelSize: d.side * (d.w.use12h ? 0.15 : 0.2); text: d.w.use12h ? d.w.fmt(d.w.now, "%I:%M %p") : d.w.fmt(d.w.now, "%H:%M") }
        GText { visible: d.w.props.show_date !== false; anchors.horizontalCenter: parent.horizontalCenter; wstyle: d.w.tstyle; opacity: 0.7; font.pixelSize: d.side * 0.07; text: d.w.fmt(d.w.now, "%a %e. %b") }
        GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: d.w.tstyle; color: d.cAcc; font.bold: true; font.pixelSize: d.side * 0.065; text: Math.floor(d.part * 100) + " %" }
    }
}
