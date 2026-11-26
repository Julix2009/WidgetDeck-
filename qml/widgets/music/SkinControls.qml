// Previous, play / pause, next - used by the music styles.
import QtQuick
import "../../core"

Row {
    id: r
    required property var host
    property real size: 36
    property color fg: "#f2f4f8"
    spacing: size * 0.22
    MButton {
        width: r.size * 1.15; height: r.size; hoverColor: r.host.accent; animate: r.host.animOn
        onClicked: r.host.prevTrack()
        Glyph { anchors.centerIn: parent; width: parent.height * 0.42; height: width; color: r.fg; kind: "prev" }
    }
    MButton {
        width: r.size * 1.15; height: r.size; hoverColor: r.host.accent; strong: true; animate: r.host.animOn
        onClicked: r.host.togglePlay()
        Glyph { anchors.centerIn: parent; width: parent.height * 0.42; height: width; color: r.fg; kind: r.host.playing ? "pause" : "play" }
    }
    MButton {
        width: r.size * 1.15; height: r.size; hoverColor: r.host.accent; animate: r.host.animOn
        onClicked: r.host.nextTrack()
        Glyph { anchors.centerIn: parent; width: parent.height * 0.42; height: width; color: r.fg; kind: "next" }
    }
}
