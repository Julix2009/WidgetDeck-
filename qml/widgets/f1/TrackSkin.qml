// The circuit as the picture: a big outline straight on the wallpaper, race name and countdown below it - or beside it in a wide widget.
import QtQuick
import "../../core"
import "Model.js" as M

Item {
    id: s
    required property var host
    readonly property bool wide: width > height * 1.5
    readonly property real u: wide ? Math.min(width / 34, height / 9) : Math.min(width / 20, height / 17)

    Track {
        id: trk
        x: 0; y: 0
        width: s.wide ? s.width * 0.38 : s.width
        height: s.wide ? s.height : Math.max(0, s.height - info.height - s.u)
        circuit: s.host.circuit; runKey: s.host.shownKey; color: s.host.cAcc
        lineWidth: Math.max(3, s.u * 0.45); pad: s.u * 0.8; draw: s.host.props.draw_in !== false
    }
    Column {
        id: info
        x: s.wide ? trk.width + s.u : 0
        width: s.wide ? s.width - x : s.width
        y: s.wide ? (s.height - height) / 2 : s.height - height
        spacing: s.u * 0.15
        GText { width: parent.width; horizontalAlignment: s.wide ? Text.AlignLeft : Text.AlignHCenter; elide: Text.ElideRight; wstyle: s.host.tstyle; font.bold: true; font.pixelSize: Math.max(11, s.u * 1.5); text: s.host.race ? M.raceName(s.host.race.name, s.host.lang) : "" }
        GText { width: parent.width; horizontalAlignment: s.wide ? Text.AlignLeft : Text.AlignHCenter; elide: Text.ElideRight; wstyle: s.host.tstyle; color: s.host.cAcc; font.bold: true; font.pixelSize: Math.max(11, s.u * 1.2)
            text: s.host.target ? s.host.remaining(s.host.target) : s.host.raceLine }
        GText { width: parent.width; horizontalAlignment: s.wide ? Text.AlignLeft : Text.AlignHCenter; elide: Text.ElideRight; wstyle: s.host.tstyle; opacity: 0.9; font.bold: true; font.pixelSize: Math.max(10, s.u * 0.85); text: s.host.raceLine }
    }
}
