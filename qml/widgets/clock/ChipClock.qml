// One line: the time, next to it the date in a small chip.
import QtQuick
import "../../core"

Item {
    id: c
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property bool date: w.props.show_date !== false
    readonly property bool seconds: w.props.show_seconds !== false
    readonly property string family: Fonts.resolveMono(w.tstyle.font)
    readonly property real chars: (seconds ? 8 : 5) + (w.use12h ? 3 : 0)
    readonly property real px: Math.max(10, Math.min(width / (chars * 0.62 + (date ? 2.5 : 0.2)), height * 0.5))

    Row {
        anchors.centerIn: parent
        spacing: c.px * 0.3
        GText {
            id: time
            wstyle: c.w.tstyle; font.family: c.family; font.bold: true; font.pixelSize: c.px; color: c.cFg
            text: c.w.fmt(c.w.now, (c.w.use12h ? "%I" : "%H") + ":%M" + (c.seconds ? ":%S" : "") + (c.w.use12h ? " %p" : ""))
        }
        Rectangle {
            visible: c.date
            anchors.verticalCenter: time.verticalCenter
            width: dt.implicitWidth + c.px * 0.5; height: dt.implicitHeight + c.px * 0.22; radius: height / 2
            color: Qt.alpha(c.cFg, 0.12)
            GText {
                id: dt; anchors.centerIn: parent
                wstyle: c.w.tstyle; font.family: c.family; font.bold: true; font.pixelSize: Math.max(9, c.px * 0.38); opacity: 0.8
                text: (c.w.props.date_format ? c.w.dateText(c.w.now) : c.w.fmt(c.w.now, "%e %b").replace(/\.$/, "")).toUpperCase()
            }
        }
    }
}
