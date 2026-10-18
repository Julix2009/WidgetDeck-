// Round control button with a springy press (squish and bounce back).
import QtQuick

Rectangle {
    id: b
    property color hoverColor: "#8ab4ff"
    property color baseColor: Qt.rgba(1, 1, 1, 0.09)
    property bool strong: false
    property bool animate: true
    signal clicked()
    default property alias content: slot.data
    readonly property bool down: ma.pressed
    radius: height / 2
    color: ma.containsMouse ? Qt.rgba(hoverColor.r, hoverColor.g, hoverColor.b, 0.45) : (strong ? Qt.rgba(hoverColor.r, hoverColor.g, hoverColor.b, 0.25) : baseColor)
    Behavior on color { ColorAnimation { duration: 160 } }
    scale: down ? 0.84 : 1.0
    Behavior on scale { enabled: b.animate; SpringAnimation { spring: 6; damping: 0.2; epsilon: 0.002 } }
    Item { id: slot; anchors.fill: parent }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: b.clicked() }
}
