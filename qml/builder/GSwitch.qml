import QtQuick

Item {
    id: s
    required property var th
    property string label: ""
    property bool checked: false
    signal toggled(bool v)
    implicitHeight: 30
    Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 52; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; text: s.label; color: s.th.fg; font.family: s.th.font; font.pixelSize: 13 }
    Rectangle {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: 42; height: 24; radius: 12
        color: s.checked ? s.th.accent : s.th.fieldHover
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            y: 2; width: 20; height: 20; radius: 10; color: "white"
            x: s.checked ? parent.width - width - 2 : 2
            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: s.toggled(!s.checked) }
}
