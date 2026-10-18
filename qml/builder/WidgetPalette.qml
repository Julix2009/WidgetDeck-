// Left panel: widget types (click = add, drag = drop on the canvas) and the layer list.
import QtQuick
import "../core"

Item {
    id: pal
    required property var store
    required property var th
    property string sel: ""
    signal addRequested(string type)
    signal dragMoved(string type, real gx, real gy)     // global (root) coordinates
    signal dragEnded(string type, real gx, real gy, bool moved)
    signal layerPicked(string id)

    readonly property var typeKeys: { store.rev; return Object.keys(store.allTypes); }

    Column {
        anchors.fill: parent
        spacing: 8
        Text { text: "WIDGETS"; color: th.dim; font.family: th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2 }
        Text { text: I18n.tr("Click, or drag onto the stage"); color: th.dim; opacity: 0.8; font.family: th.font; font.pixelSize: 12 }
        Repeater {
            model: pal.typeKeys
            delegate: Rectangle {
                id: card
                required property string modelData
                readonly property var ti: pal.store.typeInfo(modelData)
                width: pal.width; height: 56
                radius: th.liquid ? 22 : 12
                color: ma.containsMouse ? Qt.rgba(Qt.color(th.accent).r, Qt.color(th.accent).g, Qt.color(th.accent).b, 0.22) : th.field
                border.width: 1; border.color: ma.containsMouse ? th.accent : th.line
                Behavior on color { ColorAnimation { duration: 180 } }
                // springy slide on hover
                transform: Translate { x: ma.containsMouse ? 4 : 0; Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.4 } } }
                TypeGlyph { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 24; ti: card.ti; color: th.fg; size: 22 }
                Column {
                    x: 54; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 66
                    Text { text: card.ti ? card.ti.label : modelData; color: th.fg; font.family: th.font; font.pixelSize: 14; font.bold: true }
                    Text { text: card.ti ? card.ti.desc : ""; color: th.dim; font.family: th.font; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    property bool moved: false
                    onPressed: moved = false
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        var g = mapToItem(null, mouse.x, mouse.y);
                        if (Math.abs(mouse.x - width / 2) > 6 || Math.abs(mouse.y - height / 2) > 6) moved = true;
                        if (moved) pal.dragMoved(modelData, g.x, g.y);
                    }
                    onReleased: mouse => { var g = mapToItem(null, mouse.x, mouse.y); if (moved) pal.dragEnded(modelData, g.x, g.y, true); else pal.addRequested(modelData); }
                }
            }
        }
        Item { width: 1; height: 6 }
        Text { text: I18n.tr("ON THE DESKTOP"); color: th.dim; font.family: th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2 }
        ListView {
            width: pal.width; height: pal.height - y
            clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
            model: { pal.store.rev; return pal.store.widgetIds.slice().reverse(); }
            delegate: Rectangle {
                id: row
                required property string modelData
                readonly property var c: { pal.store.geomRev; return pal.store.cfg(modelData); }
                readonly property var ti: c ? pal.store.typeInfo(c.type) : null
                width: ListView.view.width; height: 38
                radius: th.liquid ? 19 : 10
                readonly property bool on: pal.sel === modelData
                color: on ? Qt.rgba(Qt.color(th.accent).r, Qt.color(th.accent).g, Qt.color(th.accent).b, 0.28) : (lma.containsMouse ? th.fieldHover : th.field)
                border.width: 1; border.color: on ? th.accent : th.line
                Behavior on color { ColorAnimation { duration: 160 } }
                TypeGlyph { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; ti: row.ti; color: th.fg; size: 16 }
                Text { x: 40; anchors.verticalCenter: parent.verticalCenter; color: th.fg; font.family: th.font; font.pixelSize: 13
                    text: (row.ti ? I18n.tr(row.ti.label) : modelData) + (row.c ? "   ·  " + row.c.x + "," + row.c.y : "") }
                MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pal.layerPicked(modelData) }
            }
        }
    }
}
