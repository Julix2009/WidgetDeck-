// The circuit as the picture: a big outline straight on the wallpaper, the race name and the countdown under it.
import QtQuick
import "../../core"
import "Model.js" as M

Item {
    id: s
    required property var host
    readonly property real u: Math.min(width / 20, height / 17)

    Track {
        id: trk
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Math.max(0, s.height - info.height - s.u)
        circuit: s.host.circuit; runKey: s.host.shownKey; color: s.host.cAcc
        lineWidth: Math.max(3, s.u * 0.45); pad: s.u; draw: s.host.props.draw_in !== false
    }
    Column {
        id: info
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: s.u * 0.15
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: s.host.tstyle; font.bold: true; font.pixelSize: s.u * 1.5; text: s.host.race ? M.raceName(s.host.race.name, s.host.lang) : "" }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wstyle: s.host.tstyle; color: s.host.cAcc; font.bold: true; font.pixelSize: s.u * 1.2
            text: s.host.target ? s.host.remaining(s.host.target) : s.host.raceLine }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: s.host.tstyle; opacity: 0.75; font.pixelSize: s.u * 0.85; text: s.host.raceLine }
    }
}
