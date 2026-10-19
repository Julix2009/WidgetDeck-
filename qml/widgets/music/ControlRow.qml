// Previous / play-pause / next as small pills (same look as the normal music style).
import QtQuick
import "../../core"

Row {
    id: cr
    property var host
    spacing: 8
    readonly property real fs: host.style.font_size
    MButton {
        width: cr.fs * 2.3; height: cr.fs * 1.7; hoverColor: cr.host.accent; animate: cr.host.animOn
        onClicked: cr.host.prevTrack()
        Glyph { anchors.centerIn: parent; width: parent.height * 0.42; height: width; color: cr.host.style.fg; kind: "prev" }
    }
    MButton {
        width: cr.fs * 2.3; height: cr.fs * 1.7; hoverColor: cr.host.accent; strong: true; animate: cr.host.animOn
        onClicked: cr.host.togglePlay()
        Item {
            anchors.centerIn: parent; width: parent.height * 0.42; height: width
            Glyph { anchors.fill: parent; color: cr.host.style.fg; kind: "play"; opacity: cr.host.playing ? 0 : 1; scale: cr.host.playing ? 0.4 : 1
                    Behavior on opacity { NumberAnimation { duration: cr.host.animOn ? 170 : 0 } }
                    Behavior on scale { enabled: cr.host.animOn; SpringAnimation { spring: 5; damping: 0.28; epsilon: 0.002 } } }
            Glyph { anchors.fill: parent; color: cr.host.style.fg; kind: "pause"; opacity: cr.host.playing ? 1 : 0; scale: cr.host.playing ? 1 : 0.4
                    Behavior on opacity { NumberAnimation { duration: cr.host.animOn ? 170 : 0 } }
                    Behavior on scale { enabled: cr.host.animOn; SpringAnimation { spring: 5; damping: 0.28; epsilon: 0.002 } } }
        }
    }
    MButton {
        width: cr.fs * 2.3; height: cr.fs * 1.7; hoverColor: cr.host.accent; animate: cr.host.animOn
        onClicked: cr.host.nextTrack()
        Glyph { anchors.centerIn: parent; width: parent.height * 0.42; height: width; color: cr.host.style.fg; kind: "next" }
    }
}
