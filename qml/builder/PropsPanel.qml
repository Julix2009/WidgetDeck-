// Right panel: geometry, glass style and the widget's own properties for the selected widget.
import QtQuick
import "../core"
import "../core/Defaults.js" as D

Item {
    id: pp
    required property var store
    required property var th
    required property var wtheme              // ThemeStore, glass backend and wallpaper: for the design previews
    required property var backend
    required property var wall
    property string sel: ""
    // simple (default) or advanced mode, remembered in builder.json; the advanced mode has three tabs
    readonly property bool adv: store.builder.advanced === true
    property string tab: "style"
    property bool fine: false
    readonly property bool showContent: adv && tab === "content"
    readonly property bool showStyle: !adv || tab === "style"
    readonly property bool showLayout: adv && tab === "layout"
    readonly property var allProps: tinfo ? tinfo.props : []
    readonly property var designProp: { for (var i = 0; i < allProps.length; i++) if (allProps[i].design === true) return allProps[i]; return null; }
    // simple mode: the flagged options (plugins without flags: the first three); advanced: every option
    readonly property var shownProps: {
        var rest = allProps.filter(function (p) { return p.design !== true; });
        if (adv) return rest;
        var s = rest.filter(function (p) { return p.simple === true; });
        return s.length > 0 || designProp ? s : rest.slice(0, 3);
    }
    function designSize(value) {
        var s = tinfo && tinfo.skinSizes ? tinfo.skinSizes[value] : null;
        return s ? s.large : (tinfo ? tinfo.size : null);
    }
    property real scrollRequest: -1           // dev/IPC: jump to a scroll position
    onScrollRequestChanged: if (scrollRequest >= 0) fl.contentY = Math.max(0, Math.min(scrollRequest, fl.contentHeight - fl.height))
    signal removeRequested()
    signal duplicateRequested()
    signal copyStyleRequested()
    signal pasteStyleRequested()
    property string styleMsg: ""            // short confirmation under the copy / paste buttons (set by the builder)
    onStyleMsgChanged: if (styleMsg !== "") styleMsgTimer.restart()
    Timer { id: styleMsgTimer; interval: 3500; onTriggered: pp.styleMsg = "" }

    readonly property var c: { store.geomRev; return sel !== "" ? store.cfg(sel) : null; }
    readonly property var st: { store.rev; return sel !== "" ? store.styleOf(sel) : null; }
    readonly property var wp: { store.rev; return sel !== "" ? store.propsOf(sel) : null; }
    readonly property var tinfo: c ? store.typeInfo(c.type) : null
    // ───────────── the user's own glass presets ─────────────
    readonly property var userPresets: { var v = store.cget("user_presets", ({})); return (v && typeof v === "object") ? v : ({}); }
    readonly property string curMode: st ? st.mode : "frosted"
    // a user preset belongs to the glass style it was saved in (older ones have no "mode": they are Liquid Glass presets)
    readonly property var userPresetNames: Object.keys(userPresets).filter(function (n) { return (userPresets[n].mode || "liquid") === pp.curMode; }).sort()
    readonly property var builtinPresets: {
        var all = D.presetsFor(curMode), out = {};
        for (var n in all) if (n !== "Serpantinum" || th.themeStore.shellColorsAvailable) out[n] = all[n];
        return out;
    }
    property string presetMsg: ""
    property string presetText: ""
    // the look of a style = the keys that belong to it; corner radius and merging belong to the widget, not to the look
    function lookKeys() {
        if (curMode === "solid") return ["bg", "border_color", "border_alpha", "shadow", "fg", "accent"];
        if (curMode === "frosted") return ["bg", "border_color", "border_alpha", "bg_alpha", "shadow", "glass", "fg", "accent"];
        var keys = Object.keys(D.LIQUID_DEFAULTS);
        for (var i = 0; i < D.STYLE_PROPS.length; i++) { var p = D.STYLE_PROPS[i]; if (p.only === "liquid" && keys.indexOf(p.key) < 0) keys.push(p.key); }
        return keys.filter(function (k) { return k !== "radius" && k !== "merge"; });
    }
    function saveUserPreset(name) {
        name = String(name || "").trim();
        if (name === "" || !st) { presetMsg = I18n.tr("Type a name first."); return; }
        if (builtinPresets[name] !== undefined) { presetMsg = I18n.tr("A built-in preset already has this name."); return; }
        var o = { mode: curMode }, k = lookKeys();
        for (var i = 0; i < k.length; i++) if (st[k[i]] !== undefined) o[k[i]] = st[k[i]];
        var all = JSON.parse(JSON.stringify(userPresets));
        all[name] = o;
        store.setConfig("user_presets", all);
        presetMsg = I18n.trf("Saved as \"%1\".", name);
    }
    function deleteUserPreset(name) {
        var all = JSON.parse(JSON.stringify(userPresets));
        delete all[name];
        store.setConfig("user_presets", all);
        presetMsg = "";
    }
    function monOptions() {
        var o = [["primary", I18n.tr("Primary monitor")], ["all", I18n.tr("All monitors")]], l = store.mons;
        for (var i = 0; i < l.length; i++) o.push([l[i].key, (i + 1) + "  " + l[i].name + "  (" + l[i].w + "×" + l[i].h + ")"]);
        if (c && c.monitor && c.monitor !== "primary" && c.monitor !== "all" && !store.monRec(c.monitor)) o.push([c.monitor, store.monitorLabel(c.monitor)]);
        return o;
    }
    function otherMons() {
        var o = [], l = store.mons, home = c ? store.homeKey(c) : "";
        for (var i = 0; i < l.length; i++) if (l[i].key !== home) o.push([l[i].key, (i + 1) + "  " + l[i].name + "  (" + l[i].w + "×" + l[i].h + ")"]);
        return o;
    }

    // style controls without the mode switch, filtered by the active glass mode
    readonly property var styleModel: {
        if (!st) return [];
        var out = [];
        for (var i = 0; i < D.STYLE_PROPS.length; i++) {
            var p = D.STYLE_PROPS[i];
            if (p.key === "mode") continue;
            if (!D.shownIn(p, st.mode)) continue;
            if (p.needs && !(Number(st[p.needs]) > 0)) continue;      // e.g. the lens controls only while the lens is on
            out.push(p);
        }
        return out;
    }

    Text {
        visible: !pp.c
        width: parent.width - 8
        wrapMode: Text.WordWrap
        text: I18n.tr("Select a widget on the stage or in the layer list.")
        color: th.dim; font.family: th.font; font.pixelSize: 13
    }

    Column {
        id: fixedHead
        visible: pp.c !== null
        width: parent.width; spacing: 8
        Item {
            width: parent.width; height: 32
            Text { width: parent.width - actions.width - 8; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: pp.tinfo ? I18n.tr(pp.tinfo.label) : ""; color: th.fg; font.family: th.font; font.pixelSize: 16; font.bold: true }
            Row {
                id: actions
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                GButton { th: pp.th; label: I18n.tr("Duplicate"); onClicked: pp.duplicateRequested() }
                GButton { th: pp.th; label: "✕"; danger: true; pad: 11; onClicked: pp.removeRequested() }
            }
        }
        Rectangle {
            width: parent.width; height: 36; radius: 12; color: th.bg
            Row {
                x: 3; y: 3; spacing: 3
                Repeater {
                    model: [[false, I18n.tr("Simple")], [true, I18n.tr("Advanced")]]
                    delegate: GButton {
                        required property var modelData
                        th: pp.th; width: (fixedHead.width - 9) / 2; implicitHeight: 30
                        label: modelData[1]; checked: pp.adv === modelData[0]
                        onClicked: pp.store.setBuilder("advanced", modelData[0])
                    }
                }
            }
        }
        Row {
            visible: pp.adv
            spacing: 6
            Repeater {
                model: [["content", I18n.tr("Contents")], ["style", I18n.tr("Style")], ["layout", I18n.tr("Layout")]]
                delegate: GButton {
                    required property var modelData
                    th: pp.th; width: (fixedHead.width - 12) / 3
                    label: modelData[1]; checked: pp.tab === modelData[0]
                    onClicked: { pp.tab = modelData[0]; fl.contentY = 0; }
                }
            }
        }
    }

    Flickable {
        id: fl
        visible: pp.c !== null
        anchors { fill: parent; topMargin: fixedHead.height + 8 }
        contentHeight: col.height + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: fl.width - 14
            spacing: 8

            // ── design tiles (clock / music styles, Formula 1 designs) ──
            Text { visible: pp.showStyle && pp.designProp !== null; text: I18n.tr("Design"); color: th.dim; font.family: th.font; font.pixelSize: 12; font.bold: true }
            Grid {
                visible: pp.showStyle && pp.designProp !== null
                columns: 3; spacing: 6; width: parent.width
                Repeater {
                    model: pp.showStyle && pp.designProp && pp.c ? pp.designProp.options : []
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool on: pp.propValue(pp.designProp.key) === modelData[0]
                        width: (col.width - 12) / 3; height: 84; radius: pp.th.ctlRadius
                        color: pp.th.well; border.width: on ? 2 : 1; border.color: on ? pp.th.accent : (tm.containsMouse ? pp.th.line : "transparent")
                        PreviewThumb {
                            x: 6; y: 6; width: parent.width - 12; height: 56
                            store: pp.store; theme: pp.wtheme; backend: pp.backend; wall: pp.wall
                            type: pp.c ? pp.c.type : "clock"
                            size: pp.designSize(tile.modelData[0])
                            previewProps: { var o = {}; o[pp.designProp.key] = tile.modelData[0]; return o; }
                        }
                        Text { y: 64; x: 4; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: I18n.tr(tile.modelData[1]); color: pp.th.fg; font.family: pp.th.font; font.pixelSize: 11 }
                        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pp.store.setProp(pp.sel, pp.designProp.key, tile.modelData[0]) }
                    }
                }
            }

            Text { visible: pp.showLayout; text: I18n.tr("POSITION & SIZE"); color: th.dim; font.family: th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2; topPadding: 4 }
            Grid {
                visible: pp.showLayout
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

            // several monitors only: which monitor the widget lives on (one monitor: none of this exists)
            Text { visible: pp.showLayout && pp.store.multi; text: I18n.tr("MONITOR"); color: th.dim; font.family: th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2; topPadding: 4; height: visible ? implicitHeight : 0 }
            GChoice {
                visible: pp.showLayout && pp.store.multi; height: visible ? implicitHeight : 0
                width: parent.width; th: pp.th; label: I18n.tr("Show on"); options: pp.monOptions(); value: pp.c && pp.c.monitor ? pp.c.monitor : "primary"
                onPicked: v => pp.store.setMonitor(pp.sel, v)
            }
            Item {
                visible: pp.showLayout && pp.store.multi; width: parent.width; height: visible ? 32 : 0
                Row {
                    spacing: 6; width: parent.width
                    GButton { th: pp.th; label: I18n.tr("Move to…"); width: (col.width - 6) / 2; onClicked: pp.th.pickList(this, pp.otherMons(), "", function (k) { pp.store.setMonitor(pp.sel, k); pp.store.selMon = k; }) }
                    GButton { th: pp.th; label: I18n.tr("Copy to…"); width: (col.width - 6) / 2; onClicked: pp.th.pickList(this, pp.otherMons(), "", function (k) { pp.store.copyToMonitor(pp.sel, k); }) }
                }
            }
            GSwitch { visible: pp.showLayout && pp.store.multi; height: visible ? implicitHeight : 0; width: parent.width; th: pp.th; label: I18n.tr("Show on the desktop"); checked: !(pp.c && pp.c.hidden); onToggled: v => pp.store.setHidden(pp.sel, !v) }

            Item {
                visible: pp.showLayout && !!pp.tinfo && !!pp.tinfo.sizes
                width: parent.width; height: visible ? 32 : 0
                Row {
                    spacing: 6; width: parent.width
                    GButton { th: pp.th; label: I18n.tr("Small"); width: (col.width - 6) / 2; onClicked: pp.store.animateGeom(pp.sel, pp.store.sizeFor(pp.sel, "small"), 320) }
                    GButton { th: pp.th; label: I18n.tr("Large"); width: (col.width - 6) / 2; onClicked: pp.store.animateGeom(pp.sel, pp.store.sizeFor(pp.sel, "large"), 320) }
                }
            }

            Text { visible: pp.showStyle; text: I18n.tr("GLASS"); color: th.dim; font.family: th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2; topPadding: 4 }
            Row {
                visible: pp.showStyle && pp.adv
                spacing: 6; width: parent.width
                GButton { th: pp.th; label: I18n.tr("Copy style"); width: (col.width - 6) / 2; onClicked: pp.copyStyleRequested() }
                GButton { th: pp.th; label: I18n.tr("Paste style"); width: (col.width - 6) / 2; enabled: pp.store.styleClip !== null; opacity: enabled ? 1 : 0.4; onClicked: pp.pasteStyleRequested() }
            }
            Text { visible: pp.showStyle && pp.styleMsg !== ""; height: visible ? implicitHeight : 0; width: parent.width; wrapMode: Text.WordWrap; text: pp.styleMsg; color: th.accent; font.family: th.font; font.pixelSize: 11 }
            GChoice {
                visible: pp.showStyle
                width: parent.width; th: pp.th; label: I18n.tr("Glass style"); options: D.MODES; value: pp.st ? pp.st.mode : "frosted"
                onPicked: v => pp.store.setStyle(pp.sel, "mode", v)
            }
            Item {
                visible: pp.showStyle && !!pp.st
                width: parent.width; height: visible ? presetCol.height + 4 : 0
                Column {
                    id: presetCol
                    width: parent.width; spacing: 6
                    Text { visible: Object.keys(pp.builtinPresets).length > 0; text: I18n.tr("Preset"); color: th.dim; font.family: th.font; font.pixelSize: 12 }
                    Flow {                                                       // wraps: any number of presets, nothing is cut off
                        width: parent.width; spacing: 6
                        Repeater {
                            model: Object.keys(pp.builtinPresets)
                            delegate: GButton {
                                required property string modelData
                                th: pp.th; label: I18n.tr(modelData); width: (col.width - 12) / 3
                                onClicked: pp.store.applyStyle(pp.sel, pp.builtinPresets[modelData])
                            }
                        }
                    }
                    // the user's own presets (config.json "user_presets"): apply with a click, the small x deletes one
                    Text { visible: pp.userPresetNames.length > 0; text: I18n.tr("Your presets"); color: th.dim; font.family: th.font; font.pixelSize: 12; topPadding: 4 }
                    Flow {
                        visible: pp.userPresetNames.length > 0
                        width: parent.width; spacing: 6
                        Repeater {
                            model: pp.userPresetNames
                            delegate: Row {
                                required property string modelData
                                spacing: 2
                                GButton {
                                    th: pp.th; label: modelData; width: (col.width - 6) / 2 - 30
                                    onClicked: pp.store.applyStyle(pp.sel, pp.userPresets[modelData])
                                }
                                GButton { th: pp.th; label: "✕"; danger: true; pad: 8; width: 28; onClicked: pp.deleteUserPreset(modelData) }
                            }
                        }
                    }
                    Text { visible: pp.adv; text: I18n.tr("Save the current look as a preset"); color: th.dim; font.family: th.font; font.pixelSize: 12; topPadding: 4 }
                    Row {
                        visible: pp.adv
                        spacing: 6; width: parent.width
                        GField { th: pp.th; label: ""; height: 30; width: col.width - 6 - 76; value: pp.presetText; onEdited: v => { pp.presetText = v; pp.presetMsg = ""; } }
                        GButton { th: pp.th; label: I18n.tr("Save"); width: 76; onClicked: pp.saveUserPreset(pp.presetText) }
                    }
                    Text { visible: pp.presetMsg !== ""; width: parent.width; wrapMode: Text.WordWrap; text: pp.presetMsg; color: th.dim; font.family: th.font; font.pixelSize: 11 }
                }
            }
            GButton {
                visible: pp.showStyle && pp.adv
                width: parent.width; th: pp.th; label: I18n.tr("Fine tuning") + (pp.fine ? "  ▴" : "  ▾")
                onClicked: pp.fine = !pp.fine
            }
            Repeater {
                model: pp.styleModel
                delegate: Column {
                    required property var modelData
                    required property int index
                    visible: pp.showStyle && pp.adv && pp.fine
                    width: col.width
                    spacing: 4
                    // a small heading where a group of controls starts (e.g. "Edge lens")
                    Text {
                        visible: !!modelData.section && (index === 0 || pp.styleModel[index - 1].section !== modelData.section)
                        height: visible ? implicitHeight + 8 : 0; verticalAlignment: Text.AlignBottom
                        text: modelData.section ? I18n.tr(modelData.section).toUpperCase() : ""
                        color: th.dim; font.family: th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2
                    }
                    Loader {
                        width: parent.width
                        sourceComponent: ctl
                        onLoaded: { item.p = modelData; item.group = "style"; }
                    }
                }
            }

            Text { visible: (pp.showContent || !pp.adv) && pp.shownProps.length > 0; text: I18n.tr("Options"); color: th.dim; font.family: th.font; font.pixelSize: 12; font.bold: true; topPadding: 6 }
            Repeater {
                model: pp.shownProps
                delegate: Loader {
                    required property var modelData
                    width: col.width
                    // `when: { key, is }` shows an option only while another option has that value (e.g. turntable settings)
                    visible: (pp.showContent || !pp.adv) && (!modelData.when || pp.propValue(modelData.when.key) === modelData.when.is)
                    sourceComponent: ctl
                    onLoaded: { item.p = modelData; item.group = "props"; }
                }
            }
            // simple mode: only the two ready-made sizes
            Text { visible: !pp.adv && !!pp.tinfo && !!pp.tinfo.sizes; text: I18n.tr("Size"); color: th.dim; font.family: th.font; font.pixelSize: 12; font.bold: true; topPadding: 6 }
            Row {
                visible: !pp.adv && !!pp.tinfo && !!pp.tinfo.sizes
                spacing: 6; width: parent.width
                GButton { th: pp.th; label: I18n.tr("Small"); width: (col.width - 6) / 2; onClicked: pp.store.animateGeom(pp.sel, pp.store.sizeFor(pp.sel, "small"), 320) }
                GButton { th: pp.th; label: I18n.tr("Large"); width: (col.width - 6) / 2; onClicked: pp.store.animateGeom(pp.sel, pp.store.sizeFor(pp.sel, "large"), 320) }
            }
        }
    }

    // current value of a widget option, falling back to its default from the registry
    function propValue(key) {
        var v = pp.wp ? pp.wp[key] : undefined;
        if (v !== undefined) return String(v);
        var ps = pp.tinfo ? pp.tinfo.props : [];
        for (var i = 0; i < ps.length; i++) if (ps[i].key === key) return String(ps[i].def);
        return "";
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
