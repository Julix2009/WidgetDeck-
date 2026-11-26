// A poster of the cover. Tall widget: the cover fills the card, title and artist over a dark fade at the bottom, wavy progress and controls.
// Wide widget: the cover as a square on the left, the text and controls beside it (nothing may run over the widget's edge).
import QtQuick
import "../../core"

Item {
    id: p
    required property var host
    readonly property bool wide: width > height * 1.15
    readonly property real u: wide ? Math.min(height / 9, width / 26) : Math.min(width / 20, height / 24)
    readonly property real r: Math.min(28, Math.min(width, height) * 0.08)

    // ───── tall: one card ─────
    Item {
        visible: !p.wide
        anchors.fill: parent
        Rectangle { anchors.fill: parent; radius: p.r; color: "#59000000"; anchors.topMargin: 6; anchors.leftMargin: 3; anchors.rightMargin: -3; anchors.bottomMargin: -6 }
        RoundCover { anchors.fill: parent; radius: p.r; source: p.host.artText; tint: p.host.accent }
        Rectangle {
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
            Text { width: parent.width; elide: Text.ElideRight; wrapMode: Text.WordWrap; maximumLineCount: 2; text: p.host.titleText; color: "#ffffff"; font.family: Fonts.resolve(p.host.style.font); font.bold: true; font.pixelSize: Math.max(11, p.u * 1.45); renderType: Text.QtRendering }
            Text { width: parent.width; elide: Text.ElideRight; text: p.host.artistText; color: "#c0ffffff"; font.family: Fonts.resolve(p.host.style.font); font.pixelSize: Math.max(10, p.u * 0.95); font.letterSpacing: 1; renderType: Text.QtRendering }
            WaveProgress { visible: p.host.props.show_progress !== false; width: parent.width; height: p.u * 1.2; value: p.host.prog; played: p.host.accent; rest: "#59ffffff"; thickness: Math.max(2, p.u * 0.18) }
            SkinControls { visible: p.host.props.show_controls !== false; anchors.horizontalCenter: parent.horizontalCenter; host: p.host; size: Math.max(22, p.u * 2.1); fg: "#ffffff" }
        }
    }

    // ───── wide: cover | text ─────
    Item {
        visible: p.wide
        anchors.fill: parent
        Rectangle { anchors.fill: parent; radius: p.r; color: "#d9171717"; border.width: 1; border.color: "#33ffffff" }
        RoundCover { id: sq; x: p.u * 0.6; y: p.u * 0.6; width: parent.height - p.u * 1.2; height: width; radius: p.r * 0.7; source: p.host.artText; tint: p.host.accent }
        Column {
            anchors { left: sq.right; leftMargin: p.u * 1.2; right: parent.right; rightMargin: p.u * 1.2; verticalCenter: parent.verticalCenter }
            spacing: p.u * 0.35
            Text { width: parent.width; elide: Text.ElideRight; text: p.host.titleText; color: "#ffffff"; font.family: Fonts.resolve(p.host.style.font); font.bold: true; font.pixelSize: Math.max(11, p.u * 1.45); renderType: Text.QtRendering }
            Text { width: parent.width; elide: Text.ElideRight; text: p.host.artistText; color: "#c0ffffff"; font.family: Fonts.resolve(p.host.style.font); font.pixelSize: Math.max(10, p.u); renderType: Text.QtRendering }
            WaveProgress { visible: p.host.props.show_progress !== false; width: parent.width; height: p.u * 1.1; value: p.host.prog; played: p.host.accent; rest: "#59ffffff"; thickness: Math.max(2, p.u * 0.18) }
            SkinControls { visible: p.host.props.show_controls !== false; host: p.host; size: Math.max(20, p.u * 2.1); fg: "#ffffff" }
        }
    }
}
