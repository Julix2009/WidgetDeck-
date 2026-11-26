// Hours above minutes, very big, in two colours.
import QtQuick
import "../../core"

Item {
    id: s
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property color cAcc: w.tstyle.accent || "#8ab4ff"
    readonly property real px: Math.max(10, Math.min((height - (w.props.show_date !== false ? height * 0.12 : 0)) / 1.8, width / 1.3))

    Column {
        anchors.centerIn: parent
        spacing: -s.px * 0.22
        GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: s.w.tstyle; font.bold: true; font.weight: Font.Black; font.pixelSize: s.px; color: s.cFg; text: s.w.use12h ? s.w.fmt(s.w.now, "%I") : s.w.fmt(s.w.now, "%H") }
        GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: s.w.tstyle; font.bold: true; font.weight: Font.Black; font.pixelSize: s.px; color: s.cAcc; text: s.w.fmt(s.w.now, "%M") }
        Item { width: 1; height: s.px * 0.3; visible: s.w.props.show_date !== false }
        GText { visible: s.w.props.show_date !== false; anchors.horizontalCenter: parent.horizontalCenter; wstyle: s.w.tstyle; opacity: 0.8; font.bold: true; font.pixelSize: Math.max(10, s.px * 0.14); text: s.w.fmt(s.w.now, "%A, %e. %B") }
    }
}
