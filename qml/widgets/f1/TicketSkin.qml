// A race ticket with a perforated stub: race, place, date and time, the circuit on the stub.
import QtQuick
import "../../core"
import "Model.js" as M

Item {
    id: s
    required property var host
    readonly property real w0: Math.min(width, height * 2.3)
    readonly property real h0: w0 / 2.3
    readonly property color ink: "#1b1c20"
    readonly property color red: "#d6251f"          // fixed: theme colours are often too pale on paper

    Item {
        width: s.w0; height: s.h0
        anchors.centerIn: parent
        Rectangle { anchors.fill: parent; anchors.topMargin: 5; anchors.bottomMargin: -5; radius: s.h0 * 0.08; color: "#59000000" }
        Rectangle { anchors.fill: parent; radius: s.h0 * 0.08; color: "#f5f0e6" }
        Rectangle { width: s.w0 * 0.03; height: s.h0; radius: s.h0 * 0.08; color: s.red }
        Column {
            x: s.w0 * 0.06; width: s.w0 * 0.6; anchors.verticalCenter: parent.verticalCenter; spacing: s.h0 * 0.035
            Text { width: parent.width; elide: Text.ElideRight; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 7; text: "FORMULA 1 · " + (s.host.race ? I18n.trf("Round %1 of %2", s.host.race.round, s.host.fd.total || s.host.fd.races.length) : ""); color: s.red; font.bold: true; font.pixelSize: s.h0 * 0.075; font.letterSpacing: 1.5; font.capitalization: Font.AllUppercase; renderType: Text.QtRendering }
            Text { width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; text: s.host.race ? M.raceName(s.host.race.name, s.host.lang) : ""; color: s.ink; font.family: Fonts.resolve(s.host.style.font); font.weight: Font.Black; font.pixelSize: s.h0 * 0.17; lineHeight: 0.95; renderType: Text.QtRendering }
            Text { width: parent.width; elide: Text.ElideRight; text: s.host.race ? (s.host.race.circuitName || s.host.race.locality || "") : ""; color: "#5a5c63"; font.pixelSize: s.h0 * 0.08; renderType: Text.QtRendering }
            Text { width: parent.width; text: s.host.raceLine; color: s.ink; font.bold: true; font.pixelSize: s.h0 * 0.09; renderType: Text.QtRendering }
            Text { visible: !!s.host.target; text: s.host.target ? s.host.remaining(s.host.target) : ""; color: s.red; font.bold: true; font.pixelSize: s.h0 * 0.1; renderType: Text.QtRendering }
        }
        Column {                                   // perforation
            x: s.w0 * 0.69; anchors.verticalCenter: parent.verticalCenter; spacing: s.h0 * 0.03
            Repeater { model: 14; delegate: Rectangle { width: Math.max(2, s.w0 * 0.006); height: s.h0 * 0.04; radius: 1; color: "#aaa497" } }
        }
        Rectangle { x: s.w0 * 0.69 - width / 2; y: -height / 2; width: s.h0 * 0.12; height: width; radius: width / 2; color: "#cc3a3a40" }
        Rectangle { x: s.w0 * 0.69 - width / 2; y: s.h0 - height / 2; width: s.h0 * 0.12; height: width; radius: width / 2; color: "#cc3a3a40" }
        Track {
            x: s.w0 * 0.72; y: s.h0 * 0.1; width: s.w0 * 0.25; height: s.h0 * 0.8
            circuit: s.host.circuit; runKey: s.host.shownKey; color: s.ink; lineWidth: Math.max(2, s.h0 * 0.018); pad: 4; draw: s.host.props.draw_in !== false
        }
    }
}
