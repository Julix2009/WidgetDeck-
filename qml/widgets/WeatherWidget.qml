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
    // icon glyphs as written by weather.sh: rain U+F0597, storm U+F0E7, snow U+F2DC
    readonly property string realKind: {
        if (!d || !d.current_icon) return "";
        var c = String(d.current_icon).codePointAt(0);
        return (c === 0xF0597 || c === 0xF0E7) ? "rain" : (c === 0xF2DC ? "snow" : "");
    }
    readonly property string particleKind: {
        if (props.particles === false) return "";
        var dbg = props.debug_weather;
        if (dbg === "rain" || dbg === "snow") return dbg;
        if (dbg === "off") return "";
        return realKind;
    }
    readonly property real particleDensity: props.particle_density !== undefined ? Number(props.particle_density) : 1.0

    Process {
        id: poll
        command: ["bash", w.dir + "weather.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    if (o && o.current_temp !== undefined) { w.d = o; w.err = ""; }
                    else if (o && o.error) w.err = o.error;
                } catch (e) { w.err = "offline"; }
            }
        }
    }
    onConfigRevChanged: if (live && !poll.running) poll.running = true
    Timer {
        interval: 600000; repeat: true; running: w.live; triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    // ---- main: icon, temperature, condition ------------------------------------------------------------------------------
    Row {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: w.s(16)
        visible: w.has
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: w.d ? w.d.current_icon : ""
            font.family: "Iosevka Nerd Font"; font.pixelSize: w.fs * 3.6; color: w.cAcc
            style: w.style.mode === "liquid" ? Text.Raised : Text.Normal; styleColor: "#73000000"; renderType: Text.QtRendering
        }
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
                { k: "󰔏", t: Math.round(Number(w.today.max)) + "° / " + Math.round(Number(w.today.min)) + "°" },
                { k: "󰔄", t: "gefühlt " + Math.round(Number(w.today.feels_like)) + "°" },
                { k: "󰖝", t: w.today.wind + " " + w.windUnit },
                { k: "󰖎", t: w.today.humidity + " %" }
            ] : []
            delegate: Row {
                anchors.right: parent.right
                spacing: w.s(8)
                GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.82; text: modelData.t }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: w.s(20); horizontalAlignment: Text.AlignHCenter
                    text: modelData.k; font.family: "Iosevka Nerd Font"; font.pixelSize: w.fs * 0.95; color: w.cAcc
                    style: w.style.mode === "liquid" ? Text.Raised : Text.Normal; styleColor: "#73000000"; renderType: Text.QtRendering
                }
            }
        }
    }
    GText {
        anchors.centerIn: parent; visible: !w.has; wstyle: w.style; opacity: 0.65
        horizontalAlignment: Text.AlignHCenter; width: parent.width - w.s(20); wrapMode: Text.WordWrap
        text: w.err === "no-location" ? "Kein Standort bekannt.\nBuilder → Einstellungen → Standort & Einheiten" : (poll.running ? "Lade …" : (w.err === "offline" ? "Keine Verbindung" : "Keine Wetterdaten"))
    }
}
