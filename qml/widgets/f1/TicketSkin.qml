// A race pass: race, date, time and countdown on the dark part, the circuit on the red stub.
import QtQuick
import "../../core"
import "Model.js" as M

Item {
    id: s
    required property var host
    readonly property real w0: Math.min(width, height * 2.3)
    readonly property real h0: w0 / 2.3
    readonly property real u: w0 / 100
    readonly property string ff: Fonts.resolve(host.style.font)

    component T: Text { color: "#f4f5f8"; font.family: s.ff; renderType: Text.QtRendering; elide: Text.ElideRight }

    Rectangle {
        anchors.centerIn: parent
        width: s.w0; height: s.h0
        radius: s.u * 4.5
        color: "#f4131313"
        border.width: 1; border.color: "#1fffffff"

        // the stub
        Rectangle {
            id: stub
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; margins: s.u * 1.6 }
            width: s.w0 * 0.30; radius: s.u * 3.2
            gradient: Gradient { GradientStop { position: 0; color: "#ff2a1f" } GradientStop { position: 1; color: "#8f0500" } }
            Track {
                anchors { fill: parent; margins: s.u * 2.4; bottomMargin: s.u * 7 }
                circuit: s.host.circuit; runKey: s.host.shownKey; color: "#ffffff"; lineWidth: Math.max(2, s.u * 0.8); pad: 2; draw: s.host.props.draw_in !== false
            }
            T {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: s.u * 2 }
                horizontalAlignment: Text.AlignHCenter
                text: s.host.race ? (s.host.race.locality || s.host.race.country || "") : ""
                font.weight: Font.Bold; font.pixelSize: s.u * 2.7; font.capitalization: Font.AllUppercase; font.letterSpacing: 1.2
            }
        }

        // tear line
        Column {
            anchors { right: stub.left; rightMargin: s.u * 2; verticalCenter: parent.verticalCenter }
            spacing: s.u * 1.3
            Repeater { model: 13; delegate: Rectangle { width: Math.max(2, s.u * 0.45); height: s.u * 1.5; radius: width / 2; color: "#3affffff" } }
        }

        Item {
            x: s.u * 5; y: s.u * 4.2
            width: stub.x - x - s.u * 5; height: parent.height - 2 * y

            Row {
                spacing: s.u * 2
                Rectangle {
                    width: tag.implicitWidth + s.u * 3.4; height: s.u * 4.6; radius: height / 2; color: "#e10600"
                    T { id: tag; anchors.centerIn: parent; text: "F1"; font.weight: Font.Black; font.italic: true; font.pixelSize: s.u * 2.8 }
                }
                T { anchors.verticalCenter: parent.verticalCenter; text: s.host.race ? I18n.trf("Round %1 of %2", s.host.race.round, s.host.fd.total || s.host.fd.races.length) : ""; color: "#9ea1ab"; font.weight: Font.DemiBold; font.pixelSize: s.u * 2.7 }
            }
            Column {
                y: s.u * 6.4; width: parent.width
                T { width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; lineHeight: 0.92; text: s.host.race ? M.raceName(s.host.race.name, s.host.lang) : ""; font.weight: Font.Black; font.pixelSize: s.u * 5.8 }
                T { width: parent.width; text: s.host.race ? (s.host.race.circuitName || "") : ""; color: "#8a8d96"; font.pixelSize: s.u * 2.6 }
            }
            Row {
                anchors.bottom: parent.bottom
                width: parent.width; spacing: s.u * 1.4
                Repeater {
                    model: s.host.raceT ? [
                        { l: I18n.tr("Date"), v: s.host.dt(s.host.raceT), w: 0.36 },
                        { l: I18n.tr("Start"), v: s.host.tm(s.host.raceT), w: 0.23 },
                        { l: I18n.tr("In"), v: s.host.target ? s.host.remaining(s.host.target) : "–", w: 0.41 }
                    ] : []
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - s.u * 2.8) * modelData.w; height: s.u * 8.6; radius: s.u * 2.2; color: "#12ffffff"
                        Column {
                            x: s.u * 1.6; width: parent.width - s.u * 2.4; anchors.verticalCenter: parent.verticalCenter
                            T { width: parent.width; text: modelData.l; color: "#8a8d96"; font.weight: Font.Bold; font.pixelSize: s.u * 2.1; font.capitalization: Font.AllUppercase; font.letterSpacing: 1 }
                            T { width: parent.width; text: modelData.v; font.weight: Font.Bold; font.pixelSize: s.u * 3.3; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 7 }
                        }
                    }
                }
            }
        }
    }
}
