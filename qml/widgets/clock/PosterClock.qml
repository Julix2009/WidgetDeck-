// A poster headline: huge time and date, straight on the wallpaper. Side by side in a wide widget, one above the other in a tall one.
import QtQuick
import "../../core"

Item {
    id: p
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property color cAcc: w.tstyle.accent || "#8ab4ff"
    readonly property string hm: w.use12h ? w.fmt(w.now, "%I:%M") : w.fmt(w.now, "%H:%M")
    readonly property string day: w.fmt(w.now, "%d/%m")
    readonly property bool dateOn: w.props.show_date !== false
    readonly property bool stacked: dateOn && height > width * 0.42
    // measured at 100 px, then scaled to the widget (width AND height, so nothing runs over the edge)
    TextMetrics { id: tm; font.family: Fonts.resolve(p.w.style.font); font.pixelSize: 100; font.bold: true; text: p.hm + (p.dateOn && !p.stacked ? "  — " + p.day : "") }
    readonly property real px: Math.max(10, Math.min(height * (stacked ? 0.42 : 0.9), 100 * width / Math.max(1, tm.advanceWidth * (w.use12h ? 1.2 : 1.06))))

    Grid {
        anchors.centerIn: parent
        columns: p.stacked ? 1 : 3
        horizontalItemAlignment: Grid.AlignHCenter
        columnSpacing: p.px * 0.18
        Row {
            spacing: p.px * 0.1
            GText { id: t; wstyle: p.w.tstyle; font.bold: true; font.pixelSize: p.px; color: p.cFg; text: p.hm }
            GText { visible: p.w.use12h; anchors.baseline: t.baseline; wstyle: p.w.tstyle; font.bold: true; font.pixelSize: p.px * 0.28; opacity: 0.7; text: p.w.fmt(p.w.now, "%p") }
        }
        GText { visible: p.dateOn && !p.stacked; wstyle: p.w.tstyle; font.bold: true; font.pixelSize: p.px; color: p.cFg; opacity: 0.35; text: "—" }
        GText { visible: p.dateOn; wstyle: p.w.tstyle; font.bold: true; font.pixelSize: p.px; color: p.cAcc; text: p.day }
    }
}
