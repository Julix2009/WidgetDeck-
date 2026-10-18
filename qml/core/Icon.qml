// A line icon from Icons.js (own drawings, independent of fonts and icon themes). Size = width/height, colour = color.
import QtQuick
import QtQuick.Shapes
import "Icons.js" as I

Item {
    id: ic
    property string name: ""
    property color color: "white"
    property real stroke: 2
    implicitWidth: 24; implicitHeight: 24
    readonly property string d: I.PATHS[name] || ""
    Shape {
        width: 24; height: 24
        scale: Math.min(ic.width, ic.height) / 24
        transformOrigin: Item.TopLeft
        x: (ic.width - 24 * scale) / 2; y: (ic.height - 24 * scale) / 2
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"; strokeColor: ic.color; strokeWidth: ic.stroke
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathSvg { path: ic.d }
        }
    }
}
