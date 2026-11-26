// Ctrl+K: type to filter, Up / Down to choose, Enter to run.
import QtQuick
import "../core"

Rectangle {
    id: cp
    required property var th
    property var commands: []            // [{ name, run: function }]
    property int current: 0
    readonly property var shown: {
        var q = input.text.toLowerCase();
        return commands.filter(function (c) { return q === "" || c.name.toLowerCase().indexOf(q) >= 0; });
    }
    onShownChanged: current = 0
    function open() { input.text = ""; current = 0; visible = true; input.forceActiveFocus(); }
    function close() { visible = false; input.focus = false; }
    function run(i) { var c = shown[i]; if (!c) return; close(); c.run(); }

    visible: false
    color: Qt.rgba(0, 0, 0, 0.55)
    MouseArea { anchors.fill: parent; onClicked: cp.close(); onWheel: wheel => wheel.accepted = true }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 120; width: 520; height: Math.min(cp.height - 180, 56 + view.contentHeight + 12)
        radius: 14; color: cp.th.popup; border.width: 1; border.color: cp.th.line
        MouseArea { anchors.fill: parent }
        TextInput {
            id: input
            x: 18; y: 16; width: parent.width - 36
            color: cp.th.fg; font.family: cp.th.font; font.pixelSize: 15; clip: true
            Keys.onEscapePressed: cp.close()
            Keys.onDownPressed: { cp.current = Math.min(cp.shown.length - 1, cp.current + 1); view.positionViewAtIndex(cp.current, ListView.Contain); }
            Keys.onUpPressed: { cp.current = Math.max(0, cp.current - 1); view.positionViewAtIndex(cp.current, ListView.Contain); }
            Keys.onReturnPressed: cp.run(cp.current)
            Keys.onEnterPressed: cp.run(cp.current)
            Text { visible: input.text === ""; text: I18n.tr("Search or command…"); color: cp.th.dim; font: input.font }
        }
        ListView {
            id: view
            x: 8; y: 50; width: parent.width - 16; height: parent.height - 58
            clip: true; boundsBehavior: Flickable.StopAtBounds
            model: cp.shown
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: view.width; height: 36; radius: cp.th.ctlRadius
                color: index === cp.current ? cp.th.selected : "transparent"
                Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: cp.th.fg; font.family: cp.th.font; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: cp.current = index; onClicked: cp.run(index) }
            }
        }
    }
}
