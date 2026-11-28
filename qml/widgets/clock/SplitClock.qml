// Hours in the accent colour, minutes in the text colour, the date small and spaced out underneath.
import QtQuick
import "../../core"

Item {
    id: s
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property color cAcc: w.tstyle.accent || "#8ab4ff"
    readonly property bool date: w.props.show_date !== false
    readonly property string family: Fonts.resolveMono(w.tstyle.font)
    readonly property real px: Math.max(10, Math.min(width / 3.5, height * (date ? 0.52 : 0.68)))

    Column {
        anchors.centerIn: parent
        spacing: s.px * 0.06
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            GText { wstyle: s.w.tstyle; font.family: s.family; font.bold: true; font.pixelSize: s.px; color: s.cAcc; text: s.w.fmt(s.w.now, s.w.use12h ? "%I" : "%H") }
            GText { wstyle: s.w.tstyle; font.family: s.family; font.bold: true; font.pixelSize: s.px; color: s.cFg; opacity: 0.7; text: ":" }
            GText { wstyle: s.w.tstyle; font.family: s.family; font.bold: true; font.pixelSize: s.px; color: s.cFg; text: s.w.fmt(s.w.now, "%M") }
        }
        GText {
            visible: s.date
            width: s.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            wstyle: s.w.tstyle; font.family: s.family; font.pixelSize: Math.max(9, s.px * 0.15); font.letterSpacing: font.pixelSize * 0.15; opacity: 0.65
            text: (s.w.props.date_format ? s.w.dateText(s.w.now) : s.w.fmt(s.w.now, "%A, %e. %B")).toUpperCase()
        }
    }
}
