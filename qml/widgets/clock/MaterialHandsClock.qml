// Two short, thick hands; the seconds are a dot that travels around them.
import QtQuick
import "../../core"

Item {
    id: a
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property color cAcc: w.tstyle.accent || "#8ab4ff"
    readonly property color cHour: w.palette.tertiary || "#d6bee4"
    readonly property real r: Math.min(width, height) / 2
    readonly property real sec: (w.now.getSeconds() * 6 - 90) * Math.PI / 180

    component Hand: Rectangle {
        id: hand
        property real len: 0.5
        property real angle: 0
        width: a.r * 0.16; height: a.r * len + width / 2; radius: width / 2
        x: a.width / 2 - width / 2; y: a.height / 2 - height + width / 2
        antialiasing: true
        transform: Rotation { origin.x: hand.width / 2; origin.y: hand.height - hand.width / 2; angle: hand.angle }
    }
    Hand { angle: (a.w.now.getHours() % 12 + a.w.now.getMinutes() / 60) * 30; len: 0.36; color: a.cHour }
    Hand { angle: (a.w.now.getMinutes() + a.w.now.getSeconds() / 60) * 6; len: 0.52; color: a.cAcc }
    Rectangle {
        visible: a.w.props.show_seconds !== false
        width: a.r * 0.14; height: width; radius: width / 2; color: a.cFg
        x: a.width / 2 + Math.cos(a.sec) * a.r * 0.82 - width / 2
        y: a.height / 2 + Math.sin(a.sec) * a.r * 0.82 - height / 2
    }
}
