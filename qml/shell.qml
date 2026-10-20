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
import "modules"
import "wizard"

ShellRoot {
    id: shell

    Store { id: theStore }
    ThemeStore { id: theTheme; store: theStore }
    GlassBackend { id: theBackend }
    UpdateCheck { id: theUpdate; store: theStore }
    Wallpaper { id: theWall; override: theStore.data.wallpaperPath || ""; extra: theStore.data.wallpapers || ({}) }

    // ───────────── monitors ─────────────
    // every connected, active, non-mirrored monitor with a stable key (core/Monitors.qml); plug / unplug is noticed live
    Monitors { id: theMons; preferredPrimary: theStore.cget("monitors.primary", "") }
    function pushMonitors() { theStore.setMonitors(theMons.list, theMons.primaryKey); }
    Connections { target: theMons; function onListChanged() { shell.pushMonitors(); } function onPrimaryKeyChanged() { shell.pushMonitors(); } }
    Connections { target: theStore; function onConfigLoadedChanged() { if (theStore.configLoaded) shell.pushMonitors(); } }
    Timer { interval: 4000; repeat: true; running: builderWin.visible; onTriggered: theMons.refresh() }          // reserved areas (a bar appearing) while editing
    // modules (config.json "modules"): widgets + builder on by default, bar + notifications off
    readonly property bool modWidgets: theStore.cget("modules.widgets", true)
    readonly property bool modBuilder: theStore.cget("modules.builder", true)
    readonly property bool modBar: theStore.configLoaded && theStore.cget("modules.bar", false)
    readonly property bool modNotify: theStore.configLoaded && theStore.cget("modules.notifications", false)

    // ───────────── desktop widgets: one layer-shell surface per widget, BELOW all windows ─────────────
    // frosted and liquid widgets live in different namespaces (see DesktopWidget.qml)
    // Liquid Glass needs the shader AND a wallpaper picture to refract; otherwise every widget is drawn Frosted
    readonly property bool liquidOk: theBackend.ready && theWall.usable
    // one window per widget AND monitor ("<id>|<monitor key>"); a widget that is not assigned to a monitor has no window anywhere (nothing hidden)
    readonly property var instList: { theStore.rev; theStore.mons; theStore.primaryKey; theStore.configRev; return theStore.monsReady ? theStore.instances() : []; }
    function liquidInst(inst) {
        var id = inst.split("|")[0], key = inst.substring(inst.indexOf("|") + 1), m = theStore.monRec(key);
        theWall.outputs; theWall.extra; theWall.extraOk; theWall.detected;
        return theStore.styleOf(id).mode === "liquid" && theBackend.ready && !!m && (theStore.data.wallpaperPath ? theWall.usable : theWall.usableFor(key, m.name));
    }
    readonly property var frostedInst: instList.filter(function (i) { return !shell.liquidInst(i); })
    readonly property var liquidInst_: instList.filter(function (i) { return shell.liquidInst(i); })

    Variants {
        model: (theStore.loaded && theStore.monsReady && shell.modWidgets) ? shell.frostedInst : []
        DesktopWidget { required property string modelData; inst: modelData; ns: "widgetdeck"
            store: theStore; theme: theTheme; backend: theBackend; wall: theWall; mons: theMons }
    }
    Variants {
        model: (theStore.loaded && theStore.monsReady && shell.modWidgets) ? shell.liquidInst_ : []
        DesktopWidget { required property string modelData; inst: modelData; ns: "widgetdeck-liquid"
            store: theStore; theme: theTheme; backend: theBackend; wall: theWall; mons: theMons }
    }

    Binding { target: I18n; property: "setting"; value: theStore.cget("language", "auto") }

    Wizard { id: setupWizard; store: theStore; theme: theTheme; wall: theWall; liquidOk: shell.liquidOk; shaderOk: theBackend.ready }
    // "Show monitors": a big number and the name on every monitor for a few seconds
    Identify { id: identify; mons: theMons; secs: theStore.cget("monitors.identify_secs", 3) }

    Builder {
        id: builderWin
        store: theStore; theme: theTheme; backend: theBackend; wall: theWall; update: theUpdate
        mons: theMons
        onIdentifyRequested: identify.show()
    }

    // ───────────── optional modules ─────────────
    // Variants (not LazyLoader): a module that is switched off is really destroyed - the notification service gives its D-Bus name back
    Variants { id: barLoader; model: shell.modBar ? [1] : []
        Bar { required property var modelData; theme: theTheme; store: theStore; mons: theMons; onPowerRequested: name => shell.togglePower(name) } }
    Variants { id: notifyLoader; model: shell.modNotify ? [1] : []
        Notifications { required property var modelData; theme: theTheme; store: theStore; mons: theMons } }
    Variants { id: powerLoader; model: (shell.modBar || shell.modNotify) ? [1] : []
        PowerPanel { required property var modelData; theme: theTheme; store: theStore; mons: theMons } }
    function moduleItem(v) { return v.instances.length > 0 ? v.instances[0] : null; }
    function togglePower(name) { var p = moduleItem(powerLoader); if (p) p.toggle(name || ""); }

    function refreshArea() { theMons.refresh(); }
    Component.onCompleted: Qt.callLater(pushMonitors)
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
        function openBuilder(): void { if (shell.modBuilder) builderWin.visible = true; }
        function closeBuilder(): void { builderWin.visible = false; }
        function toggleBuilder(): void { if (shell.modBuilder) builderWin.visible = !builderWin.visible; else builderWin.visible = false; }
        // modules: ipc call widgetdeck setModule bar on   (names: widgets builder bar notifications)
        function setModule(name: string, state: string): string {
            if (["widgets", "builder", "bar", "notifications"].indexOf(name) < 0) return "unknown module " + name;
            if (state === "on" || state === "off") theStore.setConfig("modules." + name, state === "on");
            return name + "=" + theStore.cget("modules." + name, false);
        }
        function powerPanel(): string { var p = shell.moduleItem(powerLoader); if (p) { p.toggle(""); return "ok"; } return "disabled: enable the bar or notifications module"; }
        function dismissNotifications(): string { var n = shell.moduleItem(notifyLoader); if (n) { n.dismissAll(); return "ok"; } return "disabled"; }
        function toggleDnd(): string { var n = shell.moduleItem(notifyLoader); if (n) { n.dnd = !n.dnd; return n.dnd ? "dnd on" : "dnd off"; } return "disabled"; }
        function wallpaperInfo(): string { return JSON.stringify({ path: theWall.path, usable: theWall.usable, tool: theWall.tool, manual: theWall.override !== "", liquidOk: shell.liquidOk }); }
        function animateSize(id: string, which: string): string { var sz = theStore.sizeFor(id, which); if (!sz) return "no such size"; theStore.animateGeom(id, sz, 320); return "ok"; }
        function wizard(): void { theStore.setConfig("setup.done", false); }
        function wizardStep(n: int): void { setupWizard.step = n; }
        function wizardPick(json: string): void { setupWizard.apply(JSON.parse(json)); }
        function wizardFinish(): void { setupWizard.finish(false); }
        function version(): string { return theUpdate.version; }
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
        // ── monitors ──
        function monitors(): string { return JSON.stringify(theMons.list.map(function (m) { return { key: m.key, name: m.name, x: m.x, y: m.y, w: m.w, h: m.h, scale: m.scale, refresh: m.refresh, transform: m.transform, vertical: m.vertical, primary: m.key === theMons.primaryKey, area: [m.area.x, m.area.y, m.area.width, m.area.height] }; })); }
        function selectMonitor(key: string): void { theStore.selMon = key; }
        function setMonitor(id: string, value: string): void { theStore.setMonitor(id, value); }
        function copyToMonitor(id: string, key: string): string { return theStore.copyToMonitor(id, key); }
        function transferLayout(from: string, to: string): string { return String(theStore.transferLayout(from, to)); }
        function resetAllLayouts(): void { theStore.resetAllLayouts(); }
        function setMonitorWallpaper(key: string, path: string): void { var w = Object.assign({}, theStore.data.wallpapers || {}); if (path) w[key] = path; else delete w[key]; theStore.data.wallpapers = w; theStore.touch(false); }
        function setWallpaperPath(path: string): void { theStore.data.wallpaperPath = path; theStore.touch(false); }
        function setBarMonitors(keys: string): void { theStore.setConfig("monitors.bar", keys === "all" ? "all" : keys.split("|")); }
        function setHidden(id: string, hidden: bool): void { theStore.setHidden(id, hidden); }
        function setConfigValue(key: string, json: string): void { theStore.setConfig(key, JSON.parse(json)); }
        function instances(): string { return JSON.stringify(theStore.instances()); }
        function identifyMonitors(): void { identify.show(); }
        function feeds(): string { return JSON.stringify(Feeds.info()); }
        function setMonGrid(key: string, k: string, json: string): void { theStore.setMonGrid(key, k, JSON.parse(json)); }
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
        function scrollSettings(y: real): void { builderWin.scrollSettings(y); }
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
