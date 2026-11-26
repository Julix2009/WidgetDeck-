// The drivers' standings as a timing tower, like on television.
import QtQuick
import "../../core"

Item {
    id: s
    required property var host
    readonly property var list: (host.fd && host.fd.standings) ? host.fd.standings : []
    readonly property int rows: Math.max(3, Math.min(list.length, Math.floor((height - head.height) / (rowH + 2)), Number(host.props.standings || 10) > 3 ? Number(host.props.standings) : 10))
    readonly property real rowH: Math.max(18, Math.min(34, width * 0.12))
    readonly property real w0: Math.min(width, rowH * 11)

    Column {
        id: col
        anchors.centerIn: parent
        width: s.w0
        spacing: 2
        Rectangle {
            id: head
            width: parent.width; height: s.rowH * 1.15; radius: 6; color: "#d6251f"
            Text { anchors.centerIn: parent; text: I18n.tr("Driver standings").toUpperCase(); color: "#ffffff"; font.family: Fonts.resolve(s.host.style.font); font.bold: true; font.pixelSize: s.rowH * 0.5; font.letterSpacing: 1.5; renderType: Text.QtRendering }
        }
        Repeater {
            model: Math.min(s.rows, s.list.length)
            delegate: Rectangle {
                required property int index
                readonly property var d: s.list[index]
                width: s.w0; height: s.rowH; radius: 5; color: index === 0 ? "#f2262a33" : "#e615171d"
                Rectangle { width: s.rowH * 1.1; height: parent.height; radius: 5; color: index === 0 ? s.host.cAcc : "#33ffffff"
                    Text { anchors.centerIn: parent; text: d.pos; color: index === 0 ? "#101216" : "#f2f4f8"; font.bold: true; font.pixelSize: s.rowH * 0.5; renderType: Text.QtRendering } }
                Text { x: s.rowH * 1.45; anchors.verticalCenter: parent.verticalCenter; text: d.code || String(d.name).slice(0, 3).toUpperCase(); color: "#ffffff"; font.family: Fonts.resolve(s.host.style.font); font.bold: true; font.pixelSize: s.rowH * 0.55; renderType: Text.QtRendering }
                Text { x: s.rowH * 3.9; width: parent.width - x - s.rowH * 2.6; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: d.team || ""; color: "#a0ffffff"; font.family: Fonts.resolve(s.host.style.font); font.pixelSize: s.rowH * 0.38; renderType: Text.QtRendering }
                Text { anchors { right: parent.right; rightMargin: s.rowH * 0.4; verticalCenter: parent.verticalCenter } text: d.points; color: "#ffffff"; font.bold: true; font.pixelSize: s.rowH * 0.5; renderType: Text.QtRendering }
            }
        }
    }
}
