// GitHub contribution calendar: one square per day (columns = weeks), month and weekday names, totals and streak.
import QtQuick
import "../core"
import "github"

GithubBase {
    id: g
    readonly property bool green: props.colors !== "accent"
    readonly property var days: has ? d.days : []
    // the calendar starts on a Sunday; weeks are columns
    readonly property int offset: days.length > 0 ? new Date(days[0].d + "T12:00:00").getDay() : 0
    readonly property int allWeeks: Math.ceil((days.length + offset) / 7)

    readonly property real pad: Math.max(s(10), Math.min(width, height) * 0.07)
    readonly property real innerW: width - 2 * pad
    readonly property real innerH: height - 2 * pad
    readonly property bool header: props.show_totals !== false && innerH > s(120)
    readonly property bool legend: props.show_legend !== false && innerH > s(150)
    readonly property real headH: header ? s(26) : 0
    readonly property real monthH: s(16)
    readonly property real footH: legend ? s(20) : 0
    readonly property real labelW: innerW > s(340) ? s(30) : 0
    // cell size from the height; as many of the latest weeks as fit into the width
    readonly property real step: Math.max(4, Math.min((innerH - headH - monthH - footH) / 7, (innerW - labelW) / Math.min(20, Math.max(1, allWeeks))))
    readonly property real cell: step * 0.8
    readonly property int weeks: Math.max(1, Math.min(allWeeks, Math.floor((innerW - labelW) / step)))
    readonly property int first: (allWeeks - weeks) * 7 - offset          // index in `days` of the first cell
    readonly property real gridW: weeks * step - (step - cell)
    readonly property var greens: style.dark === false ? ["#14000000", "#9be9a8", "#40c463", "#30a14e", "#216e39"] : ["#18ffffff", "#0e4429", "#006d32", "#26a641", "#39d353"]
    function levelColor(l) {
        if (green) return greens[l];
        return l === 0 ? Qt.alpha(cFg, 0.09) : Qt.alpha(cAcc, [0.3, 0.52, 0.76, 1.0][l - 1]);
    }
    function monthName(i) { return Qt.locale(I18n.lang).monthName(i, Locale.ShortFormat).replace(".", ""); }
    // a month label above the first week that begins in it
    readonly property var months: {
        var out = [], last = -1, lastX = -100;
        for (var c = 0; c < weeks; c++) {
            var i = Math.max(0, first + c * 7); if (i >= days.length) break;
            var m = new Date(days[i].d + "T12:00:00").getMonth();
            if (m !== last && c * step - lastX >= s(30)) { out.push({ x: c * step, text: monthName(m) }); lastX = c * step; }
            last = m;
        }
        return out;
    }

    Item {
        visible: g.has
        x: g.pad + Math.max(0, (g.innerW - g.labelW - g.gridW) / 2)
        y: g.pad + Math.max(0, (g.innerH - g.headH - g.monthH - 7 * g.step - g.footH) / 2)
        width: g.labelW + g.gridW

        Item {
            visible: g.header
            width: parent.width; height: g.headH
            GText { width: parent.width - streak.width - g.s(8); elide: Text.ElideRight; wstyle: g.style; font.bold: true; font.pixelSize: g.s(14)
                    text: g.has ? I18n.trf("%1 contributions in the last year", g.num(g.d.total)) : "" }
            GText { id: streak; anchors.right: parent.right; wstyle: g.style; color: g.cAcc; font.bold: true; font.pixelSize: g.s(14)
                    text: g.has && parent.width > g.s(360) ? (g.d.streak === 1 ? I18n.tr("Streak: 1 day") : I18n.trf("Streak: %1 days", g.d.streak)) : "" }
        }
        Repeater {
            model: g.months
            delegate: GText { required property var modelData; x: g.labelW + modelData.x; y: g.headH; wstyle: g.style; opacity: 0.75; font.pixelSize: g.s(11); text: modelData.text }
        }
        Repeater {
            model: g.labelW > 0 ? [1, 3, 5] : []
            delegate: GText {
                required property int modelData
                y: g.headH + g.monthH + modelData * g.step + (g.cell - height) / 2
                wstyle: g.style; opacity: 0.75; font.pixelSize: Math.min(g.s(11), g.step)
                text: Qt.locale(I18n.lang).dayName(modelData, Locale.ShortFormat).replace(".", "")
            }
        }
        Repeater {
            model: g.weeks * 7
            delegate: Rectangle {
                required property int index
                readonly property int day: g.first + index
                readonly property var rec: day >= 0 && day < g.days.length ? g.days[day] : null
                visible: rec !== null
                x: g.labelW + Math.floor(index / 7) * g.step
                y: g.headH + g.monthH + (index % 7) * g.step
                width: g.cell; height: g.cell; radius: g.cell * 0.22
                color: rec ? g.levelColor(rec.l) : "transparent"
            }
        }
        Row {
            visible: g.legend
            anchors.right: parent.right
            y: g.headH + g.monthH + 7 * g.step + g.s(4)
            spacing: g.s(3)
            GText { wstyle: g.style; opacity: 0.7; font.pixelSize: g.s(11); text: I18n.tr("Less"); rightPadding: g.s(3) }
            Repeater { model: 5; delegate: Rectangle { required property int index; anchors.verticalCenter: parent.verticalCenter; width: g.s(10); height: width; radius: width * 0.22; color: g.levelColor(index) } }
            GText { wstyle: g.style; opacity: 0.7; font.pixelSize: g.s(11); text: I18n.tr("More"); leftPadding: g.s(3) }
        }
        GText {
            visible: g.legend && parent.width > g.s(300)
            x: g.labelW; y: g.headH + g.monthH + 7 * g.step + g.s(4)
            wstyle: g.style; opacity: 0.6; font.pixelSize: g.s(11); text: g.has ? "@" + g.d.user : ""
        }
    }
}
