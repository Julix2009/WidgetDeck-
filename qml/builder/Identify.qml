// "Show monitors": a big number, the name and the resolution on every monitor for a few seconds, so you know which one is which.
// Click-through (empty input region), an overlay layer, one window per monitor only while it is shown.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

Scope {
    id: idf
    required property var mons
    property int secs: 3
    property bool on: false
    function show() { on = true; hide.restart(); }
    Timer { id: hide; interval: Math.max(1, idf.secs) * 1000; onTriggered: idf.on = false }

    Variants {
        model: idf.on ? idf.mons.list : []
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData.screen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "widgetdeck-identify"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region { }
            readonly property int idx: { var l = idf.mons.list; for (var i = 0; i < l.length; i++) if (l[i].key === modelData.key) return i + 1; return 0; }
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.5, 520); height: width * 0.62; radius: 36
                color: "#d9101420"; border.width: 3; border.color: modelData.key === idf.mons.primaryKey ? "#8ab4ff" : "#55ffffff"
                opacity: 0
                NumberAnimation on opacity { to: 1; duration: 180; running: true }
                Column {
                    anchors.centerIn: parent; spacing: 4
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: win.idx; color: "white"; font.pixelSize: parent.parent.height * 0.55; font.bold: true; font.family: Fonts.ui }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; color: "white"; font.pixelSize: parent.parent.height * 0.12; font.bold: true; font.family: Fonts.ui }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; color: "#b8c0d8"; font.pixelSize: parent.parent.height * 0.075; font.family: Fonts.ui
                           text: modelData.w + " × " + modelData.h + (modelData.scale !== 1 ? "  @" + modelData.scale : "") + (modelData.key === idf.mons.primaryKey && idf.mons.multi ? "  ★" : "") }
                }
            }
        }
    }
}
