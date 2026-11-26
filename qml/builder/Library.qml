// "Library" page: every widget type as a card with a live preview, filtered by category.
import QtQuick
import "../core"

Item {
    id: lib
    required property var store
    required property var th
    required property var theme
    required property var backend
    required property var wall
    signal addRequested(string type, var props, var size)

    // widgets with several looks (clock / music styles, Formula 1 designs, rings / bars ...): the arrows on a card step through them
    property var picked: ({})            // type -> index; kept here because cards are destroyed when scrolled away
    function variantProp(ti) {
        var ps = ti ? ti.props : [], i;
        for (i = 0; i < ps.length; i++) if (ps[i].design === true) return ps[i];
        for (i = 0; i < ps.length; i++) if (ps[i].key === "mode" && ps[i].kind === "choice") return ps[i];
        return null;
    }
    function step(type, count, by) {
        var o = Object.assign({}, picked);
        o[type] = (((o[type] || 0) + by) % count + count) % count;
        picked = o;
    }

    property string category: "all"
    readonly property var categories: [["all", I18n.tr("All")], ["system", I18n.tr("System")], ["media", I18n.tr("Media")], ["weather", I18n.tr("Weather")],
                                       ["sport", I18n.tr("Sport")], ["school", I18n.tr("School")], ["own", I18n.tr("Own")]]
    readonly property var catOf: ({ clock: "system", sysmon: "system", netmon: "system", thermals: "system", sysstatus: "system", fastfetch: "system",
                                    music: "media", lyrics: "media", visualizer: "media", weather: "weather", weathercard: "weather", airquality: "weather",
                                    f1: "sport", github: "system", focustimer: "school", timetable: "school", schoolprogress: "school" })
    readonly property var allKeys: { store.rev; return Object.keys(store.allTypes); }
    readonly property var keys: allKeys.filter(function (k) { return lib.category === "all" || (lib.catOf[k] || "own") === lib.category; })
    readonly property bool hasOwn: allKeys.some(function (k) { return lib.catOf[k] === undefined; })

    Row {
        id: chips
        spacing: 6
        Repeater {
            model: lib.categories.filter(function (c) { return c[0] !== "own" || lib.hasOwn; })
            delegate: GButton {
                required property var modelData
                th: lib.th; label: modelData[1]; checked: lib.category === modelData[0]
                onClicked: lib.category = modelData[0]
            }
        }
    }

    GridView {
        id: grid
        readonly property int cols: Math.max(2, Math.floor(width / 300))
        anchors { left: parent.left; right: parent.right; rightMargin: -12; top: chips.bottom; topMargin: 14; bottom: parent.bottom }
        cellWidth: Math.floor(width / cols); cellHeight: 262
        clip: true; boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 0
        model: lib.keys
        delegate: Item {
            id: cell
            required property string modelData
            readonly property var ti: lib.store.typeInfo(modelData)
            readonly property var vp: lib.variantProp(ti)
            readonly property int count: vp ? vp.options.length : 0
            readonly property int index: Math.min(lib.picked[modelData] || 0, Math.max(0, count - 1))
            // the standard look (first option) changes nothing: it is not written into the layout
            readonly property var chosen: { var o = {}; if (vp && index > 0) o[vp.key] = vp.options[index][0]; return o; }
            readonly property var chosenSize: {
                var s = vp && ti.skinSizes ? ti.skinSizes[vp.options[index][0]] : null;
                return s ? s.large : null;
            }
            width: grid.cellWidth; height: grid.cellHeight
            Rectangle {
                anchors { fill: parent; rightMargin: 12; bottomMargin: 12 }
                radius: lib.th.cardRadius; color: lib.th.card
                border.width: 1; border.color: hover.hovered ? lib.th.accent : "transparent"
                HoverHandler { id: hover }
                Rectangle {
                    x: 8; y: 8; width: parent.width - 16; height: 132; radius: 12; color: lib.th.well
                    PreviewThumb {
                        anchors { fill: parent; margins: 8 }
                        anchors.leftMargin: cell.count > 1 ? 30 : 8; anchors.rightMargin: cell.count > 1 ? 30 : 8
                        anchors.bottomMargin: cell.count > 1 ? 22 : 8
                        store: lib.store; theme: lib.theme; backend: lib.backend; wall: lib.wall; type: cell.modelData
                        previewProps: cell.chosen; size: cell.chosenSize
                    }
                    Repeater {
                        model: cell.count > 1 ? [-1, 1] : []
                        delegate: GButton {
                            required property int modelData
                            x: modelData < 0 ? 6 : parent.width - width - 6
                            anchors.verticalCenter: parent.verticalCenter
                            th: lib.th; width: 24; implicitHeight: 24; pad: 0; radius: 12
                            label: modelData < 0 ? "‹" : "›"
                            onClicked: lib.step(cell.modelData, cell.count, modelData)
                        }
                    }
                    Text {
                        visible: cell.count > 1
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                        text: cell.count > 1 ? I18n.tr(cell.vp.options[cell.index][1]) + "  " + (cell.index + 1) + "/" + cell.count : ""
                        color: lib.th.dim; font.family: lib.th.font; font.pixelSize: 11
                    }
                }
                TypeGlyph { x: 14; y: 150; width: 18; height: 18; size: 16; ti: cell.ti; color: lib.th.fg }
                Text { x: 40; y: 150; width: parent.width - 52; elide: Text.ElideRight; text: cell.ti ? I18n.tr(cell.ti.label) : cell.modelData; color: lib.th.fg; font.family: lib.th.font; font.pixelSize: 14; font.bold: true }
                Text { x: 14; y: 172; width: parent.width - 28; height: 32; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; text: cell.ti ? I18n.tr(cell.ti.desc) : ""; color: lib.th.dim; font.family: lib.th.font; font.pixelSize: 11 }
                GButton { x: 12; y: parent.height - height - 10; width: parent.width - 24; th: lib.th; primary: true; label: I18n.tr("Add"); onClicked: lib.addRequested(cell.modelData, cell.chosen, cell.chosenSize) }
            }
        }
    }
}
