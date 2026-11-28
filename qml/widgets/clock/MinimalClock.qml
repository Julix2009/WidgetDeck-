// Nothing but the time, in a fixed-width font.
import QtQuick
import "../../core"

Item {
    id: m
    required property var w
    readonly property bool seconds: w.props.show_seconds !== false
    readonly property real chars: (seconds ? 8 : 5) + (w.use12h ? 3 : 0)

    GText {
        anchors.centerIn: parent
        wstyle: m.w.tstyle; font.family: Fonts.resolveMono(m.w.tstyle.font); font.bold: true
        font.pixelSize: Math.max(10, Math.min(m.width / (m.chars * 0.64), m.height * 0.6))
        text: m.w.fmt(m.w.now, (m.w.use12h ? "%I" : "%H") + ":%M" + (m.seconds ? ":%S" : "") + (m.w.use12h ? " %p" : ""))
    }
}
