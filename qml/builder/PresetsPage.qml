// "Presets" page: looks that can be applied to every widget at once (built-in ones and the user's own).
import QtQuick
import "../core"
import "../core/Defaults.js" as D

Item {
    id: pg
    required property var store
    required property var th
    required property var theme
    required property var backend
    required property var wall
    property string message: ""

    readonly property var looks: {
        var out = [], n, i;
        out.push({ name: "Frosted Glass", mode: "frosted", style: ({}), own: false });
        for (n in D.LIQUID_PRESETS) out.push({ name: n, mode: "liquid", style: D.LIQUID_PRESETS[n], own: false });
        for (n in D.SOLID_PRESETS) if (n !== "Serpantinum" || theme.shellColorsAvailable) out.push({ name: n, mode: "solid", style: D.SOLID_PRESETS[n], own: false });
        var user = store.cget("user_presets", ({})), names = Object.keys(user || {}).sort();
        for (i = 0; i < names.length; i++) out.push({ name: names[i], mode: user[names[i]].mode || "liquid", style: user[names[i]], own: true });
        return out;
    }
    function modeLabel(m) { for (var i = 0; i < D.MODES.length; i++) if (D.MODES[i][0] === m) return I18n.tr(D.MODES[i][1]); return m; }

    Text { id: head; width: parent.width; wrapMode: Text.WordWrap; color: pg.message !== "" ? pg.th.accent : pg.th.dim; font.family: pg.th.font; font.pixelSize: 13
        text: pg.message !== "" ? pg.message : I18n.tr("A preset changes the look of every widget. Undo brings the old looks back.") }

    GridView {
        id: grid
        readonly property int cols: Math.max(2, Math.floor(width / 280))
        anchors { left: parent.left; right: parent.right; rightMargin: -12; top: head.bottom; topMargin: 14; bottom: parent.bottom }
        cellWidth: Math.floor(width / cols); cellHeight: 220
        clip: true; boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 0
        model: pg.looks
        delegate: Item {
            id: cell
            required property var modelData
            width: grid.cellWidth; height: grid.cellHeight
            Rectangle {
                anchors { fill: parent; rightMargin: 12; bottomMargin: 12 }
                radius: pg.th.cardRadius; color: pg.th.card
                Rectangle {
                    x: 8; y: 8; width: parent.width - 16; height: 140; radius: 12; color: pg.th.well; clip: true
                    Image { anchors.fill: parent; source: pg.wall.url; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 400 }
                    PreviewThumb {
                        anchors { fill: parent; margins: 14 }
                        store: pg.store; theme: pg.theme; backend: pg.backend; wall: pg.wall; type: "clock"
                        look: Object.assign({}, D.MODE_PRESETS[cell.modelData.mode] || {}, cell.modelData.style, { mode: cell.modelData.mode })
                    }
                }
                Column {
                    x: 14; y: 156; width: parent.width - 160
                    Text { width: parent.width; elide: Text.ElideRight; text: cell.modelData.own ? cell.modelData.name : I18n.tr(cell.modelData.name); color: pg.th.fg; font.family: pg.th.font; font.pixelSize: 14; font.bold: true }
                    Text { width: parent.width; elide: Text.ElideRight; text: pg.modeLabel(cell.modelData.mode); color: pg.th.dim; font.family: pg.th.font; font.pixelSize: 11 }
                }
                GButton {
                    anchors { right: parent.right; rightMargin: 10; bottom: parent.bottom; bottomMargin: 12 }
                    th: pg.th; label: I18n.tr("Apply to all")
                    onClicked: pg.message = I18n.trf("%1 widgets set to %2", pg.store.applyLookAll(cell.modelData.mode, cell.modelData.style), cell.modelData.own ? cell.modelData.name : I18n.tr(cell.modelData.name))
                }
            }
        }
    }
}
