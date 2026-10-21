// A track outline: a clean line with round ends, a fine drop shadow, fitted into this item (uniform scale, fixed padding) by changing the
// PATH COORDINATES (Model.fit) - no scale transform on any item. It is drawn on the glass without any fill. On the first display of a
// weekend the line draws itself along the path once (dash animation, optional); a new circuit blends over.
import QtQuick
import QtQuick.Shapes
import "Model.js" as M

Item {
    id: tr
    property var circuit: null                     // { w, h, closed, pts } from circuits.js, or null
    property string runKey: ""                     // changes per weekend: the draw-in animation runs once for each key
    property color color: "#f2f4f8"
    property real lineWidth: 3
    property real pad: 6
    property bool draw: true                       // draw-in animation allowed
    readonly property var geo: circuit ? M.fit(circuit, width, height, pad) : null
    property real prog: 1
    property var shown: null                       // the geometry on screen (changes only at the middle of a cross-fade)
    property string lastKey: ""

    onGeoChanged: { if (shown === null) shown = geo; else if (geo && shown && geo.len !== shown.len && !fade.running && !samePath()) fade.restart(); else shown = geo; }
    function samePath() { return shown && geo && shown.d === geo.d; }
    onRunKeyChanged: if (circuit && draw && runKey !== lastKey) { lastKey = runKey; prog = 0; grow.restart(); }
    Component.onCompleted: { shown = geo; if (circuit && draw) { lastKey = runKey; prog = 0; grow.restart(); } }
    NumberAnimation { id: grow; target: tr; property: "prog"; from: 0; to: 1; duration: 1500; easing.type: Easing.InOutCubic }
    SequentialAnimation {
        id: fade
        NumberAnimation { target: body; property: "opacity"; to: 0; duration: 160 }
        ScriptAction { script: tr.shown = tr.geo }
        NumberAnimation { target: body; property: "opacity"; to: 1; duration: 220 }
    }

    Item {
        id: body
        anchors.fill: parent
        visible: !!tr.shown
        // shadow (offset, softer), then the line
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.rgba(0, 0, 0, 0.32); strokeWidth: tr.lineWidth + 1.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                strokeStyle: tr.prog < 1 ? ShapePath.DashLine : ShapePath.SolidLine
                dashPattern: tr.shown ? [Math.max(0.01, tr.prog * tr.shown.len / (tr.lineWidth + 1.5)), tr.shown.len / (tr.lineWidth + 1.5) + 2] : [1, 1]
                PathSvg { path: tr.shown ? M.shiftPath(tr.shown.d, 1.4, 2.2) : "" }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: tr.color; strokeWidth: tr.lineWidth; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                strokeStyle: tr.prog < 1 ? ShapePath.DashLine : ShapePath.SolidLine
                dashPattern: tr.shown ? [Math.max(0.01, tr.prog * tr.shown.len / tr.lineWidth), tr.shown.len / tr.lineWidth + 2] : [1, 1]
                PathSvg { path: tr.shown ? tr.shown.d : "" }
            }
        }
    }
}
