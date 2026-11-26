// A tall poster: the cover fills the card, title and artist over a dark fade at the bottom, a wavy progress line and the controls.
import QtQuick
import "../../core"

Item {
    id: p
    required property var host
    readonly property real r: Math.min(28, width * 0.08)
    readonly property real u: width / 20

    Rectangle { anchors.fill: parent; radius: p.r; color: "#59000000"; anchors.topMargin: 6; anchors.leftMargin: 3; anchors.rightMargin: -3; anchors.bottomMargin: -6 }
    RoundCover { anchors.fill: parent; radius: p.r; source: p.host.artText; tint: p.host.accent }
    Rectangle {                                    // fade so the text stays readable on any cover
        anchors.fill: parent; radius: p.r
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 0.45; color: "#10000000" }
            GradientStop { position: 1.0; color: "#e6000000" }
        }
    }
    Column {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: p.u * 1.2 }
        spacing: p.u * 0.35
        Text { width: parent.width; elide: Text.ElideRight; wrapMode: Text.WordWrap; maximumLineCount: 2; text: p.host.titleText; color: "#ffffff"; font.family: Fonts.resolve(p.host.style.font); font.bold: true; font.pixelSize: Math.max(13, p.u * 1.45); renderType: Text.QtRendering }
        Text { width: parent.width; elide: Text.ElideRight; text: p.host.artistText; color: "#c0ffffff"; font.family: Fonts.resolve(p.host.style.font); font.pixelSize: Math.max(11, p.u * 0.95); font.letterSpacing: 1; renderType: Text.QtRendering }
        WaveProgress { visible: p.host.props.show_progress !== false; width: parent.width; height: p.u * 1.2; value: p.host.prog; played: p.host.accent; rest: "#59ffffff"; thickness: Math.max(2, p.u * 0.18) }
        SkinControls { visible: p.host.props.show_controls !== false; anchors.horizontalCenter: parent.horizontalCenter; host: p.host; size: Math.max(26, p.u * 2.1); fg: "#ffffff" }
    }
}
