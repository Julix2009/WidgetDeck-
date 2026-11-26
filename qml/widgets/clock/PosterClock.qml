// A poster headline: huge time and date side by side, straight on the wallpaper.
import QtQuick
import "../../core"

Item {
    id: p
    required property var w
    readonly property color cFg: w.tstyle.fg || "#f2f4f8"
    readonly property color cAcc: w.tstyle.accent || "#8ab4ff"
    readonly property string hm: w.use12h ? w.fmt(w.now, "%I:%M") : w.fmt(w.now, "%H:%M")
    readonly property string day: w.fmt(w.now, "%d/%m")
    // measured at a fixed size, then scaled to the widget
    TextMetrics { id: tm; font.family: Fonts.resolve(p.w.style.font); font.pixelSize: 100; font.bold: true; text: p.hm + (p.w.props.show_date !== false ? "  — " + p.day : "") }
    readonly property real px: Math.max(10, Math.min(height * 0.9, 100 * width / Math.max(1, tm.advanceWidth * (w.use12h ? 1.16 : 1.04))))

    Row {
        anchors.centerIn: parent
        spacing: p.px * 0.18
        GText { id: t; wstyle: p.w.tstyle; font.bold: true; font.pixelSize: p.px; color: p.cFg; text: p.hm }
        GText { visible: p.w.use12h; anchors.baseline: t.baseline; wstyle: p.w.tstyle; font.bold: true; font.pixelSize: p.px * 0.28; opacity: 0.7; text: p.w.fmt(p.w.now, "%p") }
        GText { visible: p.w.props.show_date !== false; anchors.baseline: t.baseline; wstyle: p.w.tstyle; font.bold: true; font.pixelSize: p.px; color: p.cFg; opacity: 0.35; text: "—" }
        GText { visible: p.w.props.show_date !== false; anchors.baseline: t.baseline; wstyle: p.w.tstyle; font.bold: true; font.pixelSize: p.px; color: p.cAcc; text: p.day }
    }
}
