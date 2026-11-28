// Heavy round digits, hours above minutes, the two colours crossed like a chess board.
import QtQuick
import "../../core"

Item {
    id: m
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property color cAcc: w.tstyle.accent || "#8ab4ff"
    readonly property string family: Fonts.resolveRound(w.tstyle.font)
    readonly property real px: Math.max(10, Math.min(height / 1.8, width / 1.4))
    readonly property string hh: w.fmt(w.now, w.use12h ? "%I" : "%H")
    readonly property string mm: w.fmt(w.now, "%M")

    component Digit: GText {
        width: m.px * 0.64; height: m.px * 0.82
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        wstyle: m.w.tstyle; font.family: m.family; font.weight: Font.Black; font.pixelSize: m.px
    }
    Grid {
        anchors.centerIn: parent
        columns: 2
        Digit { text: m.hh.charAt(0); color: m.cFg }
        Digit { text: m.hh.charAt(1); color: m.cAcc }
        Digit { text: m.mm.charAt(0); color: m.cAcc }
        Digit { text: m.mm.charAt(1); color: m.cFg }
    }
}
