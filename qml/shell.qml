// WidgetDeck - desktop widgets + visual builder, one Quickshell process.
//   qs -p ~/widgetdeck/qml                      start (autostarted by Hyprland)
//   qs -p ~/widgetdeck/qml ipc call widgetdeck toggleBuilder
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "core"
import "widgets"
import "builder"

ShellRoot {
    id: shell

    Store { id: theStore }
    ThemeStore { id: theTheme; store: theStore }
    GlassBackend { id: theBackend }
    Wallpaper { id: theWall; override: theStore.data.wallpaperPath || "" }

    readonly property var screenObj: {
        var s = Quickshell.screens, want = theStore.data.monitor;
        for (var i = 0; i < s.length; i++) if (s[i].name === want) return s[i];
        return s.length > 0 ? s[0] : null;
    }
    readonly property size screenSize: screenObj ? Qt.size(screenObj.width, screenObj.height) : Qt.size(2560, 1600)

    // ───────────── desktop widgets: one layer-shell surface per widget, BELOW all windows ─────────────
    // frosted and liquid widgets live in different namespaces (see DesktopWidget.qml)
    readonly property var frostedIds: { theStore.rev; return theStore.widgetIds.filter(function (id) { return theStore.styleOf(id).mode !== "liquid" || !theBackend.ready; }); }
    readonly property var liquidIds: { theStore.rev; return theStore.widgetIds.filter(function (id) { return theStore.styleOf(id).mode === "liquid" && theBackend.ready; }); }

    Variants {
        model: (theStore.loaded && shell.screenObj) ? shell.frostedIds : []
        DesktopWidget { required property string modelData; wid: modelData; ns: "widgetdeck"
            store: theStore; theme: theTheme; backend: theBackend; wall: theWall; screenObj: shell.screenObj; screenSize: shell.screenSize }
    }
    Variants {
        model: (theStore.loaded && shell.screenObj) ? shell.liquidIds : []
        DesktopWidget { required property string modelData; wid: modelData; ns: "widgetdeck-liquid"
            store: theStore; theme: theTheme; backend: theBackend; wall: theWall; screenObj: shell.screenObj; screenSize: shell.screenSize }
    }

    Builder {
        id: builderWin
        store: theStore; theme: theTheme; backend: theBackend; wall: theWall
        screenSize: shell.screenSize
    }

    // ───────────── usable area of the monitor (for the snap grid) ─────────────
    // = the monitor minus the zones other layer-shell surfaces reserve (the top bar), from hyprctl. Logical px of THIS monitor,
    // absolute from its top-left corner; refreshed at start, when the screen changes and every 4 s while the builder is open.
    Process {
        id: monProc
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector { onStreamFinished: shell.applyMonitors(text) }
    }
    function applyMonitors(t) {
        var so = shell.screenObj; if (!so) return;
        var W = so.width, H = so.height, res = [0, 0, 0, 0];
        try {
            var a = JSON.parse(t);
            for (var i = 0; i < a.length; i++) if (a[i].name === so.name && a[i].reserved) res = a[i].reserved;
        } catch (e) { }
        theStore.setArea(W, H, res[0], res[1], Math.max(100, W - res[0] - res[2]), Math.max(100, H - res[1] - res[3]));
    }
    function refreshArea() { if (!monProc.running) monProc.running = true; }
    Timer { interval: 4000; repeat: true; running: builderWin.visible; triggeredOnStart: true; onTriggered: shell.refreshArea() }
    onScreenSizeChanged: Qt.callLater(refreshArea)
    Component.onCompleted: Qt.callLater(refreshArea)
    Connections { target: theStore; function onLoadedChanged() { if (theStore.loaded) shell.refreshArea(); } }

    Timer {
        id: simDragger
        interval: 6; repeat: true
        property string wid: ""; property real amp: 200; property real t0: 0; property real dur: 2000; property point p0
        function start(id, a, ms) {
            var c = theStore.cfg(id); if (!c) return;
            wid = id; amp = a; dur = ms; p0 = Qt.point(c.x + c.w * 0.3, c.y + c.h * 0.3);
            builderWin.canvasItem.pressAt(p0.x, p0.y, 0);
            t0 = Date.now(); running = true;
        }
        onTriggered: {
            var t = (Date.now() - t0) / dur;
            if (t >= 1) { running = false; builderWin.canvasItem.release(); return; }
            builderWin.canvasItem.moveTo(p0.x + amp * Math.sin(t * Math.PI * 4), p0.y + amp * 0.5 * Math.sin(t * Math.PI * 6), 0);
        }
    }

    Connections {
        target: theTheme
        function onWallpaperPaletteChanged() { theWall.refresh(); lateWall.restart(); }
    }
    Timer { id: lateWall; interval: 1500; onTriggered: theWall.refresh() }

    IpcHandler {
        target: "widgetdeck"
        function openBuilder(): void { builderWin.visible = true; }
        function closeBuilder(): void { builderWin.visible = false; }
        function toggleBuilder(): void { builderWin.visible = !builderWin.visible; }
        function reloadWallpaper(): void { theWall.refresh(); }
        function ping(): string { return "pong"; }
        // automation: qs -p ~/widgetdeck/qml ipc call widgetdeck <fn> ...
        function list(): string { return JSON.stringify(theStore.data.widgets.map(function (w) { return w.id + " " + w.type + " " + w.x + "," + w.y; })); }
        function select(id: string): void { builderWin.sel = id; }
        function geom(id: string, x: int, y: int, w: int, h: int): void { theStore.setGeom(id, { x: x, y: y, w: w, h: h }); }
        function setProp(id: string, key: string, json: string): void { theStore.setProp(id, key, JSON.parse(json)); }
        function scrollProps(y: real): void { builderWin.propsScroll = y; }
        function style(id: string, key: string, json: string): void { theStore.setStyle(id, key, JSON.parse(json)); }
        function builderGlass(mode: string): void { theStore.setBuilder("glass", mode); }
        function reloadLayout(): void { theStore.scanPlugins(); }
        function themeInfo(): string { return JSON.stringify({ enabled: theTheme.enabled, mode: theTheme.mode, scheme: theTheme.scheme, source: theTheme.sourceColor, primary: theTheme.resolve("theme:primary"), on_surface: theTheme.resolve("theme:on_surface") }); }
        function setTheme(key: string, json: string): void { theStore.setBuilder(key, JSON.parse(json)); }
        function regenerate(): void { theTheme.regenerate(theWall.path); }
        // ── snap grid / edit mode automation ──
        function areaInfo(): string { return JSON.stringify({ screen: [theStore.screen.width, theStore.screen.height], area: [theStore.area.x, theStore.area.y, theStore.area.width, theStore.area.height], grid: theStore.grid }); }
        function layoutInfo(): string { return JSON.stringify(theStore.data.widgets.map(function (w) { return { id: w.id, type: w.type, x: w.x, y: w.y, w: w.w, h: w.h, mode: (w.style || {}).mode || "frosted" }; })); }
        function setGrid(key: string, json: string): void { theStore.setGrid(key, JSON.parse(json)); }
        function snapAll(): void { theStore.snapAll(); }
        function resetLayout(): void { theStore.resetLayout(); }
        function clamp(): string { return String(theStore.clampAll()); }
        function selectMany(ids: string): void { var a = ids.length > 0 ? ids.split("|") : []; builderWin.selectIds(a, a.length ? a[a.length - 1] : ""); }
        function alignSel(kind: string): void { builderWin.canvasItem.alignSel(kind); }
        function distributeSel(axis: string): void { builderWin.canvasItem.distributeSel(axis === "y"); }
        function nudge(dx: int, dy: int): void { builderWin.canvasItem.nudge(dx, dy); }
        function addWidget(type: string): string { var id = builderWin.canvasItem.addAtFree(type); builderWin.sel = id; return id; }
        function removeWidget(id: string): void { theStore.remove(id); builderWin.sel = ""; }
        function stageInfo(): string { var g = builderWin.canvasItem.stageGeom(); return JSON.stringify({ x: g.x, y: g.y, zoom: g.zoom, sel: builderWin.sels, visible: builderWin.visible }); }
        function sels(): string { return JSON.stringify(builderWin.sels); }
        function refreshArea(): void { shell.refreshArea(); }
        function settingsPanel(on: bool): void { builderWin.showSettings(on); }
        // drive the stage exactly like the mouse does (same functions); x / y in desktop px, mods bit 1 = Shift, bit 2 = Alt
        function dragStart(x: real, y: real, mods: int): void { builderWin.canvasItem.pressAt(x, y, (mods & 1 ? Qt.ShiftModifier : 0) | (mods & 2 ? Qt.AltModifier : 0)); }
        function dragMove(x: real, y: real, mods: int): void { builderWin.canvasItem.moveTo(x, y, (mods & 1 ? Qt.ShiftModifier : 0) | (mods & 2 ? Qt.AltModifier : 0)); }
        function dragEnd(): void { builderWin.canvasItem.release(); }
        // perf test: a drag driven by an in-process timer at display rate (no process spawn per step). Moves the widget `id` along a
        // sine path of `amp` px for `ms` milliseconds through the same pressAt / moveTo / release functions.
        function simDrag(id: string, amp: real, ms: int): void { simDragger.start(id, amp, ms); }
        function dragState(): string { var c = builderWin.canvasItem; return JSON.stringify({ invalid: c.invalid, guides: c.guides, gaps: c.gaps, mode: c.drag ? c.drag.mode : "" }); }
    }
}
