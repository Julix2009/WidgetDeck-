// A tall greeting card: line, greeting, weekday, date, time, line (letters spaced out).
import QtQuick
import "../../core"

Item {
    id: c
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property color cAcc: w.tstyle.accent || "#8ab4ff"
    readonly property real u: Math.min(height / 9.4, width / 6.2)             // one layout unit
    readonly property int hr: w.now.getHours()
    readonly property string greeting: hr >= 5 && hr < 11 ? I18n.tr("Good morning") : (hr >= 11 && hr < 17 ? I18n.tr("Good day") : (hr >= 17 && hr < 22 ? I18n.tr("Good evening") : I18n.tr("Good night")))

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: c.u * 0.28
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: Math.max(1, c.u * 0.05); height: c.u * 1.2; color: Qt.alpha(c.cFg, 0.6) }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; wstyle: c.w.tstyle; font.pixelSize: c.u * 0.52; font.letterSpacing: c.u * 0.18; font.capitalization: Font.AllUppercase; text: c.greeting }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wstyle: c.w.tstyle; font.bold: true; font.pixelSize: c.u * 1.9; font.letterSpacing: c.u * 0.22; font.capitalization: Font.AllUppercase; color: c.cAcc; text: c.w.fmt(c.w.now, "%a").replace(".", "") }
        GText { visible: c.w.props.show_date !== false; width: parent.width; horizontalAlignment: Text.AlignHCenter; wstyle: c.w.tstyle; font.pixelSize: c.u * 0.5; font.letterSpacing: c.u * 0.12; font.capitalization: Font.AllUppercase; text: c.w.fmt(c.w.now, "%e %B") }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wstyle: c.w.tstyle; font.pixelSize: c.u * 0.62; font.letterSpacing: c.u * 0.1; opacity: 0.85; text: c.w.use12h ? c.w.fmt(c.w.now, "%I:%M %p") : c.w.fmt(c.w.now, "%H:%M") }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: Math.max(1, c.u * 0.05); height: c.u * 1.2; color: Qt.alpha(c.cFg, 0.6) }
    }
}
