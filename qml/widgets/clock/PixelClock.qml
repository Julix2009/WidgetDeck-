// Dot-matrix digits (own 5 x 7 font), lit dots in the accent colour, the others faint.
import QtQuick
import "../../core"

Item {
    id: p
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property color cAcc: w.tstyle.accent || "#8ab4ff"
    // each digit: 7 rows of 5 bits, top row first
    readonly property var font5: ({
        "0": [14, 17, 17, 17, 17, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31], "3": [31, 2, 4, 2, 1, 17, 14], "4": [2, 6, 10, 18, 31, 2, 2],
        "5": [31, 16, 30, 1, 1, 17, 14], "6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14], "9": [14, 17, 17, 15, 1, 2, 12],
        ":": [0, 4, 4, 0, 4, 4, 0]
    })
    readonly property string hm: w.use12h ? w.fmt(w.now, "%I:%M") : w.fmt(w.now, "%H:%M")
    readonly property int cols: hm.length * 5 + (hm.length - 1)               // one empty column between the characters
    readonly property real cell: Math.max(2, Math.min(width / cols, height / (w.props.show_date !== false ? 9.4 : 7)))
    readonly property bool blink: w.props.show_seconds !== false && w.now.getSeconds() % 2 === 1

    Column {
        anchors.centerIn: parent
        spacing: p.cell * 0.9
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: p.cell
            Repeater {
                model: p.hm.length
                delegate: Grid {
                    id: digit
                    required property int index
                    readonly property string ch: p.hm.charAt(index)
                    readonly property var rows: p.font5[ch] || [0, 0, 0, 0, 0, 0, 0]
                    columns: 5
                    Repeater {
                        model: 35
                        delegate: Item {
                            required property int index
                            readonly property bool on: (digit.rows[Math.floor(index / 5)] >> (4 - index % 5)) & 1
                            width: p.cell; height: p.cell
                            Rectangle {                         // a soft dark edge under lit dots: readable on bright wallpapers too
                                visible: parent.on; anchors.centerIn: parent; anchors.verticalCenterOffset: p.cell * 0.09; width: p.cell * 0.92; height: width; radius: width * 0.3; color: "#a0000000"
                            }
                            Rectangle {
                                anchors.centerIn: parent; width: p.cell * 0.78; height: width; radius: width * 0.28
                                color: parent.on ? (digit.ch === ":" ? p.cFg : p.cAcc) : p.cFg
                                opacity: parent.on ? (digit.ch === ":" && p.blink ? 0.25 : 1) : 0.09
                            }
                        }
                    }
                }
            }
        }
        GText { visible: p.w.props.show_date !== false; anchors.horizontalCenter: parent.horizontalCenter; wstyle: p.w.tstyle; opacity: 0.8; font.bold: true; font.pixelSize: Math.max(10, p.cell * 1.25); font.letterSpacing: p.cell * 0.3; font.capitalization: Font.AllUppercase; text: p.w.fmt(p.w.now, "%a %e %b") }
    }
}
