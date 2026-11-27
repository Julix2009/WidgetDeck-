// The app chooser of the quick apps widgets: a window above everything with a search field and the installed apps. A click adds an app (opened
// from the builder it also takes a chosen one out again), Enter adds the first match, Esc or a click beside the card closes. It stays open until
// then, so several can be chosen at once.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../builder"
import "Model.js" as M

PanelWindow {
    id: pw
    required property var theme                   // ThemeStore
    readonly property var svc: QuickAppsService
    readonly property string wid: svc.pickerFor
    readonly property var chosen: { if (!svc.store) return []; svc.store.rev; return svc.listOf(wid); }
    readonly property var found: M.filter(svc.entries, search.text)
    function pick(id) { if (chosen.indexOf(id) < 0) svc.add(wid, id); else if (svc.pickerRemoves) svc.remove(wid, id); }

    screen: svc.pickerScreen
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "#73000000"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "widgetdeck-picker"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Theme { id: th; themeStore: pw.theme }
    MouseArea { anchors.fill: parent; onClicked: pw.svc.closePicker() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 40); height: Math.min(520, parent.height - 40)
        radius: th.cardRadius; color: th.popup
        border.width: 1; border.color: th.line
        MouseArea { anchors.fill: parent }        // a click on the card does not close
        Item {
            id: body
            anchors { fill: parent; margins: 16 }
            Text { id: title; text: I18n.tr("Add apps"); color: th.fg; font.family: th.font; font.pixelSize: 17; font.bold: true }
            Text { anchors { right: parent.right; verticalCenter: title.verticalCenter } text: I18n.trf("%1 of %2", pw.chosen.length, M.MAX); color: th.dim; font.family: th.font; font.pixelSize: 13 }
            Rectangle {
                id: box
                anchors { left: parent.left; right: parent.right; top: title.bottom; topMargin: 12 }
                height: 36; radius: th.ctlRadius; color: th.field
                TextInput {
                    id: search
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: th.fg; selectionColor: th.accent; font.family: th.font; font.pixelSize: 14; clip: true
                    focus: true
                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: list.positionViewAtBeginning()
                    onAccepted: if (text !== "" && pw.found.length > 0) { pw.svc.add(pw.wid, pw.found[0].id); text = ""; }
                    Keys.onEscapePressed: pw.svc.closePicker()
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: search.text === ""; text: I18n.tr("Search …"); color: th.dim; font: search.font }
                }
            }
            ListView {
                id: list
                anchors { left: parent.left; right: parent.right; top: box.bottom; topMargin: 10; bottom: done.top; bottomMargin: 10 }
                clip: true; boundsBehavior: Flickable.StopAtBounds
                model: pw.found
                property real keepY: 0
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool on: pw.chosen.indexOf(modelData.id) >= 0
                    readonly property bool full: !on && pw.chosen.length >= M.MAX
                    width: list.width; height: 42; radius: th.ctlRadius
                    color: on ? th.selected : (rowArea.containsMouse && !full ? th.field : "transparent")
                    opacity: full ? 0.4 : 1
                    AppIcon { id: ico; x: 8; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; icon: row.modelData.icon; name: row.modelData.name; fg: th.fg }
                    Text { anchors { left: ico.right; leftMargin: 10; right: tick.left; rightMargin: 8; verticalCenter: parent.verticalCenter } elide: Text.ElideRight; textFormat: Text.PlainText; text: row.modelData.name; color: th.fg; font.family: th.font; font.pixelSize: 14 }
                    Icon { id: tick; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } width: 16; height: 16; name: "check"; color: th.accent; stroke: 2.6; visible: row.on }
                    MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; enabled: !row.full && (!row.on || pw.svc.pickerRemoves); cursorShape: Qt.PointingHandCursor
                        onClicked: { list.keepY = list.contentY; pw.pick(row.modelData.id); } }
                }
            }
            Text { anchors.centerIn: list; visible: pw.found.length === 0; text: I18n.tr("No app found"); color: th.dim; font.family: th.font; font.pixelSize: 13 }
            GButton { id: done; anchors { right: parent.right; bottom: parent.bottom } th: th; primary: true; label: I18n.tr("Done"); onClicked: pw.svc.closePicker() }
        }
    }
}
