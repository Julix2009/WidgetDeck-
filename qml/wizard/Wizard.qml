// First-run assistant: wallpaper, location, units, style, size, widgets. Shown once (config.json "setup.done"), skippable, writes only the user's own config.
// `widgetdeck ipc wizard` shows it again.
import QtQuick
import Quickshell
import "../core"
import "../builder"

FloatingWindow {
    id: wz
    required property var store
    required property var theme
    required property var wall
    required property bool liquidOk
    required property bool shaderOk
    readonly property bool active: store.loaded && store.configLoaded && !store.cget("setup.done", false)
    property bool dismissed: false
    onActiveChanged: if (active) dismissed = false
    visible: active && !dismissed
    onClosed: dismissed = true
    title: "WidgetDeck Setup"
    color: "transparent"
    implicitWidth: 760; implicitHeight: 640
    minimumSize: Qt.size(760, 640); maximumSize: Qt.size(760, 640)

    Theme { id: th; themeStore: wz.theme; liquid: false }
    readonly property var uiTheme: th

    // ---- the choices (initialised from the current config, so re-running the assistant starts from what is set) ----
    property int step: 0
    readonly property int lastStep: 5
    property string locMode: store.cget("location.auto", true) ? "auto" : (store.cget("location.lat", null) !== null ? "manual" : "off")
    property string lat: store.cget("location.lat", null) !== null ? String(store.cget("location.lat", "")) : ""
    property string lon: store.cget("location.lon", null) !== null ? String(store.cget("location.lon", "")) : ""
    property string place: store.cget("location.name", "")
    property string units: store.cget("units", "auto")
    property string timeFmt: store.cget("time_format", "auto")
    property string lang: store.cget("language", "auto")
    property string style: "frosted"
    property string size: "M"
    property var picked: ({ clock: true, sysmon: true, music: true, weather: true, netmon: false, thermals: false, sysstatus: false, airquality: false, visualizer: false, weathercard: false, timetable: false })
    readonly property var typeKeys: ["clock", "sysmon", "music", "visualizer", "weather", "weathercard", "airquality", "netmon", "thermals", "sysstatus", "timetable"]
    function openTimetableSetup() { Quickshell.execDetached(["sh", "-c", "exec \"$1\" --terminal 2>/dev/null || exec widgetdeck-untis-setup --terminal", "sh", Quickshell.env("HOME") + "/.local/bin/widgetdeck-untis-setup"]); }

    function apply(o) {                  // automation: set choices by name (locMode, units, timeFmt, lang, style, size, lat, lon)
        for (var k in o) wz[k] = o[k];
    }
    function typeLabel(k) { var t = store.typeInfo(k); return t ? I18n.tr(t.label) : k; }
    function finish(skip) {
        if (!skip) {
            store.setConfig("location.auto", locMode === "auto");
            var la = parseFloat(lat), lo = parseFloat(lon);
            store.setConfig("location.lat", locMode === "manual" && isFinite(la) ? la : null);
            store.setConfig("location.lon", locMode === "manual" && isFinite(lo) ? lo : null);
            store.setConfig("location.name", locMode === "manual" ? place : "");
            store.setConfig("units", units); store.setConfig("time_format", timeFmt); store.setConfig("language", lang);
            var types = typeKeys.filter(function (k) { return picked[k] && store.typeInfo(k); });
            if (locMode === "off") types = types.filter(function (k) { return k !== "weather" && k !== "weathercard" && k !== "airquality"; });
            store.setupLayout(types, size === "S" ? 0.85 : (size === "L" ? 1.25 : 1), style === "liquid" && liquidOk ? "liquid" : "frosted");
        }
        store.setConfig("setup.done", true);
    }

    FilePicker { id: picker; anchors.fill: parent; z: 20; visible: false; th: th; onPicked: p => { store.data.wallpaperPath = p; store.touch(false); } }

    Rectangle {
        anchors.fill: parent
        radius: 28; color: th.popup; border.width: 1; border.color: th.line

        Column {
            anchors { fill: parent; margins: 32 }
            spacing: 14

            // header
            Row {
                width: parent.width; spacing: 12
                Text { text: "WidgetDeck"; color: th.fg; font.family: th.font; font.pixelSize: 22; font.bold: true }
                Text { anchors.baseline: parent.children[0].baseline; text: I18n.trf("Setup  ·  step %1 of %2", wz.step + 1, wz.lastStep + 1); color: th.dim; font.family: th.font; font.pixelSize: 13 }
            }
            Rectangle { width: parent.width; height: 1; color: th.line }

            // ---------------- 0: wallpaper ----------------
            Column {
                visible: wz.step === 0; width: parent.width; spacing: 12
                Text { text: I18n.tr("Wallpaper"); color: th.fg; font.family: th.font; font.pixelSize: 18; font.bold: true }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: th.dim; font.family: th.font; font.pixelSize: 13
                    text: I18n.tr("Liquid Glass bends the picture behind a widget, so it needs to know your wallpaper. WidgetDeck looks for it in awww, swww, hyprpaper, swaybg and wpaperd. If you use something else, choose the picture yourself.") }
                Rectangle {
                    width: parent.width; height: 150; radius: 16; color: th.field; clip: true
                    Image { anchors.fill: parent; source: wz.wall.url; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(700, 300); visible: wz.wall.usable }
                    Text { anchors.centerIn: parent; visible: !wz.wall.usable; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        color: th.danger; font.family: th.font; font.pixelSize: 14
                        text: I18n.tr("No wallpaper found. Choose a picture - without one, Liquid Glass is switched off and the widgets use Frosted Glass.") }
                }
                Text { width: parent.width; elide: Text.ElideMiddle; color: th.dim; font.family: th.font; font.pixelSize: 12
                    text: wz.wall.usable ? (wz.wall.override !== "" ? I18n.tr("Chosen by you") : (wz.wall.tool !== "" ? I18n.trf("Found via %1", wz.wall.tool) : "")) + "  ·  " + wz.wall.path : "" }
                Row {
                    spacing: 8
                    GButton { th: th; primary: !wz.wall.usable; label: I18n.tr("Choose picture …"); onClicked: { picker.startPath = ""; picker.open(); } }
                    GButton { th: th; visible: wz.wall.override !== ""; label: I18n.tr("Use detected wallpaper"); onClicked: { wz.store.data.wallpaperPath = ""; wz.store.touch(false); } }
                }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: wz.shaderOk ? th.dim : th.danger; font.family: th.font; font.pixelSize: 12
                    text: wz.shaderOk ? I18n.tr("Glass shader: ready.") : I18n.tr("Glass shader: not available (qsb is missing or failed). Everything uses Frosted Glass; run 'widgetdeck doctor' for details.") }
            }

            // ---------------- 1: location ----------------
            Column {
                visible: wz.step === 1; width: parent.width; spacing: 12
                Text { text: I18n.tr("Location for weather and air quality"); color: th.fg; font.family: th.font; font.pixelSize: 18; font.bold: true }
                GChoice { width: parent.width; th: th; label: I18n.tr("How should WidgetDeck find your location?")
                    options: [["auto", I18n.tr("Automatic")], ["manual", I18n.tr("Enter it")], ["off", I18n.tr("No weather")]]; value: wz.locMode; onPicked: v => wz.locMode = v }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: th.dim; font.family: th.font; font.pixelSize: 13
                    text: wz.locMode === "auto" ? I18n.tr("Once a week your IP address is sent to ipwho.is to look up the rough location (city level). The result is stored on your computer. The weather service (open-meteo.com) only receives the coordinates. Nothing else is sent, no account or key is needed.")
                        : wz.locMode === "manual" ? I18n.tr("Nothing is looked up. The coordinates are sent to open-meteo.com for the forecast, nothing else.")
                        : I18n.tr("No network request for weather is made; the weather and air quality widgets are not added.") }
                Column {
                    visible: wz.locMode === "manual"; width: parent.width; spacing: 6
                    GField { width: parent.width; th: th; label: I18n.tr("Latitude (e.g. 48.2082)"); value: wz.lat; onCommitted: v => wz.lat = v }
                    GField { width: parent.width; th: th; label: I18n.tr("Longitude (e.g. 16.3738)"); value: wz.lon; onCommitted: v => wz.lon = v }
                    GField { width: parent.width; th: th; label: I18n.tr("Place name (display only)"); value: wz.place; onCommitted: v => wz.place = v }
                }
            }

            // ---------------- 2: units ----------------
            Column {
                visible: wz.step === 2; width: parent.width; spacing: 12
                Text { text: I18n.tr("Units and language"); color: th.fg; font.family: th.font; font.pixelSize: 18; font.bold: true }
                GChoice { width: parent.width; th: th; label: I18n.tr("Temperature and speed")
                    options: [["auto", I18n.tr("From system")], ["metric", "°C, m/s"], ["imperial", "°F, mph"]]; value: wz.units; onPicked: v => wz.units = v }
                GChoice { width: parent.width; th: th; label: I18n.tr("Clock")
                    options: [["auto", I18n.tr("From system")], ["24h", "24 h"], ["12h", "12 h"]]; value: wz.timeFmt; onPicked: v => wz.timeFmt = v }
                GChoice { width: parent.width; th: th; label: I18n.tr("Language")
                    options: [["auto", I18n.tr("From system")], ["en", "English"], ["de", "Deutsch"]]; value: wz.lang; onPicked: v => { wz.lang = v; I18n.setting = v; } }
            }

            // ---------------- 3: style + size ----------------
            Column {
                visible: wz.step === 3; width: parent.width; spacing: 12
                Text { text: I18n.tr("Look"); color: th.fg; font.family: th.font; font.pixelSize: 18; font.bold: true }
                GChoice { width: parent.width; th: th; label: I18n.tr("Glass style")
                    options: [["frosted", I18n.tr("Standard (Frosted)")], ["liquid", "Liquid Glass"]]; value: wz.style; onPicked: v => wz.style = v }
                Text { visible: wz.style === "liquid" && !wz.liquidOk; width: parent.width; wrapMode: Text.WordWrap; color: th.danger; font.family: th.font; font.pixelSize: 12
                    text: I18n.tr("Liquid Glass is not available right now (see the wallpaper / shader notes on the first page). The widgets will use Frosted Glass; you can switch later in the builder.") }
                GChoice { width: parent.width; th: th; label: I18n.tr("Widget size")
                    options: [["S", I18n.tr("Small")], ["M", I18n.tr("Medium")], ["L", I18n.tr("Large")]]; value: wz.size; onPicked: v => wz.size = v }
            }

            // ---------------- 4: widgets ----------------
            Column {
                visible: wz.step === 4; width: parent.width; spacing: 6
                Text { text: I18n.tr("Which widgets do you want?"); color: th.fg; font.family: th.font; font.pixelSize: 18; font.bold: true }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: th.dim; font.family: th.font; font.pixelSize: 12
                    text: I18n.tr("You can add, remove and move widgets at any time in the builder. Sensors that your computer does not have are simply left out.") }
                Repeater {
                    model: wz.typeKeys
                    delegate: GSwitch {
                        required property string modelData
                        width: parent.width; th: wz.uiTheme; label: wz.typeLabel(modelData); checked: !!wz.picked[modelData]
                        onToggled: v => { var p = Object.assign({}, wz.picked); p[modelData] = v; wz.picked = p; }
                    }
                }
                Row {
                    visible: !!wz.picked.timetable; spacing: 10
                    GButton { th: th; label: I18n.tr("Set up the timetable access …"); onClicked: wz.openTimetableSetup() }
                    Text { anchors.verticalCenter: parent.verticalCenter; width: 340; wrapMode: Text.WordWrap; color: th.dim; font.family: th.font; font.pixelSize: 11
                           text: I18n.tr("The timetable needs your own Untis Mobile access (QR code from WebUntis). Until it is set up the widget only shows a hint.") }
                }
            }

            // ---------------- 5: done ----------------
            Column {
                visible: wz.step === 5; width: parent.width; spacing: 12
                Text { text: I18n.tr("All set"); color: th.fg; font.family: th.font; font.pixelSize: 18; font.bold: true }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: th.dim; font.family: th.font; font.pixelSize: 14
                    text: I18n.tr("The widgets appear on your desktop right away; nothing needs a restart. Open the builder with 'widgetdeck builder' to move them, change the glass or switch optional modules (bar, notifications) on. 'widgetdeck doctor' checks your setup.") }
            }
        }

        // navigation
        GButton { anchors { left: parent.left; bottom: parent.bottom; margins: 32 } th: th; label: I18n.tr("Skip setup"); visible: wz.step < wz.lastStep; onClicked: wz.finish(true) }
        Row {
            anchors { right: parent.right; bottom: parent.bottom; margins: 32 }
            spacing: 8
            GButton { th: th; label: I18n.tr("Back"); visible: wz.step > 0; onClicked: wz.step-- }
            GButton { th: th; primary: true; label: wz.step < wz.lastStep ? I18n.tr("Next") : I18n.tr("Finish"); onClicked: { if (wz.step < wz.lastStep) wz.step++; else wz.finish(false); } }
        }
    }
}
