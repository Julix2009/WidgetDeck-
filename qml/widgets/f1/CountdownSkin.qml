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
    readonly property real px: Math.max(14, Math.min(height * 0.5, width / (segs.length > 2 ? 5.4 : 3.8)))

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: s.px * 0.06
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: s.host.tstyle; font.bold: true; font.pixelSize: s.px * 0.24; font.letterSpacing: s.px * 0.04; font.capitalization: Font.AllUppercase; color: s.host.cAcc; text: s.host.race ? M.raceName(s.host.race.name, s.host.lang) : "" }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: s.px * 0.28
            Repeater {
                model: s.segs
                delegate: Column {
                    required property var modelData
                    GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: s.host.tstyle; font.weight: Font.Black; font.pixelSize: s.px; font.features: ({ "tnum": 1 }); text: modelData.n < 10 ? "0" + modelData.n : modelData.n }
                    GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: s.host.tstyle; opacity: 0.7; font.bold: true; font.pixelSize: s.px * 0.17; font.capitalization: Font.AllUppercase; text: modelData.l }
                }
            }
        }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: s.host.tstyle; opacity: 0.75; font.pixelSize: s.px * 0.18; text: s.host.target ? s.host.raceLine : s.host.raceLine }
    }
}
