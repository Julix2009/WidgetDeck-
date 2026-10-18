// Icon of a widget type: an own line icon (type.icon) or, for plugins, the short text glyph from widget.json.
import QtQuick
import "../core"

Item {
    id: tg
    property var ti: null
    property color color: "white"
    property real size: 20
    implicitWidth: size; implicitHeight: size
    Icon { anchors.fill: parent; visible: !!tg.ti && !!tg.ti.icon; name: tg.ti && tg.ti.icon ? tg.ti.icon : ""; color: tg.color }
    Text {
        anchors.fill: parent; visible: !tg.ti || !tg.ti.icon
        text: tg.ti && tg.ti.glyph ? tg.ti.glyph : "◇"; color: tg.color; font.pixelSize: tg.size
        fontSizeMode: Text.Fit; minimumPixelSize: 8; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
}
