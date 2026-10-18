// Small vector icons (no icon theme / font dependency): play, pause, next, prev.
import QtQuick
import QtQuick.Shapes

Item {
    id: g
    property string kind: "play"
    property color color: "white"
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {   // triangle(s)
            fillColor: g.color; strokeColor: "transparent"
            property real w: g.width; property real h: g.height
            PathSvg {
                path: {
                    var w = g.width, h = g.height;
                    if (g.kind === "play")  return "M " + w * 0.22 + " " + h * 0.12 + " L " + w * 0.88 + " " + h * 0.5 + " L " + w * 0.22 + " " + h * 0.88 + " Z";
                    if (g.kind === "next")  return "M " + w * 0.10 + " " + h * 0.14 + " L " + w * 0.66 + " " + h * 0.5 + " L " + w * 0.10 + " " + h * 0.86 + " Z M " + w * 0.74 + " " + h * 0.14 + " L " + w * 0.92 + " " + h * 0.14 + " L " + w * 0.92 + " " + h * 0.86 + " L " + w * 0.74 + " " + h * 0.86 + " Z";
                    if (g.kind === "prev")  return "M " + w * 0.90 + " " + h * 0.14 + " L " + w * 0.34 + " " + h * 0.5 + " L " + w * 0.90 + " " + h * 0.86 + " Z M " + w * 0.26 + " " + h * 0.14 + " L " + w * 0.08 + " " + h * 0.14 + " L " + w * 0.08 + " " + h * 0.86 + " L " + w * 0.26 + " " + h * 0.86 + " Z";
                    return "M " + w * 0.20 + " " + h * 0.14 + " L " + w * 0.40 + " " + h * 0.14 + " L " + w * 0.40 + " " + h * 0.86 + " L " + w * 0.20 + " " + h * 0.86 + " Z M " + w * 0.60 + " " + h * 0.14 + " L " + w * 0.80 + " " + h * 0.14 + " L " + w * 0.80 + " " + h * 0.86 + " L " + w * 0.60 + " " + h * 0.86 + " Z";
                }
            }
        }
    }
}
