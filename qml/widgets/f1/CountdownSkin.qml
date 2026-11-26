// Only the countdown: huge digits for days, hours and minutes, the race name above.
import QtQuick
import "../../core"
import "Model.js" as M

Item {
    id: s
    required property var host
    readonly property var p: host.target ? M.parts(host.target, host.now) : null
    readonly property var segs: !p ? [] : (p.total < 3600 ? [{ n: p.m, l: I18n.tr("min") }, { n: p.s, l: I18n.tr("s") }]
        : [{ n: p.d, l: I18n.tr("d") }, { n: p.h, l: I18n.tr("h") }, { n: p.m, l: I18n.tr("min") }])
    readonly property bool tall: height > width * 1.1
    readonly property real px: Math.max(14, tall ? Math.min(width * 0.46, height / (segs.length * 1.55 + 1.2)) : Math.min(height * 0.46, width / (segs.length > 2 ? 5.4 : 3.8)))
    readonly property real label: Math.max(10, tall ? width * 0.07 : px * 0.19)

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: s.px * 0.06
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: s.host.tstyle; font.bold: true; font.pixelSize: Math.max(11, Math.min(s.px * 0.24, s.width * 0.065)); font.letterSpacing: 1.5; font.capitalization: Font.AllUppercase; color: s.host.cAcc; text: s.host.race ? M.raceName(s.host.race.name, s.host.lang) : "" }
        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: s.tall ? 1 : Math.max(1, s.segs.length)
            horizontalItemAlignment: Grid.AlignHCenter
            columnSpacing: s.px * 0.28
            Repeater {
                model: s.segs
                delegate: Column {
                    required property var modelData
                    GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: s.host.tstyle; font.weight: Font.Black; font.pixelSize: s.px; font.features: ({ "tnum": 1 }); text: modelData.n < 10 ? "0" + modelData.n : modelData.n }
                    GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: s.host.tstyle; opacity: 0.8; font.bold: true; font.pixelSize: s.label; font.capitalization: Font.AllUppercase; text: modelData.l }
                }
            }
        }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: s.host.tstyle; opacity: 0.92; font.bold: true; font.pixelSize: Math.max(10, Math.min(s.px * 0.2, s.width * 0.055)); text: s.host.raceLine }
    }
}
