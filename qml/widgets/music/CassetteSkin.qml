// A cassette: the label carries title and artist, the two reels turn while the song plays, the tape moves from the left reel to the right one.
import QtQuick
import "../../core"

Item {
    id: c
    required property var host
    readonly property real w: Math.min(width, height * 1.58)
    readonly property real h: w / 1.58
    property real turn: 0
    NumberAnimation on turn { running: c.host.live; paused: !c.host.playing; from: 0; to: 360; duration: 2600; loops: Animation.Infinite }

    component Reel: Item {
        id: reel
        property real tape: 0.5               // 0..1 of the tape on this reel
        width: c.h * 0.34; height: width
        Rectangle { anchors.centerIn: parent; width: parent.width * (0.55 + 0.45 * reel.tape); height: width; radius: width / 2; color: "#3a2a22" }
        Item {
            anchors.centerIn: parent; width: parent.width * 0.52; height: width; rotation: c.turn
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#e8e6e0" }
            Repeater { model: 3; delegate: Rectangle { required property int index; anchors.centerIn: parent; width: parent.width * 0.78; height: parent.width * 0.12; radius: height / 2; color: "#2a2d33"; rotation: index * 60 } }
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.3; height: width; radius: width / 2; color: "#e8e6e0" }
        }
    }

    Item {
        width: c.w; height: c.h
        anchors.centerIn: parent
        Rectangle { anchors.fill: parent; anchors.topMargin: 5; anchors.bottomMargin: -5; radius: c.h * 0.08; color: "#59000000" }
        Rectangle { anchors.fill: parent; radius: c.h * 0.08; color: "#f2262930"; border.width: Math.max(1, c.h * 0.008); border.color: "#55ffffff" }
        Rectangle {                                // the paper label
            x: c.w * 0.05; y: c.h * 0.07; width: c.w * 0.9; height: c.h * 0.63; radius: c.h * 0.05; color: "#f4efe4"
            Rectangle { y: parent.height * 0.38; width: parent.width; height: parent.height * 0.07; color: c.host.accent }
            Text { x: parent.width * 0.05; width: parent.width * 0.9; y: parent.height * 0.04; elide: Text.ElideRight; text: c.host.titleText; color: "#1b1c20"; font.family: Fonts.resolve(c.host.style.font); font.bold: true; font.pixelSize: c.h * 0.095; renderType: Text.QtRendering }
            Text { x: parent.width * 0.05; width: parent.width * 0.9; y: parent.height * 0.22; elide: Text.ElideRight; text: c.host.artistText; color: "#5a5c63"; font.family: Fonts.resolve(c.host.style.font); font.pixelSize: c.h * 0.065; renderType: Text.QtRendering }
            Rectangle { x: parent.width * 0.17; y: parent.height * 0.52; width: parent.width * 0.66; height: parent.height * 0.42; radius: height / 2; color: "#2a2d33" }
            Reel { x: parent.width * 0.2; y: parent.height * 0.52 + (parent.height * 0.42 - height) / 2; tape: 1 - c.host.prog }
            Reel { x: parent.width * 0.8 - width; y: parent.height * 0.52 + (parent.height * 0.42 - height) / 2; tape: c.host.prog }
        }
        SkinControls { visible: c.host.props.show_controls !== false; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: c.h * 0.05; host: c.host; size: c.h * 0.17; fg: "#f2f4f8" }
        Text { visible: c.host.props.show_progress !== false; anchors { left: parent.left; leftMargin: c.w * 0.06; bottom: parent.bottom; bottomMargin: c.h * 0.1 } text: c.host.timeText; color: "#a0ffffff"; font.pixelSize: c.h * 0.055; renderType: Text.QtRendering }
    }
}
