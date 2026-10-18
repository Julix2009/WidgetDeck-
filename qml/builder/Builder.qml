// The visual editor window.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core"
import "../core/Defaults.js" as D

FloatingWindow {
    id: win
    required property var store
    required property var theme
    required property var backend
    required property var wall
    required property var update
    property string screenName: ""
    signal settingsClose()
    onSettingsClose: settings.visible = false
    function showSettings(on) { settings.visible = on; }
    function scrollSettings(y) { setFlick.contentY = Math.max(0, Math.min(y, setFlick.contentHeight - setFlick.height)); }
    property size screenSize: Qt.size(2560, 1600)
    property string sel: ""                  // primary selection (props panel)
    property var sels: []                    // all selected widgets (Shift+click / rubber band)
    property real propsScroll: -1
    onSelChanged: {                          // a selection set from outside (palette, layer list, IPC) becomes the only one
        if (sel === "") { if (sels.length > 0) sels = []; }
        else if (sels.indexOf(sel) < 0) sels = [sel];
    }
    function selectIds(ids, primary) { sels = ids; sel = primary; }
    // widgets that disappeared (deleted, layout reset, file reload) leave the selection
    Connections {
        target: win.store
        function onWidgetIdsChanged() {
            var ok = win.sels.filter(function (id) { return win.store.widgetIds.indexOf(id) >= 0; });
            if (ok.length !== win.sels.length) { win.sels = ok; if (ok.indexOf(win.sel) < 0) win.sel = ok.length ? ok[ok.length - 1] : ""; }
        }
    }
    function removeSelected() {
        var ids = sels.length > 0 ? sels.slice() : (sel !== "" ? [sel] : []);
        for (var i = 0; i < ids.length; i++) store.remove(ids[i]);
        sels = []; sel = "";
    }

    readonly property alias canvasItem: canvas
    visible: false
    title: "WidgetDeck"
    color: "transparent"
    implicitWidth: 1500
    implicitHeight: 920
    minimumSize: Qt.size(1100, 700)

    readonly property bool liquidUi: store.builder.glass === "liquid" && backend.ready && wall.usable
    readonly property bool liveOn: store.builder.liveCapture === true && liquidUi
    Loader {
        id: liveLoader
        active: win.liveOn && win.visible
        sourceComponent: LiveBackdrop { wall: win.wall; screenSize: win.screenSize }
    }
    readonly property Item liveItem: liveLoader.item
    Theme { id: th; themeStore: win.theme; liquid: win.liquidUi }

    // ───────────── where is this window on the monitor? (the glass refracts the wallpaper behind it) ─────────────
    property point winPos: Qt.point(Math.max(0, (screenSize.width - width) / 2), Math.max(0, (screenSize.height - height) / 2))
    function updatePos() {
        var ts = Hyprland.toplevels.values;
        for (var i = 0; i < ts.length; i++) {
            if (ts[i].title !== "WidgetDeck") continue;
            var o = ts[i].lastIpcObject;
            if (o && o.at) { winPos = Qt.point(o.at[0], o.at[1]); return; }
        }
    }
    Timer {
        interval: 300; repeat: true; running: win.visible
        onTriggered: { Hyprland.refreshToplevels(); win.updatePos(); }
    }
    onVisibleChanged: if (visible) { Hyprland.refreshToplevels(); Qt.callLater(updatePos); }

    // ───────────── glass styles of the builder itself ─────────────
    readonly property real op: store.builder.opacity
    function gstyle(radius, alphaScale, extra) {
        // liquid: the default look (all defaults); only the tint follows the "Deckkraft" setting and the theme
        var base = liquidUi
            ? { mode: "liquid", radius: radius, bg_alpha: Math.max(0.3, (op - 0.3) * 1.0) * alphaScale, shadow: 0.0 }
            : { mode: "frosted", radius: radius, bg: "theme:surface", bg_alpha: Math.min(0.97, op * alphaScale), border_alpha: 0.10, shadow: 0, glass: false };
        return theme.resolveStyle(D.resolveStyle(Object.assign(base, extra || {})));
    }
    readonly property var winStyle: gstyle(30, 1.0)
    readonly property var panelStyle: gstyle(24, 0.55, liquidUi ? { bg_alpha: Math.max(0.2, (op - 0.3) * 0.7) } : { bg_alpha: Math.min(0.5, op * 0.2), border_alpha: 0.09 })

    // ───────────── popups (live here so no panel clips them) ─────────────
    property var _colorCb: null
    property var _listCb: null
    property var _anchor: null
    function popAt(item, w, h) {
        var p = item.mapToItem(root, 0, item.height + 6);
        return Qt.point(Math.max(8, Math.min(root.width - w - 8, p.x)), Math.min(root.height - h - 8, p.y));
    }
    Component.onCompleted: {
        th.pickColor = function (item, hex, cb) {
            win._colorCb = cb;
            colorPop.hex = hex;
            var pt = win.popAt(item, colorPop.width, colorPop.height);
            colorPop.x = pt.x; colorPop.y = pt.y; colorPop.visible = true;
        };
        th.pickList = function (item, items, current, cb) {
            win._listCb = cb;
            listPop.items = items; listPop.current = current; listPop.filter = "";
            var pt = win.popAt(item, listPop.width, listPop.height);
            listPop.x = pt.x; listPop.y = pt.y; listPop.visible = true;
        };
    }

    Item {
        id: root
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { if (colorPop.visible || listPop.visible || settings.visible) { colorPop.visible = false; listPop.visible = false; settings.visible = false; } else win.visible = false; event.accepted = true; return; }
            if (win.sels.length === 0 || colorPop.visible || listPop.visible) return;
            // arrow keys: one grid cell (Shift: five cells), for the whole selection; Delete removes the selection
            var st = (event.modifiers & Qt.ShiftModifier) ? 5 : 1;
            if (event.key === Qt.Key_Delete) { win.removeSelected(); event.accepted = true; }
            else if (event.key === Qt.Key_Left)  { canvas.nudge(-st, 0); event.accepted = true; }
            else if (event.key === Qt.Key_Right) { canvas.nudge(st, 0); event.accepted = true; }
            else if (event.key === Qt.Key_Up)    { canvas.nudge(0, -st); event.accepted = true; }
            else if (event.key === Qt.Key_Down)  { canvas.nudge(0, st); event.accepted = true; }
        }

        // window background
        GlassPanel {
            id: winGlass
            width: root.width; height: root.height
            style: win.winStyle; backend: win.backend; wall: win.wall; backdrop: win.liveItem
            screenX: win.winPos.x; screenY: win.winPos.y; screenSize: win.screenSize
            padPx: 0; interactive: false
        }

        // header (drag area)
        Item {
            id: header
            x: 22; y: 14; width: root.width - 44; height: 40
            MouseArea {
                anchors.fill: parent
                property point start
                onPressed: mouse => { if (typeof win.startSystemMove === "function") win.startSystemMove(); }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "◈  WidgetDeck"; color: th.fg; font.family: th.font; font.pixelSize: 16; font.bold: true }
            Text { x: 150; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Drag widgets (grid + guides, Alt = free), Shift = multi-select - changes appear live on the desktop"); color: th.dim; font.family: th.font; font.pixelSize: 12 }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                GButton { th: th; label: I18n.tr("Settings"); checked: settings.visible; onClicked: settings.visible = !settings.visible }
                GButton { th: th; label: "✕"; danger: true; pad: 12; onClicked: win.visible = false }
            }
        }

        // three panels
        Item {
            id: body
            x: 18; y: 62; width: root.width - 36; height: root.height - 80
            readonly property real leftW: 270
            readonly property real rightW: 330

            GlassPanel {
                id: leftGlass
                x: 0; y: 0; width: body.leftW; height: body.height
                style: win.panelStyle; backend: win.backend; wall: win.wall; backdrop: win.liveItem
                screenX: win.winPos.x + body.x + x; screenY: win.winPos.y + body.y + y; screenSize: win.screenSize
                padPx: 0; interactive: false
                WidgetPalette {
                    id: palette
                    anchors.fill: parent; anchors.margins: 14
                    store: win.store; th: th; sel: win.sel
                    onAddRequested: type => { win.sel = canvas.addAtFree(type); }
                    onDragMoved: (type, gx, gy) => { ghost.type = type; var p = root.mapFromItem(null, gx, gy); ghost.x = p.x - ghost.width / 2; ghost.y = p.y - ghost.height / 2; ghost.visible = true; }
                    onDragEnded: (type, gx, gy, moved) => {
                        ghost.visible = false;
                        if (canvas.containsGlobal(gx, gy)) canvas.dropAt(type, gx, gy);
                    }
                    onLayerPicked: id => win.sel = id
                }
            }
            GlassPanel {
                id: midGlass
                x: body.leftW + 12; y: 0; width: body.width - body.leftW - body.rightW - 24; height: body.height
                style: win.panelStyle; backend: win.backend; wall: win.wall; backdrop: win.liveItem
                screenX: win.winPos.x + body.x + x; screenY: win.winPos.y + body.y + y; screenSize: win.screenSize
                padPx: 0; interactive: false
                StageCanvas {
                    id: canvas
                    anchors.fill: parent; anchors.margins: 10
                    store: win.store; theme: win.theme; th: th; backend: win.backend; wall: win.wall
                    screenSize: win.screenSize; sel: win.sel; sels: win.sels
                    onSelectionRequested: (ids, primary) => win.selectIds(ids, primary)
                }
            }
            GlassPanel {
                id: rightGlass
                x: body.width - body.rightW; y: 0; width: body.rightW; height: body.height
                style: win.panelStyle; backend: win.backend; wall: win.wall; backdrop: win.liveItem
                screenX: win.winPos.x + body.x + x; screenY: win.winPos.y + body.y + y; screenSize: win.screenSize
                padPx: 0; interactive: false
                PropsPanel {
                    anchors.fill: parent; anchors.margins: 14
                    store: win.store; th: th; sel: win.sel; scrollRequest: win.propsScroll
                    onRemoveRequested: win.removeSelected()
                    onDuplicateRequested: win.sel = win.store.duplicate(win.sel)
                }
            }
        }

        // drag ghost for palette drops
        Rectangle {
            id: ghost
            property string type: ""
            visible: false; z: 100
            width: 150; height: 64; radius: 18; opacity: 0.85
            color: Qt.rgba(Qt.color(th.accent).r, Qt.color(th.accent).g, Qt.color(th.accent).b, 0.35)
            border.color: th.accent; border.width: 2
            Row {
                anchors.centerIn: parent; spacing: 8
                readonly property var t: win.store.typeInfo(ghost.type)
                TypeGlyph { anchors.verticalCenter: parent.verticalCenter; ti: parent.t; color: th.fg; size: 18 }
                Text { anchors.verticalCenter: parent.verticalCenter; color: th.fg; font.family: th.font; font.pixelSize: 14; text: parent.t ? I18n.tr(parent.t.label) : "" }
            }
        }

        // settings
        GlassPanel {
            id: settings
            visible: false; z: 50
            x: root.width - width - 22; y: 56; width: 360
            height: Math.min(root.height - 80, setCol.height + 36)
            style: win.gstyle(26, 1.2); backend: win.backend; wall: win.wall; backdrop: win.liveItem
            screenX: win.winPos.x + x; screenY: win.winPos.y + y; screenSize: win.screenSize
            padPx: 0; interactive: false
            Flickable {
                id: setFlick
                anchors.fill: parent; anchors.margins: 18
                contentHeight: setCol.height; clip: true; boundsBehavior: Flickable.StopAtBounds
                SettingsPanel {
                    id: setCol
                    width: parent.width - 8
                    store: win.store; theme: win.theme; wall: win.wall; backend: win.backend; update: win.update; th: th
                    screenName: win.screenName; liquidOk: win.backend.ready && win.wall.usable
                    onPickWallpaper: { wallPicker.startPath = ""; wallPicker.open(); }
                    onRunWizard: { win.settingsClose(); win.store.setConfig("setup.done", false); }
                }
            }
        }

        // wallpaper chooser (own file browser, no portal needed)
        FilePicker { id: wallPicker; z: 150; anchors.centerIn: parent; width: Math.min(root.width - 80, 760); height: Math.min(root.height - 80, 540); th: th; visible: false
            onPicked: p => { win.store.data.wallpaperPath = p; win.store.touch(false); } }

        // colour picker popup
        Rectangle {
            id: colorPop
            property string hex: "#ffffff"
            visible: false; z: 200
            width: 250; height: 230; radius: 18
            color: th.popup; border.width: 1; border.color: th.line
            property real hue: Qt.color(hex).hsvHue < 0 ? 0 : Qt.color(hex).hsvHue
            property real sat: Qt.color(hex).hsvSaturation
            property real val: Qt.color(hex).hsvValue
            function commit(h, s, v) { hex = Qt.hsva(h, s, v, 1).toString().substring(0, 7); if (win._colorCb) win._colorCb(hex); }
            Column {
                x: 14; y: 14; width: parent.width - 28; spacing: 10
                Rectangle {   // saturation / value square
                    width: parent.width; height: 110; radius: 10; clip: true
                    color: Qt.hsva(colorPop.hue, 1, 1, 1)
                    Rectangle { anchors.fill: parent; gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "white" } GradientStop { position: 1; color: "transparent" } } }
                    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: "black" } } }
                    Rectangle { x: colorPop.sat * (parent.width - 12); y: (1 - colorPop.val) * (parent.height - 12); width: 12; height: 12; radius: 6; color: "transparent"; border.width: 2; border.color: "white" }
                    MouseArea {
                        anchors.fill: parent
                        function set(m) { colorPop.commit(colorPop.hue, Math.max(0, Math.min(1, m.x / width)), 1 - Math.max(0, Math.min(1, m.y / height))); }
                        onPressed: m => set(m); onPositionChanged: m => { if (pressed) set(m); }
                    }
                }
                Rectangle {   // hue bar
                    width: parent.width; height: 14; radius: 7
                    gradient: Gradient { orientation: Gradient.Horizontal
                        GradientStop { position: 0.00; color: "#ff0000" } GradientStop { position: 0.17; color: "#ffff00" } GradientStop { position: 0.33; color: "#00ff00" }
                        GradientStop { position: 0.50; color: "#00ffff" } GradientStop { position: 0.67; color: "#0000ff" } GradientStop { position: 0.83; color: "#ff00ff" } GradientStop { position: 1.00; color: "#ff0000" } }
                    Rectangle { x: colorPop.hue * (parent.width - 8); y: -2; width: 8; height: 18; radius: 4; color: "white"; border.width: 1; border.color: "#40000000" }
                    MouseArea {
                        anchors.fill: parent
                        function set(m) { colorPop.commit(Math.max(0, Math.min(1, m.x / width)), colorPop.sat, colorPop.val); }
                        onPressed: m => set(m); onPositionChanged: m => { if (pressed) set(m); }
                    }
                }
                GField { width: parent.width; th: th; value: colorPop.hex; implicitHeight: 32
                    onEdited: v => { if (/^#[0-9a-fA-F]{6}$/.test(v)) { colorPop.hex = v; if (win._colorCb) win._colorCb(v); } } }
                GButton { th: th; label: I18n.tr("Done"); primary: true; onClicked: colorPop.visible = false }
            }
        }

        // list popup (fonts, long choices)
        Rectangle {
            id: listPop
            property var items: []
            property string current: ""
            property string filter: ""
            visible: false; z: 200
            width: 280; height: 340; radius: 18
            color: th.popup; border.width: 1; border.color: th.line
            Column {
                x: 12; y: 12; width: parent.width - 24; spacing: 8
                GField { width: parent.width; th: th; value: listPop.filter; implicitHeight: 32; onEdited: v => listPop.filter = v }
                ListView {
                    width: parent.width; height: listPop.height - 70; clip: true; boundsBehavior: Flickable.StopAtBounds
                    model: listPop.items.filter(function (it) { return listPop.filter === "" || String(it[1]).toLowerCase().indexOf(listPop.filter.toLowerCase()) >= 0; })
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 30; radius: 8
                        color: lm.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : (modelData[0] === listPop.current ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        Rectangle { visible: modelData.length > 2; x: 8; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 8; color: modelData.length > 2 ? modelData[2] : "transparent"; border.width: 1; border.color: th.line }
                        Text { x: modelData.length > 2 ? 32 : 10; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr(modelData[1]); color: modelData[0] === listPop.current ? th.accent : th.fg; font.family: modelData.length > 2 ? th.font : modelData[1]; font.pixelSize: 14 }
                        MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; onClicked: { if (win._listCb) win._listCb(modelData[0]); listPop.visible = false; } }
                    }
                }
            }
        }
    }
}
