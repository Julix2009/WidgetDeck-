// The five start lights: one more lights up for every day the race comes closer (all five on race day, out while the race runs).
import QtQuick
import "../../core"
import "Model.js" as M

Item {
    id: s
    required property var host
    readonly property var p: host.target ? M.parts(host.target, host.now) : null
    readonly property int lit: host.shown.kind === "running" ? 0 : (!p ? 0 : Math.max(0, Math.min(5, 5 - p.d)))
    readonly property real d: Math.min(width / 6.6, height * 0.36)

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: s.d * 0.22
        Rectangle {                                // the gantry
            anchors.horizontalCenter: parent.horizontalCenter
            width: s.d * 6.2; height: s.d * 1.35; radius: s.d * 0.3; color: "#e6101216"; border.width: 1; border.color: "#40ffffff"
            Row {
                anchors.centerIn: parent
                spacing: s.d * 0.2
                Repeater {
                    model: 5
                    delegate: Item {
                        required property int index
                        readonly property bool on: index < s.lit
                        width: s.d; height: s.d
                        Rectangle { anchors.centerIn: parent; width: s.d * 1.2; height: width; radius: width / 2; color: "#55ff2d20"; visible: parent.on }
                        Rectangle { anchors.fill: parent; radius: width / 2; color: parent.on ? "#ff2d20" : "#33262a31"; border.width: 1; border.color: parent.on ? "#ff7a70" : "#33ffffff" }
                    }
                }
            }
        }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: s.host.tstyle; font.bold: true; font.pixelSize: s.d * 0.48; text: s.host.race ? M.raceName(s.host.race.name, s.host.lang) : "" }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wstyle: s.host.tstyle; color: s.host.cAcc; font.bold: true; font.pixelSize: s.d * 0.4; text: s.host.target ? s.host.remaining(s.host.target) : s.host.raceLine }
    }
}
