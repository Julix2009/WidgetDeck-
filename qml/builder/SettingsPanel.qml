// The settings column of the builder: grid, monitor, modules, location & units, theme, glass background, version & updates, assistant.
import QtQuick
import Quickshell
import "../core"
import "../core/Defaults.js" as D

Column {
    id: sp
    required property var store
    required property var theme
    required property var wall
    required property var backend
    required property var update
    required property var th
    property string screenName: ""
    property bool liquidOk: false
    signal pickWallpaper()
    signal runWizard()
    spacing: 8

    component Section: Text { topPadding: 8; color: sp.th.dim; font.family: sp.th.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2 }
    component Note: Text { width: sp.width; wrapMode: Text.WordWrap; color: sp.th.dim; font.family: sp.th.font; font.pixelSize: 11 }
    function cfgStr(k, d) { var v = store.cget(k, d); return v === null ? "" : String(v); }

    // ───────────── grid ─────────────
    Section { text: I18n.tr("GRID & ALIGNMENT"); topPadding: 0 }
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
            th: sp.th; danger: true; label: armed ? I18n.tr("Really reset? (click again)") : I18n.tr("Reset layout")
            onClicked: { if (armed) { sp.store.resetLayout(); armed = false; } else { armed = true; armTimer.restart(); } }
            Timer { id: armTimer; interval: 3500; onTriggered: resetBtn.armed = false }
        }
    }
    Note { opacity: 0.8; text: I18n.trf("Usable area: %1 × %2 px from (%3, %4) - grid and limits apply per monitor.", sp.store.area.width, sp.store.area.height, sp.store.area.x, sp.store.area.y) }

    // ───────────── monitor ─────────────
    Section { visible: Quickshell.screens.length > 1; text: I18n.tr("MONITOR") }
    GChoice {
        visible: Quickshell.screens.length > 1
        width: parent.width; th: sp.th; label: I18n.tr("Show the widgets on")
        options: Quickshell.screens.map(function (s) { return [s.name, s.name + "  (" + s.width + "×" + s.height + ")"]; })
        value: sp.screenName
        onPicked: v => { sp.store.data.monitor = v; sp.store.touch(false); }
    }

    // ───────────── modules ─────────────
    Section { text: I18n.tr("MODULES") }
    Note { text: I18n.tr("Only switch on what you want. Nothing here stops or replaces another program: the bar and the notification service ask first and tell you what has to be turned off.") }
    ModulesBox { width: parent.width; store: sp.store; th: sp.th }

    // ───────────── location & units ─────────────
    Section { text: I18n.tr("LOCATION & UNITS") }
    Note { text: I18n.tr("For weather and air quality. With 'automatic' your IP address is sent once to ipwho.is (the result is kept for a week); your own coordinates take priority. Open-Meteo only receives coordinates.") }
    GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Locate automatically (IP address)"); checked: sp.store.cget("location.auto", true); onToggled: v => sp.store.setConfig("location.auto", v) }
    GField {
        width: parent.width; th: sp.th; label: I18n.tr("Latitude (e.g. 48.2082, empty = automatic)"); value: sp.cfgStr("location.lat", "")
        onCommitted: v => { var n = parseFloat(v); sp.store.setConfig("location.lat", isFinite(n) && n >= -90 && n <= 90 ? n : null); }
    }
    GField {
        width: parent.width; th: sp.th; label: I18n.tr("Longitude (e.g. 16.3738)"); value: sp.cfgStr("location.lon", "")
        onCommitted: v => { var n = parseFloat(v); sp.store.setConfig("location.lon", isFinite(n) && n >= -180 && n <= 180 ? n : null); }
    }
    GField { width: parent.width; th: sp.th; label: I18n.tr("Place name (display only)"); value: sp.cfgStr("location.name", ""); onCommitted: v => sp.store.setConfig("location.name", v) }
    GChoice { width: parent.width; th: sp.th; label: I18n.tr("Units"); options: [["auto", I18n.tr("From system")], ["metric", "°C, m/s"], ["imperial", "°F, mph"]]; value: sp.store.cget("units", "auto"); onPicked: v => sp.store.setConfig("units", v) }
    GChoice { width: parent.width; th: sp.th; label: I18n.tr("Clock"); options: [["auto", I18n.tr("From system")], ["24h", "24 h"], ["12h", "12 h"]]; value: sp.store.cget("time_format", "auto"); onPicked: v => sp.store.setConfig("time_format", v) }
    GChoice { width: parent.width; th: sp.th; label: I18n.tr("Language"); options: [["auto", I18n.tr("From system")], ["en", "English"], ["de", "Deutsch"]]; value: sp.store.cget("language", "auto"); onPicked: v => sp.store.setConfig("language", v) }

    // ───────────── theme (matugen is optional) ─────────────
    Section { text: I18n.tr("THEME (MATUGEN)") }
    Note { visible: !sp.theme.hasMatugen; text: I18n.tr("Matugen is not installed, so the fixed default palette is used. Install it (pacman -S matugen) and the colours can follow your wallpaper.") }
    Column {
        visible: sp.theme.hasMatugen; width: parent.width; spacing: 8
        GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Theme active (follows the wallpaper)"); checked: sp.theme.enabled; onToggled: v => sp.store.setBuilder("themeEnabled", v) }
        GChoice {
            width: parent.width; th: sp.th; label: I18n.tr("Matugen scheme"); options: D.SCHEMES; value: sp.theme.scheme
            onPicked: v => { sp.store.setBuilder("themeScheme", v); sp.theme.regenerate(sp.wall.path); }
        }
        GChoice {
            width: parent.width; th: sp.th; label: I18n.tr("Mode"); options: [["dark", I18n.tr("Dark")], ["light", I18n.tr("Light")]]; value: sp.theme.mode
            onPicked: v => { sp.store.setBuilder("themeMode", v); sp.theme.regenerate(sp.wall.path); }
        }
        GButton { th: sp.th; width: parent.width; label: sp.theme.busy ? I18n.tr("Matugen is running …") : I18n.tr("Regenerate palette"); primary: true; onClicked: sp.theme.regenerate(sp.wall.path) }
        Row {
            spacing: 8
            Rectangle { width: 18; height: 18; radius: 9; color: sp.theme.sourceColor !== "" ? sp.theme.sourceColor : "transparent"; border.width: 1; border.color: sp.th.line }
            Text { width: sp.width - 30; wrapMode: Text.WordWrap; color: sp.th.dim; font.family: sp.th.font; font.pixelSize: 11
                text: I18n.tr("Scheme and mode run Matugen on the current wallpaper. An executable ~/.config/widgetdeck/hooks/after-matugen runs afterwards (e.g. to reload other programs).") }
        }
    }

    // ───────────── builder look ─────────────
    Section { text: I18n.tr("BUILDER LOOK") }
    GChoice { width: parent.width; th: sp.th; label: I18n.tr("Glass style of the builder"); options: D.MODES; value: sp.store.builder.glass; onPicked: v => sp.store.setBuilder("glass", v) }
    GSlider { width: parent.width; th: sp.th; label: I18n.tr("Window opacity"); from: 0.5; to: 0.95; step: 0.01; value: sp.store.builder.opacity; onMoved: v => sp.store.setBuilder("opacity", v) }
    GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Live capture of windows (experimental)"); checked: sp.store.builder.liveCapture === true; onToggled: v => sp.store.setBuilder("liveCapture", v) }

    // ───────────── glass background ─────────────
    Section { text: I18n.tr("GLASS BACKGROUND") }
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

    // ───────────── version & updates ─────────────
    Section { text: I18n.tr("VERSION & UPDATES") }
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
    GSwitch { width: parent.width; th: sp.th; label: I18n.tr("Check for updates daily"); checked: sp.store.cget("update.check", true); onToggled: v => sp.store.setConfig("update.check", v) }

    // ───────────── assistant ─────────────
    Section { text: I18n.tr("SETUP") }
    GButton { th: sp.th; width: parent.width; label: I18n.tr("Run the setup assistant again"); onClicked: sp.runWizard() }
}
