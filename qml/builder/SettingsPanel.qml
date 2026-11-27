// The settings column of the builder: grid, monitor, modules, location & units, theme, glass background, version & updates, assistant.
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/Geo.js" as Geo
import "../core/Defaults.js" as D

Item {
    id: sp
    required property var store
    required property var theme
    required property var wall
    required property var backend
    required property var update
    required property var th
    required property var mons
    property bool liquidOk: false
    property bool ttKey: false
    readonly property string ttDir: decodeURIComponent(Qt.resolvedUrl("../widgets/timetable/").toString().replace("file://", ""))
    function runSetup(arg) {
        var p = Quickshell.env("HOME") + "/.local/bin/widgetdeck-untis-setup";
        Quickshell.execDetached(["sh", "-c", "exec \"$1\" $2 --terminal 2>/dev/null || exec widgetdeck-untis-setup --terminal", "sh", p, arg]);
        ttRecheck.restart();
    }
    Process { id: ttProc; command: ["python3", "-I", sp.ttDir + "untis.py", "doctor"]
        stdout: StdioCollector { onStreamFinished: sp.ttKey = /^key: yes/m.test(this.text) } }
    Timer { id: ttRecheck; interval: 15000; onTriggered: ttProc.running = true }
    signal pickWallpaper()
    signal runWizard()
    readonly property bool twoCols: width >= 700
    implicitHeight: twoCols ? Math.max(leftCol.height, rightCol.height) : leftCol.height + 14 + rightCol.height
    property string allMsg: ""
    component Section: Text { topPadding: 8; color: sp.th.dim; font.family: sp.th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.6 }
    component Note: Text { width: parent.width; wrapMode: Text.WordWrap; color: sp.th.dim; font.family: sp.th.font; font.pixelSize: 11 }
    // one boxed group with a spaced heading
    component Card: Rectangle {
        property string title: ""
        default property alias content: inner.data
        width: parent.width
        height: inner.height + 32
        radius: 14; color: sp.th.well; border.width: 1; border.color: sp.th.line
        Column {
            id: inner
            x: 16; y: 16; width: parent.width - 32; spacing: 8
            Text { text: title.toUpperCase(); color: sp.th.dim; font.family: sp.th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2; bottomPadding: 4 }
        }
    }
    function cfgStr(k, d) { var v = store.cget(k, d); return v === null ? "" : String(v); }
    readonly property bool multi: store.multi
    readonly property string ck: { store.mons; store.selMon; return store.curKey(); }
    readonly property var cmon: { store.mons; return store.monRec(sp.ck); }
    function monOpts(extra) {
        var o = extra ? extra.slice() : [], l = store.mons;
        for (var i = 0; i < l.length; i++) o.push([l[i].key, (i + 1) + "  " + l[i].name + "  (" + l[i].w + "×" + l[i].h + ")"]);
        return o;
    }
    Component.onCompleted: { ttProc.running = true; theme.scan(); }
    property bool latBad: false
    property bool lonBad: false
    function setCoord(key, text, max) {          // empty removes it; unusable input keeps the stored value and returns false
        if (text.trim() === "") { store.setConfig(key, null); return true; }
        var n = Geo.parseCoord(text, max);
        if (isNaN(n)) return false;
        store.setConfig(key, n);
        return true;
    }

    Column {
        id: leftCol
        width: sp.twoCols ? (sp.width - 14) / 2 : sp.width
        spacing: 14
        Card { title: I18n.tr("LOCATION & UNITS")
        Note { text: I18n.tr("For weather and air quality. With 'automatic' your IP address is sent once to ipwho.is (the result is kept for a week); your own coordinates take priority. Open-Meteo only receives coordinates.") }
        GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Locate automatically (IP address)"); checked: sp.store.cget("location.auto", true); onToggled: v => sp.store.setConfig("location.auto", v) }
        GField {
            width: parent.width; th: sp.th; label: I18n.tr("Latitude (e.g. 48.2082, empty = automatic)"); value: sp.cfgStr("location.lat", "")
            onCommitted: v => sp.latBad = !sp.setCoord("location.lat", v, 90)
        }
        GField {
            width: parent.width; th: sp.th; label: I18n.tr("Longitude (e.g. 16.3738)"); value: sp.cfgStr("location.lon", "")
            onCommitted: v => sp.lonBad = !sp.setCoord("location.lon", v, 180)
        }
        Note { visible: sp.latBad || sp.lonBad; text: I18n.tr("Not saved: latitude must be -90 to 90, longitude -180 to 180.") }
        GField { width: parent.width; th: sp.th; label: I18n.tr("Place name (display only)"); value: sp.cfgStr("location.name", ""); onCommitted: v => sp.store.setConfig("location.name", v) }
        GChoice { width: parent.width; th: sp.th; label: I18n.tr("Units"); options: [["auto", I18n.tr("From system")], ["metric", "°C, m/s"], ["imperial", "°F, mph"]]; value: sp.store.cget("units", "auto"); onPicked: v => sp.store.setConfig("units", v) }
        GChoice { width: parent.width; th: sp.th; label: I18n.tr("Clock"); options: [["auto", I18n.tr("From system")], ["24h", "24 h"], ["12h", "12 h"]]; value: sp.store.cget("time_format", "auto"); onPicked: v => sp.store.setConfig("time_format", v) }
        GChoice { width: parent.width; th: sp.th; label: I18n.tr("Language"); options: [["auto", I18n.tr("From system")], ["en", "English"], ["de", "Deutsch"]]; value: sp.store.cget("language", "auto"); onPicked: v => sp.store.setConfig("language", v) }
        }
        Card { title: I18n.tr("COLOURS")
        GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Theme active (follows the wallpaper)"); checked: sp.theme.enabled; onToggled: v => sp.store.setBuilder("themeEnabled", v) }
        Column {
            visible: sp.theme.enabled; width: parent.width; spacing: 8
            GChoice {
                width: parent.width; th: sp.th; label: I18n.tr("Colour source")
                options: {
                    var o = [["auto", I18n.tr("Automatic")]];
                    sp.theme.known.forEach(function (k) { if (sp.theme.found.indexOf(k.id) >= 0 || sp.theme.source === k.id) o.push([k.id, k.name]); });
                    o.push(["wallpaper", I18n.tr("From the wallpaper")], ["file", I18n.tr("Own file")]);
                    return o;
                }
                value: sp.theme.source
                onPicked: v => sp.store.setBuilder("themeSource", v)
            }
            Note { text: I18n.trf("In use: %1", I18n.tr(sp.theme.sourceName(sp.theme.activeSource))) }
            GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Neutral grey background, only accents follow"); checked: sp.theme.neutral; onToggled: v => sp.store.setBuilder("neutralSurfaces", v) }
            GField {
                visible: sp.theme.source === "file"; width: parent.width; th: sp.th; label: I18n.tr("Colour file (JSON)")
                value: sp.store.builder.themeFile || ""
                onCommitted: v => sp.store.setBuilder("themeFile", v.trim())
            }
            Note { visible: sp.theme.externalPath !== "" && sp.theme.rolesNow() === null; color: sp.th.danger; text: I18n.tr("No colours found in this file, so the default palette is used.") }
            GChoice {
                width: parent.width; th: sp.th; label: I18n.tr("Mode"); options: [["dark", I18n.tr("Dark")], ["light", I18n.tr("Light")]]; value: sp.theme.mode
                onPicked: v => { sp.store.setBuilder("themeMode", v); if (sp.theme.activeSource === "matugen") sp.theme.regenerate(sp.wall.path); }
            }
            GChoice {
                visible: sp.theme.hasMatugen && sp.theme.activeSource === "matugen"
                width: parent.width; th: sp.th; label: I18n.tr("Matugen scheme"); options: D.SCHEMES; value: sp.theme.scheme
                onPicked: v => { sp.store.setBuilder("themeScheme", v); sp.theme.regenerate(sp.wall.path); }
            }
            GButton { visible: sp.theme.hasMatugen && sp.theme.activeSource === "matugen"; th: sp.th; width: parent.width; label: sp.theme.busy ? I18n.tr("Matugen is running …") : I18n.tr("Regenerate palette"); primary: true; onClicked: sp.theme.regenerate(sp.wall.path) }
        }
        }
        Card { title: I18n.tr("GRID & ALIGNMENT")
        Note { text: I18n.tr("Edit mode = this builder (widgetdeck toggle). Widgets can only be dragged here; on the desktop they do not take clicks. Hold Alt while dragging for free placement.") }
        GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Show grid"); checked: sp.store.grid.grid; onToggled: v => sp.store.setGrid("grid", v) }
        GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Snap (grid + guides)"); checked: sp.store.grid.snap; onToggled: v => sp.store.setGrid("snap", v) }
        GSpin { width: parent.width; th: sp.th; label: I18n.tr("Grid size (px, 8 – 64)"); from: 8; to: 64; step: 2; value: sp.store.grid.cell; onMoved: v => sp.store.setGrid("cell", v) }
        GSlider { width: parent.width; th: sp.th; label: I18n.tr("Snap threshold (px)"); from: 4; to: 16; step: 1; value: sp.store.grid.threshold; onMoved: v => sp.store.setGrid("threshold", v) }
        GSpin { width: parent.width; th: sp.th; label: I18n.tr("Distance to the screen edge (px)"); from: 0; to: 100; step: 4; value: sp.store.grid.margin; onMoved: v => sp.store.setGrid("margin", v) }
        GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Allow overlapping"); checked: sp.store.grid.overlap; onToggled: v => sp.store.setGrid("overlap", v) }
        Column {
            spacing: 6; width: parent.width
            GButton { th: sp.th; width: parent.width; label: I18n.tr("Align all to the grid"); onClicked: sp.store.snapAll() }
            GButton {
                id: resetBtn
                property bool armed: false
                width: parent.width
                th: sp.th; danger: true; label: armed ? I18n.tr("Really reset? (click again)") : (sp.store.multi ? I18n.tr("Reset layout of this monitor") : I18n.tr("Reset layout"))
                onClicked: { if (armed) { sp.store.resetLayout(); armed = false; } else { armed = true; armTimer.restart(); } }
                Timer { id: armTimer; interval: 3500; onTriggered: resetBtn.armed = false }
            }
        }
        Note { opacity: 0.8; text: I18n.trf("Usable area: %1 × %2 px from (%3, %4) - grid and limits apply per monitor.", sp.store.area.width, sp.store.area.height, sp.store.area.x, sp.store.area.y) }
        }
        Card { title: I18n.tr("TIMETABLE (UNTIS MOBILE)")
        Note { text: I18n.tr("Reads only your own timetable. The key is stored in the Secret Service (keyring) and never shown. Set it up in a terminal with the QR code from WebUntis > Profile > Releases > Untis Mobile.") }
        Text { width: parent.width; wrapMode: Text.WordWrap; color: sp.ttKey ? sp.th.dim : sp.th.danger; font.family: sp.th.font; font.pixelSize: 12
            text: sp.ttKey ? I18n.tr("Access: key stored") : I18n.tr("Access: not set up") }
        Row {
            spacing: 8
            GButton { th: sp.th; label: sp.ttKey ? I18n.tr("Set up again …") : I18n.tr("Set up …"); onClicked: sp.runSetup("") }
            GButton { th: sp.th; visible: sp.ttKey; danger: true; label: I18n.tr("Remove access"); onClicked: sp.runSetup("--remove") }
        }
        }
    }
    Column {
        id: rightCol
        x: sp.twoCols ? leftCol.width + 14 : 0
        y: sp.twoCols ? 0 : leftCol.height + 14
        width: leftCol.width
        spacing: 14
        Card { title: I18n.tr("START")
        GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Start animation of the builder"); checked: sp.store.builder.splash !== false; onToggled: v => sp.store.setBuilder("splash", v) }
        GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Icon in the system tray"); checked: sp.store.cget("tray", true); onToggled: v => sp.store.setConfig("tray", v) }
        }
        Card { title: "GITHUB"
        GField { width: parent.width; th: sp.th; label: I18n.tr("GitHub user name (for the activity widget)"); value: sp.cfgStr("github_user", ""); onCommitted: v => sp.store.setConfig("github_user", v.trim()) }
        Note { text: I18n.tr("Only public data is read, no login needed. Empty = the account of the gh tool, if it is logged in.") }
        }
        Card { title: I18n.tr("VERSION & UPDATES")
        Row {
            width: parent.width; spacing: 10
            Text { anchors.verticalCenter: parent.verticalCenter; color: sp.th.fg; font.family: sp.th.font; font.pixelSize: 13
                text: I18n.tr("Version") + " " + (sp.update.version !== "" ? sp.update.version : "?") }
            GButton { th: sp.th; label: sp.update.busy ? I18n.tr("Checking …") : I18n.tr("Check for updates"); onClicked: sp.update.check(true) }
        }
        Text { visible: sp.update.message !== ""; width: parent.width; wrapMode: Text.WordWrap; color: sp.th.dim; font.family: sp.th.font; font.pixelSize: 12; text: sp.update.message }
        Column {
            visible: sp.update.available; width: parent.width; spacing: 6
            Text { width: parent.width; wrapMode: Text.WordWrap; color: sp.th.accent; font.family: sp.th.font; font.pixelSize: 13; font.bold: true
                text: I18n.tr("Update available:") + " " + sp.update.latest }
            Text { visible: sp.update.notes !== ""; width: parent.width; wrapMode: Text.WordWrap; color: sp.th.dim; font.family: sp.th.font; font.pixelSize: 11; text: sp.update.notes }
            GButton { th: sp.th; width: parent.width; primary: true; label: I18n.tr("Start the update in a terminal"); onClicked: sp.update.startUpdate() }
            Note { opacity: 0.8; text: I18n.tr("Nothing is installed automatically: the terminal shows the changes and asks first. Your settings are kept.") }
        }
        GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Check for updates automatically"); checked: sp.store.cget("update.check", true); onToggled: v => sp.store.setConfig("update.check", v) }
        }
        Card { title: I18n.tr("GLASS BACKGROUND")
        Text { width: parent.width; wrapMode: Text.WordWrap; color: sp.wall.usable ? sp.th.dim : sp.th.danger; font.family: sp.th.font; font.pixelSize: 12
            text: sp.wall.usable ? I18n.tr("Wallpaper:") + " " + sp.wall.path + (sp.wall.override === "" && sp.wall.tool !== "" ? "  (" + sp.wall.tool + ")" : "")
                : I18n.tr("No wallpaper found - Liquid Glass is off, widgets use Frosted Glass. Choose a picture below.") }
        Row {
            spacing: 8
            GButton { th: sp.th; label: I18n.tr("Choose picture …"); onClicked: sp.pickWallpaper() }
            GButton { th: sp.th; visible: sp.wall.override !== ""; label: I18n.tr("Use detected wallpaper"); onClicked: { sp.store.data.wallpaperPath = ""; sp.store.touch(false); } }
        }
        GField { width: parent.width; th: sp.th; label: I18n.tr("Wallpaper path (empty = automatic)"); value: sp.store.data.wallpaperPath || ""
            onCommitted: v => { sp.store.data.wallpaperPath = v; sp.store.touch(false); } }
        Text { width: parent.width; wrapMode: Text.WordWrap; color: sp.th.dim; font.family: sp.th.font; font.pixelSize: 12
            text: I18n.tr("Glass engine:") + " " + (sp.backend.ready ? (sp.liquidOk ? I18n.tr("GPU shader (refraction active)") : I18n.tr("GPU shader ready, but no wallpaper - Frosted")) : I18n.tr("fallback without refraction") + " (" + sp.backend.state + ")") }
        Text { text: sp.store.dir + "/widgets.json"; color: sp.th.dim; opacity: 0.7; font.family: sp.th.font; font.pixelSize: 11 }
        }
        Card { title: I18n.tr("MODULES")
        Note { text: I18n.tr("Only switch on what you want. Nothing here stops or replaces another program: the bar and the notification service ask first and tell you what has to be turned off.") }
        ModulesBox { width: parent.width; store: sp.store; th: sp.th }
        }
        Card { title: I18n.tr("ALL WIDGETS")
        Text { width: parent.width; wrapMode: Text.WordWrap; color: sp.th.dim; font.family: sp.th.font; font.pixelSize: 12; text: I18n.tr("Set the glass style of every widget at once. Each widget keeps its own settings for the other styles.") }
        Row {
            spacing: 6; width: parent.width
            Repeater {
                model: D.MODES
                delegate: GButton {
                    required property var modelData
                    th: sp.th; label: I18n.tr(modelData[1]); width: (parent.width - 12) / 3
                    onClicked: sp.allMsg = I18n.trf("%1 widgets set to %2", sp.store.setAllMode(modelData[0]), I18n.tr(modelData[1]))
                }
            }
        }
        Text { visible: sp.allMsg !== ""; width: parent.width; wrapMode: Text.WordWrap; color: sp.th.accent; font.family: sp.th.font; font.pixelSize: 11; text: sp.allMsg }
        }
        Card { visible: sp.multi; title: I18n.tr("MONITORS")
        Note { visible: sp.multi; text: I18n.trf("Editing: %1. Pick another monitor at the top of the builder. Grid size and distance above apply to every monitor unless you override them below.", sp.cmon ? sp.cmon.name : "") }
        GChoice { visible: sp.multi; width: parent.width; th: sp.th; label: I18n.tr("Main monitor"); options: sp.monOpts([["", I18n.tr("Automatic")]]); value: sp.cfgStr("monitors.primary", ""); onPicked: v => sp.store.setConfig("monitors.primary", v) }
        GChoice { visible: sp.multi; width: parent.width; th: sp.th; label: I18n.tr("When a monitor is unplugged")
            options: [["wait", I18n.tr("Wait for it")], ["primary", I18n.tr("Use the main monitor")]]; value: sp.cfgStr("monitors.unplugged", "wait"); onPicked: v => sp.store.setConfig("monitors.unplugged", v) }
        GSwitch { visible: sp.multi; width: parent.width; th: sp.th; label: I18n.tr("Drag a widget over the edge to the next monitor"); checked: sp.store.cget("monitors.cross_edge", false); onToggled: v => sp.store.setConfig("monitors.cross_edge", v) }
        Section { visible: sp.multi; text: I18n.trf("THIS MONITOR (%1)", sp.cmon ? sp.cmon.name : "") }
        GSpin { visible: sp.multi; width: parent.width; th: sp.th; label: I18n.tr("Grid size here (px)"); from: 8; to: 64; step: 2; value: sp.store.gridFor(sp.ck).cell; onMoved: v => sp.store.setMonGrid(sp.ck, "cell", v) }
        GSpin { visible: sp.multi; width: parent.width; th: sp.th; label: I18n.tr("Distance to the screen edge here (px)"); from: 0; to: 100; step: 4; value: sp.store.gridFor(sp.ck).margin; onMoved: v => sp.store.setMonGrid(sp.ck, "margin", v) }
        GChoice { visible: sp.multi; width: parent.width; th: sp.th; label: I18n.tr("Size of new widgets here")
            options: [["", I18n.tr("Normal")], ["small", I18n.tr("Small")], ["large", I18n.tr("Large")]]; value: { sp.store.builder; return String(sp.store.monSettings(sp.ck).size || ""); } onPicked: v => sp.store.setMonSize(sp.ck, v) }
        GField { visible: sp.multi; width: parent.width; th: sp.th; label: I18n.tr("Wallpaper of this monitor (empty = automatic)")
            value: { sp.store.data; return (sp.store.data.wallpapers || {})[sp.ck] || ""; }
            onCommitted: v => { var w = Object.assign({}, sp.store.data.wallpapers || {}); if (v) w[sp.ck] = v; else delete w[sp.ck]; sp.store.data.wallpapers = w; sp.store.touch(false); } }
        Column {
            visible: sp.multi; width: parent.width; spacing: 6
            GButton { th: sp.th; width: parent.width; label: I18n.tr("Copy this monitor's layout to …"); onClicked: sp.th.pickList(this, sp.monOpts().filter(function (o) { return o[0] !== sp.ck; }), "", function (k) { sp.store.transferLayout(sp.ck, k); }) }
            GButton {
                id: resetAll
                property bool armed: false
                width: parent.width
                th: sp.th; danger: true; label: armed ? I18n.tr("Really reset? (click again)") : I18n.tr("Reset the layout of all monitors")
                onClicked: { if (armed) { sp.store.resetAllLayouts(); armed = false; } else { armed = true; resetAllTimer.restart(); } }
                Timer { id: resetAllTimer; interval: 3500; onTriggered: resetAll.armed = false }
            }
        }
        Section { visible: sp.multi; text: I18n.tr("BAR, NOTIFICATIONS") }
        GChoice { visible: sp.multi; width: parent.width; th: sp.th; label: I18n.tr("Notifications and pop-ups appear on")
            options: sp.monOpts([["focused", I18n.tr("The focused monitor")], ["primary", I18n.tr("The main monitor")]]); value: sp.cfgStr("monitors.notify", "focused"); onPicked: v => sp.store.setConfig("monitors.notify", v) }
        Repeater {
            model: (sp.multi && sp.store.cget("modules.bar", false)) ? sp.store.mons : []
            delegate: GSwitch {
                required property var modelData
                width: parent.width; th: sp.th; label: I18n.trf("Bar on %1", modelData.name)
                checked: { var b = sp.store.cget("monitors.bar", "all"); return b === "all" || (Array.isArray(b) && b.indexOf(modelData.key) >= 0); }
                onToggled: v => {
                    var b = sp.store.cget("monitors.bar", "all"), keys = sp.store.mons.map(function (m) { return m.key; });
                    var cur = (b === "all" || !Array.isArray(b)) ? keys : b.slice();
                    var i = cur.indexOf(modelData.key);
                    if (v && i < 0) cur.push(modelData.key); else if (!v && i >= 0) cur.splice(i, 1);
                    sp.store.setConfig("monitors.bar", cur.length === keys.length ? "all" : cur);
                }
            }
        }
        }
    }
}
