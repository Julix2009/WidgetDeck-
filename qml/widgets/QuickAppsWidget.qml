// Quick apps: up to six programs, one click starts one. "+" (while the pointer is over the widget, or the big tile of an empty one) opens the app
// chooser; the widget takes the size that fits its apps. On the desktop apps are only added, never removed (no accidents): removing is done in the
// builder (builder/QuickAppsEditor.qml). Logic: quickapps/Model.js and QuickAppsService.qml.
import QtQuick
import Quickshell
import "../core"
import "quickapps"
import "quickapps/Model.js" as M
import "music"

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})
    property string widgetId: ""                  // set by WidgetHost

    readonly property var svc: QuickAppsService
    readonly property bool demo: props.demo === true          // the library preview: invented apps
    readonly property real fs: style.font_size || 16
    function s(v) { return v * fs / 16; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: palette.primary || style.accent || "#8ab4ff"
    function faded(a) { return Qt.rgba(cFg.r, cFg.g, cFg.b, a); }

    readonly property var apps: {
        if (demo) return [["Browser", "wifi"], ["Files", "folder"], ["Editor", "pencil"], ["Music", "music"], ["Monitor", "cpu"], ["Notes", "note"]].map(function (d) {
            return { id: d[0], name: d[0], icon: "", line: d[1] }; });
        var found = svc.entries;                  // re-evaluated when apps are installed or removed
        return M.clean(props.apps).map(function (id) { var e = svc.entry(id); return { id: id, name: e ? e.name : id, icon: e ? e.icon : "", line: "" }; });
    }
    readonly property int count: apps.length
    function choose() { if (!demo && widgetId !== "") svc.openPicker(widgetId, w.QsWindow.window ? w.QsWindow.window.screen : null); }

    HoverHandler { id: hov }

    Item {
        id: head
        width: parent.width; height: w.s(22)
        Row {
            height: parent.height; spacing: w.s(7)
            Icon { anchors.verticalCenter: parent.verticalCenter; width: w.s(15); height: width; name: "grid"; color: w.cAcc; stroke: 2.2 }
            GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.letterSpacing: 1.4; font.pixelSize: w.s(11); opacity: 0.9; text: I18n.tr("Quick apps").toUpperCase() }
        }
        MButton {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: hov.hovered && !w.demo && w.count > 0 && w.count < M.MAX
            width: w.s(22); height: width; animate: false; hoverColor: w.cAcc
            onClicked: w.choose()
            Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: "+"; color: w.cFg; font.pixelSize: w.s(17) }
        }
    }

    Item {
        id: area
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: w.s(8); bottom: parent.bottom }
        readonly property int cols: M.columns(w.count)
        readonly property int lines: M.rows(w.count)
        readonly property real gap: w.s(6)
        readonly property real cellW: (width - (cols - 1) * gap) / cols
        readonly property real cellH: (height - (lines - 1) * gap) / lines
        Repeater {
            model: w.apps
            delegate: Rectangle {
                id: tile
                required property var modelData
                required property int index
                x: (index % area.cols) * (area.cellW + area.gap); y: Math.floor(index / area.cols) * (area.cellH + area.gap)
                width: area.cellW; height: area.cellH
                radius: Math.max(w.innerRadius, w.s(12))
                color: w.faded(tileHover.hovered ? 0.14 : 0.06)
                Behavior on color { ColorAnimation { duration: 140 } }
                HoverHandler { id: tileHover }
                MouseArea { id: press; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!w.demo) w.svc.launch(tile.modelData.id) }
                readonly property real iconSize: Math.max(8, Math.min(width * 0.5, height - w.s(30)))
                Item {
                    id: pic
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (parent.height - height - name.height - w.s(5)) / 2
                    width: tile.iconSize; height: width
                    scale: press.pressed ? 0.88 : 1
                    Behavior on scale { NumberAnimation { duration: 110 } }
                    AppIcon { anchors.fill: parent; visible: tile.modelData.line === ""; icon: tile.modelData.icon; name: tile.modelData.name; fg: w.cFg }
                    Icon { anchors.fill: parent; visible: tile.modelData.line !== ""; name: tile.modelData.line; color: w.cAcc; stroke: 1.8 }
                }
                GText {
                    id: name
                    anchors { top: pic.bottom; topMargin: w.s(5); left: parent.left; right: parent.right; leftMargin: w.s(4); rightMargin: w.s(4) }
                    horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    wstyle: w.style; font.pixelSize: w.s(11); opacity: 0.85
                    textFormat: Text.PlainText
                    text: tile.modelData.name
                }
            }
        }
        // nothing chosen yet: one big tile
        Rectangle {
            anchors.fill: parent
            visible: w.count === 0
            radius: Math.max(w.innerRadius, w.s(12))
            color: w.faded(emptyArea.containsMouse ? 0.14 : 0.06)
            MouseArea { id: emptyArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.choose() }
            GText { anchors.centerIn: parent; width: parent.width - w.s(12); horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; wstyle: w.style; font.pixelSize: w.s(13); opacity: 0.8; text: "+ " + I18n.tr("Add apps") }
        }
    }
}
