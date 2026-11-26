// The visual editor window.
import QtQuick
import Quickshell
import "../core"
import "../core/Defaults.js" as D

FloatingWindow {
    id: win
    required property var store
    required property var theme
    required property var backend
    required property var wall
    required property var update
    required property var mons                 // Monitors.qml
    signal settingsClose()
    signal identifyRequested()
    onSettingsClose: page = "editor"
    property string page: "editor"              // editor | library | presets | settings
    // short page change: the new page fades in and slides a little from the side it lies on (settings is a dialog, not a page)
    readonly property var pageOrder: ["editor", "library", "presets"]
    property string lastPage: "editor"
    property real pageIn: 1                     // 0 -> 1 while the new page comes in
    property int pageDir: 1
    onPageChanged: {
        var to = pageOrder.indexOf(page), from = pageOrder.indexOf(lastPage);
        if (to < 0) return;
        lastPage = page;
        if (to === from) return;
        pageDir = to > from ? 1 : -1;
        pageAnim.stop(); pageIn = 0;
        Qt.callLater(pageAnim.start);           // after the new page is built, so its first frame is part of the animation
    }
    NumberAnimation { id: pageAnim; target: win; property: "pageIn"; to: 1; duration: 220; easing.type: Easing.OutCubic }
    function showSettings(on) { page = on ? "settings" : "editor"; }
    function scrollSettings(y) { setFlick.contentY = Math.max(0, Math.min(y, setFlick.contentHeight - setFlick.height)); }
    readonly property var selRec: { store.mons; store.selMon; return store.monRec(store.curKey()); }
    MonitorWall { id: swall; wall: win.wall; key: win.store.curKey(); name: win.selRec ? win.selRec.name : "" }   // wallpaper of the edited monitor
    property string sel: ""                  // primary selection (props panel)
    property var sels: []                    // all selected widgets (Shift+click / rubber band)
    property real propsScroll: -1
    property alias propsTab: propsPanel.tab
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
    // Copy / paste the look by keyboard: Ctrl+Shift+C / V and Ctrl+C / V. They are Shortcuts (not keys of one item), so they work whichever item has the focus
    // (after typing in a text field the focus stays there). Ctrl+C / V belong to the text field while a text field has the focus.
    readonly property var focusItem: root.Window.window ? root.Window.window.activeFocusItem : null
    readonly property bool textFocus: focusItem !== null && focusItem !== undefined && focusItem.cursorPosition !== undefined
    readonly property bool editorKeys: page === "editor" && !colorPop.visible && !listPop.visible && !commands.visible
    readonly property bool styleKeysOk: visible && editorKeys && sels.length > 0 && !colorPop.visible && !listPop.visible
    function copyStyleKey() { if (sel !== "" && store.copyStyle(sel)) propsPanel.styleMsg = I18n.tr("Style copied - select another widget and paste it"); }
    function pasteStyleKey() { if (styleKeysOk) pasteStyleToSelection(); }
    // "Paste style": onto every selected widget (or the one in the panel)
    function pasteStyleToSelection() {
        var n = store.pasteStyle(sels.length > 0 ? sels : [sel]);
        propsPanel.styleMsg = n === 1 ? I18n.tr("Style pasted") : I18n.trf("Style pasted to %1 widgets", n);
    }
    function removeSelected() {
        var ids = sels.length > 0 ? sels.slice() : (sel !== "" ? [sel] : []);
        for (var i = 0; i < ids.length; i++) store.remove(ids[i]);
        sels = []; sel = "";
    }

    readonly property alias canvasItem: canvas
    visible: false
    title: "WidgetDeck"
    color: th.bg
    implicitWidth: 1500
    implicitHeight: 920
    minimumSize: Qt.size(1100, 700)

    Theme { id: th; themeStore: win.theme }
    readonly property Theme thm: th

    function addFromLibrary(type, props, size) {
        var id = canvas.addAtFree(type, size);
        if (id === "") return;
        for (var k in props || {}) store.setProp(id, k, props[k]);
        page = "editor"; sel = id;
    }
    function commandList() {
        var out = [
            { name: I18n.tr("Editor"), run: function () { win.page = "editor"; } },
            { name: I18n.tr("Library"), run: function () { win.page = "library"; } },
            { name: I18n.tr("Presets"), run: function () { win.page = "presets"; } },
            { name: I18n.tr("Settings"), run: function () { win.page = "settings"; } },
            { name: I18n.tr("Undo"), run: function () { win.store.undo(); } },
            { name: I18n.tr("Redo"), run: function () { win.store.redo(); } },
            { name: I18n.tr("Show grid"), run: function () { win.store.setGrid("grid", !win.store.grid.grid); } },
            { name: I18n.tr("Snap (grid + guides)"), run: function () { win.store.setGrid("snap", !win.store.grid.snap); } },
            { name: I18n.tr("Align all to the grid"), run: function () { win.store.snapAll(); } }
        ];
        Object.keys(store.allTypes).forEach(function (type) {
            out.push({ name: I18n.trf("Add: %1", I18n.tr(win.store.allTypes[type].label)), run: function () { win.addFromLibrary(type); } });
        });
        return out;
    }
    function openCommands() { colorPop.visible = false; listPop.visible = false; commands.commands = commandList(); commands.open(); }

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
            if (splashLoader.item) { splashLoader.item.skip(); event.accepted = true; return; }
            if (event.key === Qt.Key_Escape) { if (colorPop.visible || listPop.visible) { colorPop.visible = false; listPop.visible = false; } else if (win.page !== "editor") win.page = "editor"; else win.visible = false; event.accepted = true; return; }
            if (win.sels.length === 0 || !win.editorKeys) return;
            // arrow keys: one grid cell (Shift: five cells), for the whole selection; Delete removes the selection
            var st = (event.modifiers & Qt.ShiftModifier) ? 5 : 1;
            if (event.key === Qt.Key_Delete) { win.removeSelected(); event.accepted = true; }
            else if (event.key === Qt.Key_Left)  { canvas.nudge(-st, 0); event.accepted = true; }
            else if (event.key === Qt.Key_Right) { canvas.nudge(st, 0); event.accepted = true; }
            else if (event.key === Qt.Key_Up)    { canvas.nudge(0, -st); event.accepted = true; }
            else if (event.key === Qt.Key_Down)  { canvas.nudge(0, st); event.accepted = true; }
        }

        Shortcut { sequence: "Ctrl+Shift+C"; enabled: win.styleKeysOk; onActivated: win.copyStyleKey() }
        Shortcut { sequence: "Ctrl+Shift+V"; enabled: win.styleKeysOk; onActivated: win.pasteStyleKey() }
        Shortcut { sequence: "Ctrl+C"; enabled: win.styleKeysOk && !win.textFocus; onActivated: win.copyStyleKey() }
        Shortcut { sequence: "Ctrl+V"; enabled: win.styleKeysOk && !win.textFocus; onActivated: win.pasteStyleKey() }

        Shortcut { sequence: "Ctrl+K"; enabled: win.visible; onActivated: commands.visible ? commands.close() : win.openCommands() }
        Shortcut { sequence: "Ctrl+Z"; enabled: win.visible && !win.textFocus && !commands.visible; onActivated: win.store.undo() }
        Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; enabled: win.visible && !win.textFocus && !commands.visible; onActivated: win.store.redo() }

        // header (drag area): name, pages, command search, undo / redo, close
        Item {
            id: header
            x: 10; y: 0; width: root.width - 20; height: 60
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => { if (typeof win.startSystemMove === "function") win.startSystemMove(); }
            }
            Text { x: 14; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.StyledText; color: th.fg; font.family: th.font; font.pixelSize: 17; font.bold: true
                text: "Widget<font color=\"" + th.accent + "\">Deck</font>" }
            Row {
                x: 220; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Repeater {
                    model: [["editor", I18n.tr("Editor")], ["library", I18n.tr("Library")], ["presets", I18n.tr("Presets")]]
                    delegate: GButton {
                        required property var modelData
                        th: win.thm; label: modelData[1]; implicitHeight: 34
                        checked: win.page === modelData[0]
                        color: checked ? th.selected : "transparent"; border.color: "transparent"
                        onClicked: win.page = modelData[0]
                    }
                }
            }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                GButton { th: win.thm; implicitHeight: 34; width: 230; label: I18n.tr("Search or command…") + "   Ctrl+K"; onClicked: win.openCommands() }
                GButton { th: win.thm; implicitHeight: 34; width: 34; pad: 0; label: "↶"; enabled: win.store.undoStack.length > 0; opacity: enabled ? 1 : 0.38; onClicked: win.store.undo() }
                GButton { th: win.thm; implicitHeight: 34; width: 34; pad: 0; label: "↷"; enabled: win.store.redoStack.length > 0; opacity: enabled ? 1 : 0.38; onClicked: win.store.redo() }
                GButton {
                    th: win.thm; implicitHeight: 34; width: 34; pad: 0; checked: win.page === "settings"
                    onClicked: win.page = "settings"
                    Icon { anchors.centerIn: parent; width: 18; height: 18; name: "gear"; color: th.fg }
                }
                GButton { th: win.thm; implicitHeight: 34; width: 34; pad: 0; label: "✕"; danger: true; onClicked: win.visible = false }
            }
        }

        Item {
            id: body
            x: 10; y: 60; width: root.width - 20; height: root.height - 92
            readonly property real leftW: 210
            readonly property real rightW: 332

            // ── editor ──
            Item {
                anchors.fill: parent
                visible: win.page === "editor" || win.page === "settings"
                opacity: win.pageIn; transform: Translate { x: (1 - win.pageIn) * 28 * win.pageDir }
                Rectangle {
                    width: body.leftW; height: body.height; radius: th.cardRadius; color: th.card
                    WidgetPalette {
                        anchors.fill: parent; anchors.margins: 14
                        store: win.store; th: win.thm; sel: win.sel
                        onAddRequested: win.page = "library"
                        onLayerPicked: id => { var c = win.store.raw(id); if (c && win.store.monRec(win.store.homeKey(c))) win.store.selMon = win.store.homeKey(c); win.sel = id; }
                    }
                }
                Rectangle {
                    x: body.leftW + 10; width: body.width - body.leftW - body.rightW - 20; height: body.height
                    radius: th.cardRadius; color: th.well
                    // several monitors: pick the one you edit; with one monitor none of this exists
                    MonitorStrip { id: strip; visible: win.store.multi; x: 12; y: 10; width: parent.width - 24; height: visible ? 40 : 0; clip: true
                        store: win.store; th: win.thm; mons: win.mons; onIdentify: win.identifyRequested() }
                    StageCanvas {
                        id: canvas
                        anchors.fill: parent; anchors.margins: 12; anchors.topMargin: win.store.multi ? 60 : 12
                        store: win.store; theme: win.theme; th: win.thm; backend: win.backend; wall: swall
                        screenSize: win.store.screen; sel: win.sel; sels: win.sels
                        onSelectionRequested: (ids, primary) => win.selectIds(ids, primary)
                    }
                    // a monitor without any widget (new / unknown monitor): offer to take the layout of another one
                    Rectangle {
                        id: emptyHint
                        readonly property var donors: {
                            win.store.rev; win.store.mons; win.store.selMon;
                            var out = [], k = win.store.curKey(), l = win.store.mons;
                            for (var i = 0; i < l.length; i++) {
                                if (l[i].key === k) continue;
                                var n = win.store.data.widgets.filter(function (w) { return win.store.homeKey(w) === l[i].key && w.monitor !== "all"; }).length;
                                if (n > 0) out.push({ key: l[i].key, name: l[i].name, n: n });
                            }
                            return out;
                        }
                        readonly property var thm: win.thm
                        visible: win.store.multi && win.store.stageIds.length === 0 && donors.length > 0
                        z: 5
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 18 }
                        width: hintCol.width + 28; height: hintCol.height + 22; radius: 14
                        color: th.popup; border.width: 1; border.color: th.line
                        Column {
                            id: hintCol
                            anchors.centerIn: parent; spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter; color: th.fg; font.family: th.font; font.pixelSize: 13; text: I18n.tr("This monitor has no widgets yet.") }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                                Repeater {
                                    model: emptyHint.donors
                                    delegate: GButton { required property var modelData; th: emptyHint.thm; label: I18n.trf("Take the layout of %1", modelData.name); onClicked: win.store.transferLayout(modelData.key, win.store.curKey()) }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    x: body.width - body.rightW; width: body.rightW; height: body.height; radius: th.cardRadius; color: th.card
                    PropsPanel {
                        id: propsPanel
                        anchors.fill: parent; anchors.margins: 14; anchors.rightMargin: 4
                        store: win.store; th: win.thm; sel: win.sel; scrollRequest: win.propsScroll
                        wtheme: win.theme; backend: win.backend; wall: swall
                        onRemoveRequested: win.removeSelected()
                        onDuplicateRequested: win.sel = win.store.duplicate(win.sel)
                        onCopyStyleRequested: win.copyStyleKey()
                        onPasteStyleRequested: win.pasteStyleToSelection()
                    }
                }
            }

            // ── library / presets: only built while shown (their live previews run data feeds) ──
            Loader {
                anchors { fill: parent; margins: 6 }
                active: win.visible && win.page === "library"
                opacity: win.pageIn; transform: Translate { x: (1 - win.pageIn) * 28 * win.pageDir }
                sourceComponent: Library { store: win.store; th: win.thm; theme: win.theme; backend: win.backend; wall: swall; onAddRequested: (type, props, size) => win.addFromLibrary(type, props, size) }
            }
            Loader {
                anchors { fill: parent; margins: 6 }
                active: win.visible && win.page === "presets"
                opacity: win.pageIn; transform: Translate { x: (1 - win.pageIn) * 28 * win.pageDir }
                sourceComponent: PresetsPage { store: win.store; th: win.thm; theme: win.theme; backend: win.backend; wall: swall }
            }
        }

        // footer: state of the grid, widget count, version
        Row {
            x: 24; y: root.height - 24; spacing: 22
            readonly property string c: th.dim
            Text { text: I18n.trf("Grid %1 px", win.store.grid.cell); color: parent.c; font.family: th.font; font.pixelSize: 11 }
            Text { text: win.store.grid.snap ? I18n.tr("Snap on") : I18n.tr("Snap off"); color: parent.c; font.family: th.font; font.pixelSize: 11 }
            Text { text: I18n.trf("%1 widgets", win.store.widgetIds.length); color: parent.c; font.family: th.font; font.pixelSize: 11 }
            Text { visible: win.page === "editor"; text: I18n.tr("Drag widgets (grid + guides, Alt = free), Shift = multi-select - changes appear live on the desktop"); color: parent.c; font.family: th.font; font.pixelSize: 11 }
        }
        Text { anchors { right: parent.right; rightMargin: 24 } y: root.height - 24; visible: win.update.version !== ""; text: "v" + win.update.version; color: th.dim; font.family: th.font; font.pixelSize: 11 }

        // ── settings: a dialog over the dimmed editor ──
        Rectangle {
            id: settingsLayer
            visible: win.page === "settings"; z: 100
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)
            MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: win.page = "editor"; onWheel: wheel => wheel.accepted = true }
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 980); height: parent.height - 60
                radius: th.cardRadius; color: th.card; border.width: 1; border.color: th.line
                MouseArea { anchors.fill: parent }

                // head: accent line, mark, title and version
                Rectangle {
                    id: setHead
                    x: 1; y: 1; width: parent.width - 2; height: 82
                    topLeftRadius: th.cardRadius - 1; topRightRadius: th.cardRadius - 1
                    color: Qt.tint(th.card, Qt.rgba(th.accent.r, th.accent.g, th.accent.b, 0.10))
                    Rectangle { x: th.cardRadius; width: parent.width - 2 * th.cardRadius; height: 3; radius: 2; color: th.accent }
                    Rectangle {
                        id: mark
                        x: 24; anchors.verticalCenter: parent.verticalCenter; width: 44; height: 44; radius: 13; color: th.accent
                        Text { anchors.centerIn: parent; text: "W"; color: th.onAccent; font.family: th.font; font.pixelSize: 25; font.weight: Font.Black; renderType: Text.QtRendering }
                    }
                    Column {
                        x: mark.x + mark.width + 16; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                        Text { text: I18n.tr("Settings"); color: th.fg; font.family: th.font; font.pixelSize: 24; font.bold: true }
                        Text { text: ("WidgetDeck " + win.update.version).toUpperCase(); color: th.dim; font.family: th.font; font.pixelSize: 11; font.letterSpacing: 2 }
                    }
                    GButton { anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter } th: win.thm; width: 34; implicitHeight: 34; pad: 0; label: "✕"; onClicked: win.page = "editor" }
                }

                Flickable {
                    id: setFlick
                    anchors { left: parent.left; right: parent.right; top: setHead.bottom; bottom: setFoot.top; leftMargin: 20; rightMargin: 20 }
                    contentHeight: setCol.height + 36; clip: true; boundsBehavior: Flickable.StopAtBounds
                    SettingsPanel {
                        id: setCol
                        y: 18; width: setFlick.width - 12; height: implicitHeight
                        store: win.store; theme: win.theme; wall: win.wall; backend: win.backend; update: win.update; th: win.thm
                        mons: win.mons; liquidOk: win.backend.ready && swall.usable
                        onPickWallpaper: { wallPicker.startPath = ""; wallPicker.open(); }
                        onRunWizard: { win.settingsClose(); win.store.setConfig("setup.done", false); }
                    }
                }
                Rectangle {                                       // scroll position
                    x: parent.width - 11; width: 4; radius: 2; color: th.accent; opacity: 0.7
                    visible: setFlick.contentHeight > setFlick.height
                    y: setFlick.y + setFlick.visibleArea.yPosition * setFlick.height
                    height: setFlick.visibleArea.heightRatio * setFlick.height
                }

                Item {
                    id: setFoot
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 62
                    Rectangle { width: parent.width; height: 1; color: th.line }
                    GButton { x: 20; anchors.verticalCenter: parent.verticalCenter; th: win.thm; implicitHeight: 34; label: I18n.tr("Run the setup assistant again"); onClicked: setCol.runWizard() }
                    GButton { anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter } th: win.thm; implicitHeight: 34; pad: 26; primary: true; label: I18n.tr("Done"); onClicked: win.page = "editor" }
                }
            }
        }

        CommandPalette { id: commands; z: 250; anchors.fill: parent; th: win.thm }

        // start animation: only built when it is switched on, gone after it ran
        Loader {
            id: splashLoader
            anchors.fill: parent; z: 500
            property bool done: false
            active: !done && win.store.loaded && win.store.builder.splash !== false
            sourceComponent: Splash {
                th: win.thm; ready: win.store.loaded && win.store.monsReady
                onFinished: splashLoader.done = true
                // a short moment for the window to appear, so the animation is seen from its first frame
                Timer { interval: 90; running: true; onTriggered: parent.start() }
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
