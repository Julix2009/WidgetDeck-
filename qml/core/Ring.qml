// Progress ring (GPU path rendering).
import QtQuick
import QtQuick.Shapes

Item {
    id: r
    property real value: 0
    property color trackColor: "#20ffffff"
    property color barColor: "#8ab4ff"
    property real thickness: width * 0.09
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        ShapePath {
            strokeColor: r.trackColor; strokeWidth: r.thickness; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: r.width / 2; centerY: r.height / 2; radiusX: r.width / 2 - r.thickness / 2; radiusY: r.height / 2 - r.thickness / 2; startAngle: -90; sweepAngle: 359.9 }
        }
        ShapePath {
            strokeColor: r.barColor; strokeWidth: r.thickness; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: r.width / 2; centerY: r.height / 2; radiusX: r.width / 2 - r.thickness / 2; radiusY: r.height / 2 - r.thickness / 2; startAngle: -90; sweepAngle: Math.max(1, Math.min(359.9, r.value * 360)) }
        }
    }
}
