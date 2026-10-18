import QtQuick

Item {
    id: s
    required property var th
    property string label: ""
    property string value: ""
    signal edited(string v)           // every keystroke
    signal committed(string v)        // Enter / focus lost: use this for values that must be complete (numbers)
    implicitHeight: 52
    Text { text: s.label; color: s.th.dim; font.family: s.th.font; font.pixelSize: 12; visible: s.label !== "" }
    Rectangle {
        y: s.label !== "" ? 18 : 0; width: parent.width; height: 30; radius: s.th.ctlRadius; color: s.th.field; border.width: 1
        border.color: input.activeFocus ? s.th.accent : s.th.line
        TextInput {
            id: input
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; verticalAlignment: TextInput.AlignVCenter
            text: s.value
            color: s.th.fg; font.family: s.th.font; font.pixelSize: 13
            selectByMouse: true; clip: true
            onTextEdited: s.edited(text)
            onEditingFinished: s.committed(text)
        }
    }
    onValueChanged: if (!input.activeFocus) input.text = value
}
