import QtQuick

Item {
    id: s
    required property var th
    property string label: ""
    property string value: "#ffffff"
    signal picked(string v)
    implicitHeight: 52
    Text { text: s.label; color: s.th.dim; font.family: s.th.font; font.pixelSize: 12 }
    Rectangle {
        id: sw
        y: 18; width: parent.width; height: 30; radius: s.th.ctlRadius; color: s.value
        border.width: 1; border.color: s.th.line
        Text { anchors.centerIn: parent; text: s.value; font.family: s.th.font; font.pixelSize: 12
            color: Qt.color(s.value).hslLightness > 0.55 ? "#101216" : "#f2f4f8" }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: s.th.pickColor(sw, s.value, function (h) { s.picked(h); }) }
    }
}
