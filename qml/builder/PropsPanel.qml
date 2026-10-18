// Right panel: geometry, glass style and the widget's own properties for the selected widget.
import QtQuick
import "../core"
import "../core/Defaults.js" as D

Item {
    id: pp
    required property var store
    required property var th
    property string sel: ""
    property real scrollRequest: -1           // dev/IPC: jump to a scroll position
    onScrollRequestChanged: if (scrollRequest >= 0) fl.contentY = Math.max(0, Math.min(scrollRequest, fl.contentHeight - fl.height))
    signal removeRequested()
    signal duplicateRequested()

    readonly property var c: { store.geomRev; return sel !== "" ? store.cfg(sel) : null; }
    readonly property var st: { store.rev; return sel !== "" ? store.styleOf(sel) : null; }
    readonly property var wp: { store.rev; return sel !== "" ? store.propsOf(sel) : null; }
    readonly property var tinfo: c ? store.typeInfo(c.type) : null

    // style controls without the mode switch, filtered by the active glass mode
    readonly property var styleModel: {
        if (!st) return [];
        var out = [];
        for (var i = 0; i < D.STYLE_PROPS.length; i++) {
            var p = D.STYLE_PROPS[i];
            if (p.key === "mode") continue;
            if (p.only && p.only !== st.mode) continue;
            out.push(p);
        }
        return out;
    }

    Text {
        visible: !pp.c
        width: parent.width - 8
        wrapMode: Text.WordWrap
        text: I18n.tr("Select a widget on the stage or add one on the left.")
        color: th.dim; font.family: th.font; font.pixelSize: 13
    }

    Flickable {
        id: fl
        visible: pp.c !== null
        anchors.fill: parent
        contentHeight: col.height + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: fl.width - 14
            spacing: 8

            // header
            Item {
                width: parent.width; height: 36
                Text { anchors.verticalCenter: parent.verticalCenter; text: pp.tinfo ? I18n.tr(pp.tinfo.label) : ""; color: th.fg; font.family: th.font; font.pixelSize: 16; font.bold: true }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    GButton { th: pp.th; label: I18n.tr("Duplicate"); onClicked: pp.duplicateRequested() }
                    GButton { th: pp.th; label: I18n.tr("Delete"); danger: true; onClicked: pp.removeRequested() }
                }
            }

            Text { text: I18n.tr("POSITION & SIZE"); color: th.dim; font.family: th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2; topPadding: 4 }
            Grid {
                columns: 2; columnSpacing: 8; rowSpacing: 0; width: parent.width
                Repeater {
                    model: [["x", "X", 0, 8000], ["y", "Y", 0, 8000], ["w", I18n.tr("Width"), 80, 4000], ["h", I18n.tr("Height"), 50, 4000]]
                    delegate: GSpin {
                        required property var modelData
                        th: pp.th; width: (col.width - 8) / 2
                        label: I18n.tr(modelData[1]); from: modelData[2]; to: modelData[3]
                        value: pp.c ? pp.c[modelData[0]] : 0
                        onMoved: v => { var p = {}; p[modelData[0]] = v; pp.store.setGeom(pp.sel, p); }
                    }
                }
            }

            Text { text: "GLAS"; color: th.dim; font.family: th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2; topPadding: 4 }
            GChoice {
                width: parent.width; th: pp.th; label: I18n.tr("Glass style"); options: D.MODES; value: pp.st ? pp.st.mode : "frosted"
                onPicked: v => pp.store.setStyle(pp.sel, "mode", v)
            }
            Item {
                visible: pp.st && pp.st.mode === "liquid"
                width: parent.width; height: visible ? 62 : 0
                Text { text: I18n.tr("Preset"); color: th.dim; font.family: th.font; font.pixelSize: 12 }
                Row {
                    y: 20; spacing: 6; width: parent.width
                    Repeater {
                        model: Object.keys(D.LIQUID_PRESETS)
                        delegate: GButton {
                            required property string modelData
                            th: pp.th; label: I18n.tr(modelData); width: (col.width - 12) / 3
                            onClicked: pp.store.applyStyle(pp.sel, D.LIQUID_PRESETS[modelData])
                        }
                    }
                }
            }
            Repeater {
                model: pp.styleModel
                delegate: Loader {
                    required property var modelData
                    width: col.width
                    sourceComponent: ctl
                    onLoaded: { item.p = modelData; item.group = "style"; }
                }
            }

            Text { visible: pp.tinfo && pp.tinfo.props.length > 0; text: pp.tinfo ? I18n.tr(pp.tinfo.label).toUpperCase() : ""; color: th.dim; font.family: th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2; topPadding: 6 }
            Repeater {
                model: pp.tinfo ? pp.tinfo.props : []
                delegate: Loader {
                    required property var modelData
                    width: col.width
                    sourceComponent: ctl
                    onLoaded: { item.p = modelData; item.group = "props"; }
                }
            }
        }
    }

    // one generic editor, chosen by prop kind
    Component {
        id: ctl
        Item {
            id: e
            property var p: ({ kind: "text", key: "", label: "", def: "" })
            property string group: "style"
            readonly property var cur: group === "style" ? pp.st : pp.wp
            readonly property var val: cur ? cur[p.key] : undefined
            function set(v) { if (group === "style") pp.store.setStyle(pp.sel, p.key, v); else pp.store.setProp(pp.sel, p.key, v); }
            implicitHeight: kindLoader.item ? kindLoader.item.implicitHeight : 40
            height: implicitHeight
            Loader {
                id: kindLoader
                width: parent.width
                sourceComponent: e.p.kind === "range" ? cSlider : e.p.kind === "int" ? cSpin : e.p.kind === "bool" ? cSwitch
                               : e.p.kind === "choice" ? cChoice : e.p.kind === "color" ? cColor : e.p.kind === "font" ? cFont : cText
                property var ed: e
            }
        }
    }
    Component { id: cSlider; GSlider { th: pp.th; label: I18n.tr(ed.p.label); from: ed.p.min; to: ed.p.max; step: ed.p.step; value: Number(ed.val); onMoved: v => ed.set(v) } }
    Component { id: cSpin; GSpin { th: pp.th; label: I18n.tr(ed.p.label); from: ed.p.min; to: ed.p.max; step: ed.p.step || 1; value: Number(ed.val); onMoved: v => ed.set(v) } }
    Component { id: cSwitch; GSwitch { th: pp.th; label: I18n.tr(ed.p.label); checked: !!ed.val; onToggled: v => ed.set(v) } }
    Component { id: cChoice; GChoice { th: pp.th; label: I18n.tr(ed.p.label); options: ed.p.options; value: String(ed.val); onPicked: v => ed.set(v) } }
    Component { id: cColor; GThemeColor { th: pp.th; label: I18n.tr(ed.p.label); value: String(ed.val); defRole: String(ed.p.def).indexOf("theme:") === 0 ? String(ed.p.def).substring(6) : "primary"; onPicked: v => ed.set(v) } }
    Component { id: cText; GField { th: pp.th; label: I18n.tr(ed.p.label); value: ed.val === undefined ? "" : String(ed.val); onEdited: v => ed.set(v) } }
    Component {
        id: cFont
        Item {
            implicitHeight: 52
            Text { text: I18n.tr(ed.p.label); color: pp.th.dim; font.family: pp.th.font; font.pixelSize: 12 }
            GButton {
                y: 18; width: parent.width; th: pp.th; label: ed.val ? String(ed.val) : I18n.tr("System default")
                onClicked: pp.th.pickList(this, Qt.fontFamilies().map(function (f) { return [f, f]; }), String(ed.val), function (v) { ed.set(v); })
            }
        }
    }
}
