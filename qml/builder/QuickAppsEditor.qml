// The apps of a quick apps widget, shown small in the builder's settings panel: icon and name, the x takes one out, "+" opens the same app chooser
// the widget on the desktop uses (widgets/quickapps/AppPicker.qml).
import QtQuick
import Quickshell
import "../core"
import "../widgets/quickapps"
import "../widgets/quickapps/Model.js" as M

Column {
    id: qe
    required property var th
    required property var store
    property string wid: ""                       // "" = no quick apps widget is selected
    spacing: 6

    readonly property var ids: { store.rev; return wid === "" ? [] : QuickAppsService.listOf(wid); }
    readonly property var apps: {
        var found = QuickAppsService.entries;     // re-evaluated when apps are installed or removed
        return ids.map(function (id) { var e = QuickAppsService.entry(id); return { id: id, name: e ? e.name : id, icon: e ? e.icon : "" }; });
    }
    readonly property real cellW: (width - 12) / 3

    Text { text: I18n.tr("Apps") + "  ·  " + I18n.trf("%1 of %2", qe.ids.length, M.MAX); color: qe.th.dim; font.family: qe.th.font; font.pixelSize: 12; font.bold: true }
    Flow {
        width: parent.width; spacing: 6
        Repeater {
            model: qe.apps
            delegate: Rectangle {
                id: cell
                required property var modelData
                width: qe.cellW; height: 62; radius: qe.th.ctlRadius; color: qe.th.well
                AppIcon { anchors.horizontalCenter: parent.horizontalCenter; y: 8; width: 28; height: 28; icon: cell.modelData.icon; name: cell.modelData.name; fg: qe.th.fg }
                Text { x: 4; y: 42; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; textFormat: Text.PlainText; text: cell.modelData.name; color: qe.th.fg; font.family: qe.th.font; font.pixelSize: 11 }
                Rectangle {
                    anchors { right: parent.right; top: parent.top; margins: 3 }
                    width: 17; height: 17; radius: width / 2
                    color: del.containsMouse ? Qt.rgba(1, 0.35, 0.35, 0.45) : qe.th.field
                    Icon { anchors.centerIn: parent; width: 9; height: 9; name: "cancel"; color: qe.th.fg; stroke: 3 }
                    MouseArea { id: del; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: QuickAppsService.remove(qe.wid, cell.modelData.id) }
                }
            }
        }
        Rectangle {
            visible: qe.ids.length < M.MAX
            width: qe.cellW; height: 62; radius: qe.th.ctlRadius
            color: plus.containsMouse ? qe.th.fieldHover : qe.th.field
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 5; text: "+"; color: qe.th.fg; font.family: qe.th.font; font.pixelSize: 24 }
            Text { x: 4; y: 42; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: I18n.tr("Add"); color: qe.th.dim; font.family: qe.th.font; font.pixelSize: 11 }
            MouseArea { id: plus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: QuickAppsService.openPicker(qe.wid, qe.QsWindow.window ? qe.QsWindow.window.screen : null, true) }
        }
    }
}
