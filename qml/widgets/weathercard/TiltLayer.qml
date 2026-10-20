// One rendered layer seen from a mouse-dependent angle: the sprite grid <base>/<yaw>_<pitch>.<ext> holds the same layer rendered from slightly different
// angles; the four neighbours of the current angle are blended (premultiplied "over" with opacities that add up to the right weights), so moving the
// mouse turns the object in 3D without jumps. Only the visible frames are loaded (cached by Qt's pixmap cache), `px` limits the decoded size.
import QtQuick

Item {
    id: tl
    property string base: ""                  // .../<variant>/<layer>
    property string ext: "png"
    property int yawCount: 5
    property int pitchCount: 3
    property real yaw: 0                      // -1 .. 1
    property real pitch: 0                    // -1 .. 1
    property int px: 256
    readonly property real yp: (Math.max(-1, Math.min(1, yaw)) + 1) / 2 * (yawCount - 1)
    readonly property real pp: (Math.max(-1, Math.min(1, pitch)) + 1) / 2 * (pitchCount - 1)
    readonly property int y0: Math.min(yawCount - 2, Math.floor(yp))
    readonly property int p0: Math.min(pitchCount - 2, Math.floor(pp))
    readonly property real fy: yp - y0
    readonly property real fp: pp - p0
    // weights of the four frames and the opacities that realise them when drawn one over the other
    readonly property real w1: (1 - fy) * (1 - fp)
    readonly property real w2: fy * (1 - fp)
    readonly property real w3: (1 - fy) * fp
    readonly property real w4: fy * fp
    function src(yi, pi) { return base + "/" + yi + "_" + pi + "." + ext; }
    component Frame: Image {
        property real wgt: 0
        property real cum: 0
        anchors.fill: parent
        smooth: true; mipmap: true; cache: true; asynchronous: false
        sourceSize: Qt.size(tl.px, tl.px)
        opacity: cum > 0.0001 ? wgt / cum : 1
        visible: wgt > 0.002 || cum <= 0.0001
    }
    Frame { source: tl.src(tl.y0, tl.p0); wgt: 1; cum: 1 }
    Frame { source: tl.src(tl.y0 + 1, tl.p0); wgt: tl.w2; cum: tl.w1 + tl.w2 }
    Frame { source: tl.src(tl.y0, tl.p0 + 1); wgt: tl.w3; cum: tl.w1 + tl.w2 + tl.w3 }
    Frame { source: tl.src(tl.y0 + 1, tl.p0 + 1); wgt: tl.w4; cum: 1 }
}
