// One weather icon: baked sprite layers (icons/*.png, made by tools/weather-icons/render.sh) with a soft shadow, a gentle idle motion and a hover tilt.
// Layers move by position, rotation and opacity only. Nothing here touches the glass. `t` is a clock in seconds that the card advances while it
// is visible and animations are on; a frozen `t` (or level 0) means the icon stands still and costs nothing.
import QtQuick
import "Model.js" as M

Item {
    id: ic
    property string kind: "unknown"
    property bool day: true
    property real t: 0
    property int level: 0                       // 0 = still, 1 = subtle, 2 = full
    property real tilt: 0                       // hover direction, -1 (left) .. 1 (right)
    property real tiltY: 0
    property bool shadowOn: true
    readonly property var layers: M.layersFor(kind, day)
    readonly property real amp: Math.max(0.4, width / 96)
    readonly property real gain: level >= 2 ? 1.8 : 1
    readonly property bool moving: level > 0
    property real stx: tilt
    property real sty: tiltY
    Behavior on stx { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
    Behavior on sty { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

    // soft contact shadow below the object (follows the tilt in the opposite direction)
    Image {
        visible: ic.shadowOn
        source: "icons/shadow.png"
        smooth: true; mipmap: true
        width: ic.width * 0.7; height: width / 3
        x: (ic.width - width) / 2 - ic.stx * 3 * ic.amp
        y: ic.height * 0.93 - height / 2 + ic.sty * 1.5 * ic.amp
        opacity: ic.moving ? 0.8 + 0.12 * Math.sin(ic.t * 1.37) * (ic.gain > 1 ? 1.3 : 1) : 0.85
    }
    Item {
        id: body
        width: ic.width; height: ic.height
        y: ic.moving ? Math.sin(ic.t * 1.35) * 2.6 * ic.amp * ic.gain : 0         // the whole icon floats a little
        Repeater {
            model: ic.layers
            delegate: Item {
                id: lay
                required property var modelData
                readonly property real w0: modelData.w * ic.width
                readonly property real ph: modelData.p * 1.9
                readonly property string m: ic.moving ? modelData.m : "none"
                readonly property real fall: (ic.t * 0.5 + modelData.p * 0.29) % 1          // 0..1 position in the falling loop
                width: w0; height: w0
                x: modelData.x * ic.width - w0 / 2 + ic.stx * modelData.d * 5 * ic.amp + (m === "drift" ? Math.sin(ic.t * 0.8 + ph) * 2.4 * ic.amp * ic.gain : 0)
                y: modelData.y * ic.height - w0 / 2 + ic.sty * modelData.d * 3 * ic.amp + (m === "fall" ? lay.fall * 0.1 * ic.height * ic.gain : 0)
                rotation: ic.stx * modelData.d * 2.6 + (m === "spin" ? (ic.t * (ic.gain > 1 ? 22 : 9) + ph * 40) % 360 : 0)
                scale: m === "breathe" ? 1 + 0.035 * ic.gain * Math.sin(ic.t * 1.3) : 1
                opacity: m === "fall" ? Math.pow(Math.sin(Math.PI * lay.fall), 0.5)
                       : (m === "twinkle" ? 0.62 + 0.38 * Math.sin(ic.t * 2.1 + ph * 2) : (m === "flicker" && ic.level >= 2 ? (((ic.t * 0.42 + ph) % 1) > 0.9 ? 0.45 : 1) : 1))
                Image { anchors.fill: parent; source: "icons/" + modelData.s + ".png"; smooth: true; mipmap: true }
            }
        }
    }
}
