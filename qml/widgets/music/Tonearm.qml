// Tonearm: the item sits at the pivot (0,0). `angle` is measured from "straight down", clockwise; `lift` (0..1) raises the arm
// (slightly larger, longer soft shadow). Small drawn shapes only - no glass material.
import QtQuick
import QtQuick.Effects

Item {
    id: arm
    property real unit: 100                       // side of the deck square
    property real armLength: unit * 0.62
    property real angle: 0
    property real lift: 0
    property color metal: Qt.rgba(0.86, 0.88, 0.92, 0.92)
    property color accent: "#8ab4ff"
    width: 0; height: 0

    // bearing base (does not rotate)
    Rectangle { x: -width / 2; y: -height / 2; width: arm.unit * 0.12; height: width; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.10); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.30) }

    Item {
        id: bar
        width: 0; height: 0
        rotation: arm.angle
        scale: 1 + 0.07 * arm.lift
        readonly property real tw: Math.max(2, arm.unit * 0.022)
        readonly property real back: arm.unit * 0.11
        RectangularShadow {
            x: tube.x; y: tube.y; width: tube.width; height: tube.height; radius: tube.radius
            blur: 4 + arm.lift * 12; offset: Qt.point(1 + arm.lift * 7, 2 + arm.lift * 11); color: Qt.rgba(0, 0, 0, 0.38)
        }
        Rectangle { id: tube; x: -bar.tw / 2; y: -bar.back; width: bar.tw; height: arm.armLength + bar.back; radius: width / 2; color: arm.metal }
        // counterweight behind the pivot
        Rectangle { x: -arm.unit * 0.04; y: -bar.back - arm.unit * 0.03; width: arm.unit * 0.08; height: arm.unit * 0.085; radius: arm.unit * 0.02; color: Qt.rgba(0.62, 0.65, 0.70, 0.95) }
        // headshell + needle (the needle tip carries the accent colour)
        Item {
            x: 0; y: arm.armLength; width: 0; height: 0
            rotation: 14
            Rectangle { x: -arm.unit * 0.026; y: -arm.unit * 0.012; width: arm.unit * 0.052; height: arm.unit * 0.078; radius: arm.unit * 0.012; color: Qt.rgba(0.72, 0.75, 0.80, 0.98) }
            Rectangle { x: -arm.unit * 0.009; y: arm.unit * 0.062; width: arm.unit * 0.018; height: width; radius: width / 2; color: arm.accent }
        }
    }
}
