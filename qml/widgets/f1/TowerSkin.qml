// The drivers' standings: the leader large, the rest as rows with team colour, points bar and gap to the leader.
import QtQuick
import "../../core"
import "Model.js" as M

Item {
    id: s
    required property var host
    readonly property var list: (host.fd && host.fd.standings) ? host.fd.standings : []
    readonly property var leader: list.length > 0 ? list[0] : null
    readonly property int limit: Number(host.props.standings || 10) > 3 ? Number(host.props.standings) : 10
    // rows after the leader: as many as fit with a readable height
    readonly property int rows: Math.max(2, Math.min(list.length - 1, limit - 1, Math.floor((height - 118) / 24)))
    readonly property real w0: Math.min(width, 420)
    readonly property real rowH: Math.max(20, Math.min(34, (height - 24) / (rows + 4)))
    readonly property string ff: Fonts.resolve(host.style.font)
    function surname(d) { var p = String(d.name || "").split(" "); return p.length > 1 ? p.slice(1).join(" ") : (d.name || d.code); }

    component T: Text { color: "#f4f5f8"; font.family: s.ff; renderType: Text.QtRendering }

    Rectangle {
        anchors.centerIn: parent
        width: s.w0
        height: col.height + 20
        radius: 20
        color: "#f2131313"
        border.width: 1; border.color: "#1fffffff"

        Column {
            id: col
            x: 10; y: 10; width: parent.width - 20; spacing: 3

            Item {
                width: parent.width; height: s.rowH * 0.9
                Rectangle { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 4; height: parent.height * 0.7; radius: 2; color: "#e10600" }
                T { x: 18; width: parent.width - 80; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Driver standings"); font.weight: Font.Bold; font.pixelSize: s.rowH * 0.46 }
                T { anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } text: "F1"; color: "#8a8d96"; font.weight: Font.Black; font.italic: true; font.pixelSize: s.rowH * 0.46 }
            }

            // the leader
            Rectangle {
                visible: s.leader !== null
                readonly property color team: s.leader ? M.teamColor(s.leader.team) : "#8a8d96"
                width: parent.width; height: s.rowH * 2.5; radius: 14; clip: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: s.leader ? Qt.alpha(M.teamColor(s.leader.team), 0.55) : "#33ffffff" }
                    GradientStop { position: 1.0; color: "#14ffffff" }
                }
                T { anchors { right: parent.right; rightMargin: parent.width * 0.30; verticalCenter: parent.verticalCenter } text: "1"; color: "#1affffff"; font.weight: Font.Black; font.italic: true; font.pixelSize: parent.height * 1.35 }
                Column {
                    x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.66
                    T { width: parent.width; elide: Text.ElideRight; text: s.leader ? s.surname(s.leader) : ""; font.weight: Font.Black; font.pixelSize: s.rowH * 0.9 }
                    T { width: parent.width; elide: Text.ElideRight; text: s.leader ? (s.leader.team || "") : ""; color: "#c8ffffff"; font.pixelSize: s.rowH * 0.42 }
                }
                Column {
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    T { anchors.right: parent.right; text: s.leader ? s.leader.points : ""; font.weight: Font.Black; font.pixelSize: s.rowH * 0.95; font.features: ({ "tnum": 1 }) }
                    T { anchors.right: parent.right; text: "PTS"; color: "#a0ffffff"; font.weight: Font.Bold; font.pixelSize: s.rowH * 0.34; font.letterSpacing: 1.5 }
                }
            }

            Repeater {
                model: Math.max(0, Math.min(s.rows, s.list.length - 1))
                delegate: Item {
                    id: row
                    required property int index
                    readonly property var d: s.list[index + 1]
                    readonly property color team: M.teamColor(d.team)
                    width: col.width; height: s.rowH
                    Rectangle { anchors.fill: parent; radius: 9; color: row.index % 2 === 0 ? "#0affffff" : "transparent" }
                    T { x: 0; width: s.rowH * 1.1; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; text: row.d.pos; color: "#8a8d96"; font.weight: Font.Bold; font.pixelSize: s.rowH * 0.46; font.features: ({ "tnum": 1 }) }
                    Rectangle { x: s.rowH * 1.15; anchors.verticalCenter: parent.verticalCenter; width: 4; height: parent.height * 0.62; radius: 2; color: row.team }
                    T { x: s.rowH * 1.55; width: parent.width * 0.40; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: s.surname(row.d); font.weight: Font.DemiBold; font.pixelSize: s.rowH * 0.50 }
                    // points relative to the leader
                    Rectangle {
                        x: parent.width * 0.56; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.17; height: 4; radius: 2; color: "#1affffff"
                        Rectangle { width: parent.width * Math.max(0.03, s.leader && s.leader.points > 0 ? row.d.points / s.leader.points : 0); height: parent.height; radius: 2; color: row.team }
                    }
                    T { x: parent.width * 0.74; width: parent.width * 0.12; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: s.leader ? "-" + (s.leader.points - row.d.points) : ""; color: "#6f727c"; font.pixelSize: s.rowH * 0.38; font.features: ({ "tnum": 1 }) }
                    T { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: row.d.points; font.weight: Font.Bold; font.pixelSize: s.rowH * 0.50; font.features: ({ "tnum": 1 }) }
                }
            }
        }
    }
}
