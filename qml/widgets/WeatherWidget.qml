// Weather: temperature, condition, high / low, feels like, wind, humidity - and, on Liquid Glass, rain beads / snow flakes.
// Data: sysmon/weather.sh (Open-Meteo, no API key, cached 10 min) every 10 minutes while the widget is on screen.
// Location and units come from ~/.config/widgetdeck/config.json (builder: Settings -> Location & units) or are detected automatically.
// Particles: this widget declares `particleKind`; WidgetHost then adds the drops overlay (core/GlassDrops.qml) to its glass:
// small glass lenses made of the widget's own material. Only on Liquid Glass, only for rain / snow (storms count as rain);
// dry weather costs nothing. Props: particles (on/off), particle_density, debug_weather (test switch: force rain / snow).
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../core"

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})

    readonly property real fs: style.font_size || 16
    function s(v) { return v * fs / 16; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: style.accent || "#8ab4ff"
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("sysmon/").toString().replace("file://", ""))
    property int configRev: 0              // bumped by WidgetHost when config.json changes (location, units): fetch again
    property string err: ""

    property var d: null
    readonly property string unit: d && d.unit ? d.unit : "°C"
    readonly property string windUnit: d && d.wind_unit ? d.wind_unit : "m/s"
    readonly property var today: d && d.forecast && d.forecast.length > 0 ? d.forecast[0] : null
    readonly property bool has: d !== null && d.current_temp !== undefined

    // ---- what the particles react to --------------------------------------------------------------------------------------
    // icon names as written by weather.sh: sun, moon, cloud, mist, rain, snow, storm
    readonly property string realKind: {
        if (!d || !d.current_icon) return "";
        var c = String(d.current_icon);
        return (c === "rain" || c === "storm") ? "rain" : (c === "snow" ? "snow" : "");
    }
    readonly property string particleKind: {
        if (props.particles === false) return "";
        var dbg = props.debug_weather;
        if (dbg === "rain" || dbg === "snow") return dbg;
        if (dbg === "off") return "";
        return realKind;
    }
    readonly property real particleDensity: props.particle_density !== undefined ? Number(props.particle_density) : 1.0

    Feed {                                                  // one weather request for all weather widgets (and monitors); the script also caches and locks
        id: poll
        key: "weather"
        command: ["bash", w.dir + "weather.sh"]
        interval: 600000
        active: w.live
        onGot: text => {
            try {
                var o = JSON.parse(text);
                if (o && o.current_temp !== undefined) { w.d = o; w.err = ""; }
                else if (o && o.error) w.err = o.error;
            } catch (e) { w.err = "offline"; }
        }
    }

    // ---- main: icon, temperature, condition ------------------------------------------------------------------------------
    Row {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: w.s(16)
        visible: w.has
        Icon { anchors.verticalCenter: parent.verticalCenter; name: w.d ? w.d.current_icon : ""; width: w.fs * 3.8; height: width; stroke: 1.7; color: w.cAcc }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: w.s(2)
            GText { wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 3.2; text: w.has ? Math.round(Number(w.d.current_temp)) + "°" : "" }
            GText { wstyle: w.style; opacity: 0.75; font.bold: true; font.pixelSize: w.fs * 0.95; text: w.today ? w.today.desc : "" }
        }
    }
    // ---- details -------------------------------------------------------------------------------------------------------------
    Column {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: w.s(5)
        visible: w.has && w.props.show_details !== false && !!w.today
        Repeater {
            model: w.today ? [
                { k: "thermometer", t: Math.round(Number(w.today.max)) + "° / " + Math.round(Number(w.today.min)) + "°" },
                { k: "thermometer", t: I18n.tr("feels like") + " " + Math.round(Number(w.today.feels_like)) + "°" },
                { k: "wind", t: w.today.wind + " " + w.windUnit },
                { k: "drop", t: w.today.humidity + " %" }
            ] : []
            delegate: Row {
                anchors.right: parent.right
                spacing: w.s(8)
                GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.82; text: modelData.t }
                Icon { anchors.verticalCenter: parent.verticalCenter; name: modelData.k; width: w.fs * 1.1; height: width; color: w.cAcc }
            }
        }
    }
    GText {
        anchors.centerIn: parent; visible: !w.has; wstyle: w.style; opacity: 0.65
        horizontalAlignment: Text.AlignHCenter; width: parent.width - w.s(20); wrapMode: Text.WordWrap
        text: w.err === "no-location" ? I18n.tr("No location known.") + "\n" + I18n.tr("Builder → Settings → Location & units") : (w.err === "" ? I18n.tr("Loading …") : (w.err === "offline" ? I18n.tr("No connection") : I18n.tr("No weather data")))
    }
}
