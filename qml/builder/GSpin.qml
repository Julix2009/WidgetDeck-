import QtQuick

Item {
    id: s
    required property var th
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    signal moved(real v)
    implicitHeight: 52
    function commit(v) { v = Math.max(from, Math.min(to, Math.round(v / step) * step)); if (v !== value) moved(v); }
    Text { text: s.label; color: s.th.dim; font.family: s.th.font; font.pixelSize: 12 }
    Rectangle {
        y: 18; width: parent.width; height: 30; radius: s.th.ctlRadius; color: s.th.field; border.width: 1
        border.color: input.activeFocus ? s.th.accent : s.th.line
        TextInput {
            id: input
            anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: minus.left; anchors.verticalCenter: parent.verticalCenter
            text: String(s.value)
            color: s.th.fg; font.family: s.th.font; font.pixelSize: 13
            selectByMouse: true
            validator: DoubleValidator { }
            onEditingFinished: s.commit(parseFloat(text))
            onActiveFocusChanged: if (!activeFocus) text = String(s.value)
        }
        Rectangle { id: minus; anchors.right: plus.left; width: 26; height: parent.height; color: "transparent"
            Rectangle { anchors.centerIn: parent; width: 10; height: 2; radius: 1; color: mm.containsMouse ? s.th.accent : s.th.fg }
            MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; onClicked: s.commit(s.value - s.step) } }
        Rectangle { id: plus; anchors.right: parent.right; width: 26; height: parent.height; color: "transparent"
            Rectangle { anchors.centerIn: parent; width: 10; height: 2; radius: 1; color: pm.containsMouse ? s.th.accent : s.th.fg }
            Rectangle { anchors.centerIn: parent; width: 2; height: 10; radius: 1; color: pm.containsMouse ? s.th.accent : s.th.fg }
            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: s.commit(s.value + s.step) } }
    }
    onValueChanged: if (!input.activeFocus) input.text = String(value)
}
