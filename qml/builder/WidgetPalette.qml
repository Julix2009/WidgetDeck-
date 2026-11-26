// Left card of the editor: the "+ Widget" button (opens the library) and the layer list.
import QtQuick
import "../core"

Item {
    id: pal
    required property var store
    required property var th
    property string sel: ""
    signal addRequested()
    signal layerPicked(string id)

    GButton { id: addBtn; width: parent.width; implicitHeight: 38; th: pal.th; primary: true; label: I18n.tr("+ Widget"); onClicked: pal.addRequested() }
    Text { id: head; anchors { top: addBtn.bottom; topMargin: 16 } text: I18n.tr("Layers"); color: pal.th.dim; font.family: pal.th.font; font.pixelSize: 12; font.bold: true }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 8; bottom: parent.bottom }
        clip: true; boundsBehavior: Flickable.StopAtBounds; spacing: 2
        // only the widgets of the monitor that is being edited (and those shown on all monitors), top-most first
        model: {
            pal.store.rev; pal.store.mons; pal.store.selMon; pal.store.primaryKey;
            var k = pal.store.curKey();
            return pal.store.widgetIds.filter(function (id) { var c = pal.store.cfg(id); return c !== null && (c.monitor === "all" || pal.store.homeKey(c) === k); }).reverse();
        }
        delegate: Rectangle {
            id: row
            required property string modelData
            readonly property var c: { pal.store.geomRev; return pal.store.cfg(modelData); }
            readonly property var ti: c ? pal.store.typeInfo(c.type) : null
            readonly property bool on: pal.sel === modelData
            readonly property string where: {
                if (!pal.store.multi || !c) return "";
                pal.store.mons;
                if (c.monitor === "all") return I18n.tr("All monitors");
                var k = pal.store.homeKey(c), r = pal.store.monRec(k);
                return r ? r.name : pal.store.monitorLabel(k);
            }
            width: list.width; height: pal.store.multi ? 44 : 34; radius: pal.th.ctlRadius
            color: on ? pal.th.selected : (ma.containsMouse ? pal.th.fieldHover : "transparent")
            opacity: c && c.hidden ? 0.5 : 1
            TypeGlyph { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; size: 16; ti: row.ti; color: row.on ? pal.th.accent : pal.th.fg }
            Column {
                x: 38; width: parent.width - 46; anchors.verticalCenter: parent.verticalCenter
                Text { width: parent.width; elide: Text.ElideRight; text: row.ti ? I18n.tr(row.ti.label) : row.modelData; color: pal.th.fg; font.family: pal.th.font; font.pixelSize: 13 }
                Text { visible: row.where !== ""; width: parent.width; elide: Text.ElideRight; text: row.where; color: pal.th.dim; font.family: pal.th.font; font.pixelSize: 10 }
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pal.layerPicked(row.modelData) }
        }
    }
}
