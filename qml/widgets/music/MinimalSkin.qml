// Only typography, free on the wallpaper: a very big title, the artist in the accent colour, a wavy progress line and the time.
import QtQuick
import "../../core"

Item {
    id: m
    required property var host
    // the column is about 3.2 title sizes high: the size follows the smaller of both directions, nothing runs over the edge
    readonly property real px: Math.max(11, Math.min(height / 3.3, width / 8.5))

    Column {
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: m.px * 0.12
        GText { width: parent.width; elide: Text.ElideRight; wstyle: m.host.tstyle; font.bold: true; font.weight: Font.Black; font.pixelSize: m.px; text: m.host.titleText }
        GText { width: parent.width; elide: Text.ElideRight; wstyle: m.host.tstyle; color: m.host.accent; font.bold: true; font.pixelSize: m.px * 0.44; font.letterSpacing: m.px * 0.06; font.capitalization: Font.AllUppercase; text: m.host.artistText }
        Row {
            visible: m.host.props.show_progress !== false
            width: parent.width; spacing: m.px * 0.3
            WaveProgress { width: parent.width - clk.width - parent.spacing; height: m.px * 0.4; value: m.host.prog; played: m.host.accent; rest: Qt.alpha(m.host.tstyle.fg || "#ffffff", 0.3); thickness: Math.max(2, m.px * 0.07); anchors.verticalCenter: parent.verticalCenter }
            GText { id: clk; wstyle: m.host.tstyle; opacity: 0.75; font.pixelSize: m.px * 0.34; text: m.host.timeText }
        }
        SkinControls { visible: m.host.props.show_controls !== false; host: m.host; size: Math.max(18, m.px * 0.68); fg: m.host.tstyle.fg || "#ffffff" }
    }
}
