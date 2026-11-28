// Only the hands: no dial, no numbers. The second hand in the accent colour.
import QtQuick
import "../../core"

Item {
    id: a
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property color cAcc: w.tstyle.accent || "#8ab4ff"
    readonly property real r: Math.min(width, height) / 2

    component Hand: Rectangle {
        id: hand
        property real len: 0.5
        property real thick: 0.1
        property real angle: 0
        width: Math.max(1.5, a.r * thick); height: a.r * len + width / 2; radius: width / 2
        x: a.width / 2 - width / 2; y: a.height / 2 - height + width / 2
        antialiasing: true
        transform: Rotation { origin.x: hand.width / 2; origin.y: hand.height - hand.width / 2; angle: hand.angle }
    }
    Hand { angle: (a.w.now.getHours() % 12 + a.w.now.getMinutes() / 60) * 30; len: 0.46; thick: 0.11; color: a.cFg }
    Hand { angle: (a.w.now.getMinutes() + a.w.now.getSeconds() / 60) * 6; len: 0.66; thick: 0.09; color: Qt.alpha(a.cFg, 0.75) }
    Hand { visible: a.w.props.show_seconds !== false; angle: a.w.now.getSeconds() * 6; len: 0.82; thick: 0.032; color: a.cAcc }
    Rectangle { anchors.centerIn: parent; width: a.r * 0.15; height: width; radius: width / 2; color: a.cAcc }
}
