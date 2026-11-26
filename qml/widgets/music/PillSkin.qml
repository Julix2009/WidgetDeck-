// A compact capsule: round cover, title and artist, the progress under the text and a play button.
import QtQuick
import "../../core"

Item {
    id: p
    required property var host
    readonly property real h: Math.min(height, width * 0.34)

    Row {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: p.h
        spacing: p.h * 0.2
        RoundCover { id: art; width: p.h; height: p.h; radius: p.h / 2; source: p.host.artText; tint: p.host.accent }
        Column {
            width: parent.width - art.width - btn.width - parent.spacing * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: p.h * 0.06
            GText { width: parent.width; elide: Text.ElideRight; wstyle: p.host.style; font.bold: true; font.pixelSize: Math.max(11, p.h * 0.26); text: p.host.titleText }
            GText { width: parent.width; elide: Text.ElideRight; wstyle: p.host.style; opacity: 0.65; font.pixelSize: Math.max(10, p.h * 0.19); text: p.host.artistText }
            Rectangle {
                visible: p.host.props.show_progress !== false
                width: parent.width; height: Math.max(2, p.h * 0.05); radius: height / 2; color: "#33ffffff"
                Rectangle { width: parent.width * p.host.prog; height: parent.height; radius: height / 2; color: p.host.accent }
            }
        }
        MButton {
            id: btn
            width: p.h * 0.72; height: width; anchors.verticalCenter: parent.verticalCenter
            hoverColor: p.host.accent; strong: true; animate: p.host.animOn
            onClicked: p.host.togglePlay()
            Glyph { anchors.centerIn: parent; width: parent.height * 0.4; height: width; color: p.host.style.fg; kind: p.host.playing ? "pause" : "play" }
        }
    }
}
