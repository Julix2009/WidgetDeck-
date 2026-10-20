// Offline renderer for one weather icon part: qml6 render.qml -- <spec.json> <out.png> <size> <qsb file>
// spec: { "prims": [{ "a": [x,y,z,r], "b": [x,y,z] }], "sub": [[x,y,z,r]], "k": 0.1, "base": "#rrggbb", "shade": "#rrggbb", "hi": "#rrggbb", "gloss": 0.7, "occl": 0.8 }
import QtQuick
Window {
    id: win
    visible: true
    color: "transparent"
    property var args: Qt.application.arguments
    property string specFile: args[args.length - 4]
    property string outFile: args[args.length - 3]
    property int size: parseInt(args[args.length - 2])
    property string qsbFile: args[args.length - 1]
    width: size; height: size
    function load(path) { var x = new XMLHttpRequest(); x.open("GET", "file://" + path, false); x.send(); return JSON.parse(x.responseText); }
    property var spec: load(specFile)
    Item {
        id: scene
        width: win.size; height: win.size           // the window may be resized by a tiling compositor - the grabbed item is not
        ShaderEffect {
            id: fx
            anchors.fill: parent
            fragmentShader: "file://" + win.qsbFile
        property vector4d a0: Qt.vector4d(0,0,0,0)
        property vector4d a1: Qt.vector4d(0,0,0,0)
        property vector4d a2: Qt.vector4d(0,0,0,0)
        property vector4d a3: Qt.vector4d(0,0,0,0)
        property vector4d a4: Qt.vector4d(0,0,0,0)
        property vector4d a5: Qt.vector4d(0,0,0,0)
        property vector4d a6: Qt.vector4d(0,0,0,0)
        property vector4d a7: Qt.vector4d(0,0,0,0)
        property vector4d a8: Qt.vector4d(0,0,0,0)
        property vector4d a9: Qt.vector4d(0,0,0,0)
        property vector4d a10: Qt.vector4d(0,0,0,0)
        property vector4d a11: Qt.vector4d(0,0,0,0)
        property vector4d b0: Qt.vector4d(0,0,0,0)
        property vector4d b1: Qt.vector4d(0,0,0,0)
        property vector4d b2: Qt.vector4d(0,0,0,0)
        property vector4d b3: Qt.vector4d(0,0,0,0)
        property vector4d b4: Qt.vector4d(0,0,0,0)
        property vector4d b5: Qt.vector4d(0,0,0,0)
        property vector4d b6: Qt.vector4d(0,0,0,0)
        property vector4d b7: Qt.vector4d(0,0,0,0)
        property vector4d b8: Qt.vector4d(0,0,0,0)
        property vector4d b9: Qt.vector4d(0,0,0,0)
        property vector4d b10: Qt.vector4d(0,0,0,0)
        property vector4d b11: Qt.vector4d(0,0,0,0)
        property vector4d s0: Qt.vector4d(0,0,0,0)
        property vector4d s1: Qt.vector4d(0,0,0,0)
        property vector4d s2: Qt.vector4d(0,0,0,0)
        property vector4d s3: Qt.vector4d(0,0,0,0)
        property vector4d s4: Qt.vector4d(0,0,0,0)
        property vector4d s5: Qt.vector4d(0,0,0,0)
        property vector4d s6: Qt.vector4d(0,0,0,0)
        property vector4d s7: Qt.vector4d(0,0,0,0)
            property color baseColor: win.spec.base
            property color shadeColor: win.spec.shade
            property color hiColor: win.spec.hi || "#ffffff"
            property real k: win.spec.k !== undefined ? win.spec.k : 0.1
            property real gloss: win.spec.gloss !== undefined ? win.spec.gloss : 0.6
            property real occl: win.spec.occl !== undefined ? win.spec.occl : 0.8
            property real px: 2.0 / win.size
            property real nCap: win.spec.prims.length
            property real nSub: (win.spec.sub || []).length
            Component.onCompleted: {
                var P = win.spec.prims, S = win.spec.sub || [];
                for (var i = 0; i < P.length; i++) {
                    var a = P[i].a, b = P[i].b || [a[0], a[1], a[2]];
                    fx["a" + i] = Qt.vector4d(a[0], a[1], a[2], a[3]);
                    fx["b" + i] = Qt.vector4d(b[0], b[1], b[2], 0);
                }
                for (var j = 0; j < S.length; j++) fx["s" + j] = Qt.vector4d(S[j][0], S[j][1], S[j][2], S[j][3]);
            }
        }
    }
    Timer {
        interval: 400; running: true
        onTriggered: scene.grabToImage(function (r) { console.log("saved", r.saveToFile(win.outFile)); Qt.quit(); })
    }
}
