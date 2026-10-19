// The record: vinyl with fine grooves (drawn ONCE into a 512 px canvas texture), a round label with the album cover and the spindle hole.
// This whole item is the thing that spins (RotationAnimator in TurntableView, render thread); the glass below and the text never re-render for it.
import QtQuick
import "../../core"

Item {
    id: disc
    property color vinyl: "#0e0e10"
    property color accent: "#8ab4ff"
    property string cover: ""
    property bool started: false
    property int dur: 440
    readonly property string shownUrl: lab.shownUrl
    readonly property real labelSize: width * 0.40

    Rectangle {
        anchors.fill: parent; radius: width / 2; color: disc.vinyl
        Behavior on color { ColorAnimation { duration: 450 } }
    }
    // grooves + rim: painted once (fixed 512 px canvas, scaled by the item size - resizing never repaints)
    Canvas {
        id: grooves
        width: 512; height: 512
        transformOrigin: Item.TopLeft
        scale: disc.width / 512
        renderTarget: Canvas.Image
        onPaint: {
            var c = getContext("2d"), R = 256;
            c.reset();
            c.lineWidth = 1;
            for (var i = 0, r = R * 0.43; r < R * 0.965; i++, r += 2.1) {                  // ~125 fine grooves with a slightly irregular brightness
                var a = 0.030 + 0.045 * (((i * 37) % 11) / 11) + ((i % 23 === 0) ? 0.05 : 0);
                c.strokeStyle = "rgba(255,255,255," + a.toFixed(3) + ")";
                c.beginPath(); c.arc(R, R, r, 0, Math.PI * 2); c.stroke();
            }
            c.lineWidth = 3;                                                                // gaps between tracks
            var gaps = [0.58, 0.71, 0.83];
            for (var g = 0; g < gaps.length; g++) { c.strokeStyle = "rgba(0,0,0,0.55)"; c.beginPath(); c.arc(R, R, R * gaps[g], 0, Math.PI * 2); c.stroke(); }
            c.lineWidth = 2;                                                                // smooth lead-in and run-out rim
            c.strokeStyle = "rgba(255,255,255,0.16)"; c.beginPath(); c.arc(R, R, R * 0.985, 0, Math.PI * 2); c.stroke();
            c.strokeStyle = "rgba(255,255,255,0.10)"; c.beginPath(); c.arc(R, R, R * 0.415, 0, Math.PI * 2); c.stroke();
        }
        Component.onCompleted: requestPaint()
    }
    // label with the cover (round); a new cover blends in through the shared cover stack (never an empty frame)
    CoverStack {
        id: lab
        anchors.centerIn: parent
        width: disc.labelSize; height: width; radius: width / 2
        accent: disc.accent
        source: disc.cover; sourceKnown: true; started: disc.started
        animate: true; animStyle: "crossfade"; dur: disc.dur; zoom: 0
        playing: true; shadowOn: false
    }
    Icon { visible: disc.cover === ""; anchors.centerIn: parent; width: disc.labelSize * 0.55; height: width; name: "music"; color: Qt.rgba(1, 1, 1, 0.9); stroke: 2.2 }
    Rectangle { anchors.centerIn: parent; width: disc.labelSize; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14) }
    // spindle hole
    Rectangle { anchors.centerIn: parent; width: disc.width * 0.04; height: width; radius: width / 2; color: "#16161a"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.35) }
}
