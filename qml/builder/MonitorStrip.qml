// The monitor selector of the builder header (only shown with more than one monitor): a small map of the arrangement (click a rectangle),
// one card per monitor (name, resolution) and the "Show monitors" button.
import QtQuick
import "../core"

Item {
    id: ms
    required property var store
    required property var th
    required property var mons
    signal identify()

    readonly property var list: { store.mons; return store.mons; }
    readonly property rect bounds: {
        var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (var i = 0; i < list.length; i++) { x0 = Math.min(x0, list[i].x); y0 = Math.min(y0, list[i].y); x1 = Math.max(x1, list[i].x + list[i].w); y1 = Math.max(y1, list[i].y + list[i].h); }
        return list.length ? Qt.rect(x0, y0, x1 - x0, y1 - y0) : Qt.rect(0, 0, 1, 1);
    }
    readonly property real mapW: 124
    readonly property real k: Math.min(mapW / bounds.width, 34 / bounds.height)

    // map
    Item {
        id: map
        x: 0; anchors.verticalCenter: parent.verticalCenter; width: ms.mapW; height: 36
        Repeater {
            model: ms.list
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool on: modelData.key === ms.store.curKey()
                x: (modelData.x - ms.bounds.x) * ms.k; y: (modelData.y - ms.bounds.y) * ms.k
                width: Math.max(10, modelData.w * ms.k - 2); height: Math.max(8, modelData.h * ms.k - 2); radius: 3
                color: on ? Qt.rgba(Qt.color(ms.th.accent).r, Qt.color(ms.th.accent).g, Qt.color(ms.th.accent).b, 0.45) : ms.th.field
                border.width: 1; border.color: on ? ms.th.accent : ms.th.line
                Text { anchors.centerIn: parent; text: index + 1; color: ms.th.fg; font.family: ms.th.font; font.pixelSize: 11; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ms.store.selMon = modelData.key }
            }
        }
    }
    // cards
    Row {
        x: ms.mapW + 14; anchors.verticalCenter: parent.verticalCenter; spacing: 6
        Repeater {
            model: ms.list
            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property bool on: modelData.key === ms.store.curKey()
                width: Math.max(120, lab.implicitWidth + 22); height: 36; radius: ms.th.ctlRadius
                color: on ? Qt.rgba(Qt.color(ms.th.accent).r, Qt.color(ms.th.accent).g, Qt.color(ms.th.accent).b, 0.32) : (cma.containsMouse ? ms.th.fieldHover : ms.th.field)
                border.width: 1; border.color: on ? ms.th.accent : ms.th.line
                Column {
                    id: lab
                    anchors.centerIn: parent; spacing: 0
                    Text { anchors.horizontalCenter: parent.horizontalCenter; color: ms.th.fg; font.family: ms.th.font; font.pixelSize: 12; font.bold: true
                           text: (card.index + 1) + "  " + modelData.name + (modelData.key === ms.mons.primaryKey ? "  ★" : "") }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; color: ms.th.dim; font.family: ms.th.font; font.pixelSize: 10
                           text: modelData.w + "×" + modelData.h + (modelData.scale !== 1 ? "  @" + modelData.scale : "") + (modelData.vertical ? "  ↻" : "") }
                }
                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ms.store.selMon = modelData.key }
            }
        }
        GButton { th: ms.th; label: I18n.tr("Show monitors"); anchors.verticalCenter: parent.verticalCenter; onClicked: ms.identify() }
    }
}
