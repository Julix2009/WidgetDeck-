import QtQuick

Rectangle {
    id: b
    required property var th
    property string label: ""
    property bool primary: false
    property bool danger: false
    property bool checked: false
    property int pad: 14
    signal clicked()
    implicitHeight: 32
    implicitWidth: lab.implicitWidth + 2 * pad
    radius: th.ctlRadius
    color: primary ? Qt.rgba(Qt.color(th.accent).r, Qt.color(th.accent).g, Qt.color(th.accent).b, ma.containsMouse ? 1 : 0.85)
         : checked ? Qt.rgba(Qt.color(th.accent).r, Qt.color(th.accent).g, Qt.color(th.accent).b, 0.35)
         : danger && ma.containsMouse ? Qt.rgba(1, 0.35, 0.35, 0.3)
         : ma.containsMouse ? th.fieldHover : th.field
    border.width: 1
    border.color: checked ? th.accent : (danger && ma.containsMouse ? Qt.rgba(1, 0.45, 0.45, 0.8) : th.line)
    scale: ma.pressed ? 0.96 : 1
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    Text {
        id: lab
        anchors.centerIn: parent
        text: b.label
        color: b.primary ? "#0b0c10" : b.th.fg
        font.family: b.th.font; font.pixelSize: 13; font.bold: b.primary
    }
    default property alias extra: slot.data
    Item { id: slot; anchors.fill: parent }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
