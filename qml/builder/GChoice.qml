// Segmented control for <= 3 options, popup list otherwise.
import QtQuick

Item {
    id: s
    required property var th
    property string label: ""
    property var options: []            // [[value, text], ...]
    property string value: ""
    signal picked(string v)
    readonly property bool segmented: options.length <= 3
    implicitHeight: 52
    Text { text: s.label; color: s.th.dim; font.family: s.th.font; font.pixelSize: 12 }
    Row {
        y: 18; width: parent.width; spacing: 6
        visible: s.segmented
        Repeater {
            model: s.options
            delegate: GButton {
                required property var modelData
                th: s.th; label: modelData[1]; checked: s.value === modelData[0]
                width: (s.width - (s.options.length - 1) * 6) / s.options.length
                onClicked: s.picked(modelData[0])
            }
        }
    }
    GButton {
        y: 18; width: parent.width; visible: !s.segmented
        th: s.th
        label: { for (var i = 0; i < s.options.length; i++) if (s.options[i][0] === s.value) return s.options[i][1]; return s.value; }
        onClicked: s.th.pickList(this, s.options, s.value, function (v) { s.picked(v); })
    }
}
