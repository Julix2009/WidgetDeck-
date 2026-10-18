// Air quality: traffic-light level + text, European AQI, PM2.5 / PM10 / ozone. Open-Meteo (free, no key).
// Location: config.json / automatic (sysmon/location.sh) or the props lat / lon.
// Feed: aq.sh every 30 minutes while the widget is on screen (the script caches for 30 min and serves the last value, marked
// stale with its time stamp, when offline). The level colour is a small dot and a thin scale marker - it never tints the glass.
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
    readonly property color cErr: palette.error || "#ff8a80"
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("sysmon/").toString().replace("file://", ""))

    property var d: ({})
    readonly property bool has: d.aqi !== undefined && d.aqi !== null
    readonly property real aqi: has ? d.aqi : 0
    // European AQI bands (EEA): 0-20 good, 20-40 fair, 40-60 moderate, 60-80 poor, 80-100 very poor, >100 extremely poor.
    // Colours come from the theme (accent family .. error), the traffic-light dot is all that carries them.
    readonly property var bands: [
        { max: 20,  text: I18n.tr("Good"),             col: palette.primary || cAcc },
        { max: 40,  text: I18n.tr("Fair"),       col: palette.secondary || cAcc },
        { max: 60,  text: I18n.tr("Moderate"),           col: palette.tertiary || cAcc },
        { max: 80,  text: I18n.tr("Poor"),        col: cErr },
        { max: 100, text: I18n.tr("Very poor"),   col: cErr },
        { max: 1e9, text: I18n.tr("Extremely poor"), col: cErr }
    ]
    readonly property int level: { for (var i = 0; i < bands.length; i++) if (aqi <= bands[i].max) return i; return bands.length - 1; }
    readonly property color levelColor: bands[level].col

    function clock(iso) { return iso ? String(iso).substring(11, 16) : ""; }
    function ago(sec) { return sec < 90 ? I18n.tr("just now") : sec < 5400 ? I18n.trf("%1 min ago", Math.round(sec / 60)) : I18n.trf("%1 h ago", Math.round(sec / 3600)); }

    Process {
        id: poll
        command: ["bash", w.dir + "aq.sh", String(w.props.lat || ""), String(w.props.lon || "")]
        stdout: StdioCollector { onStreamFinished: { try { w.d = JSON.parse(this.text); } catch (e) { } } }
    }
    Timer {
        interval: 1800000; repeat: true; running: w.live; triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }
    property int configRev: 0               // bumped by WidgetHost when config.json changes (location)
    onConfigRevChanged: if (live && !poll.running) poll.running = true
    Connections {
        target: w
        function onPropsChanged() { if (w.live && !poll.running) poll.running = true; }
    }

    // ---- level + AQI -----------------------------------------------------------------------------------------------------
    Row {
        id: top
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: w.s(52)
        visible: w.has
        Column {
            width: parent.width * 0.62
            anchors.verticalCenter: parent.verticalCenter
            spacing: w.s(2)
            Row {
                spacing: w.s(9)
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: w.s(13); height: width; radius: width / 2; color: w.levelColor }
                GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 1.5; text: w.bands[w.level].text }
            }
            GText { wstyle: w.style; opacity: 0.6; font.bold: true; font.pixelSize: w.fs * 0.68; text: I18n.tr("EUROPEAN AQI") + (w.d.place ? "   ·   " + w.d.place : "") }
        }
        GText {
            width: parent.width * 0.38; height: parent.height
            horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
            wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 2.6; color: w.levelColor; text: Math.round(w.aqi)
        }
    }
    Item {                                                          // thin scale 0..120 with a marker (position = AQI)
        id: scaleBar
        anchors { left: parent.left; right: parent.right; top: top.bottom; topMargin: w.s(6) }
        height: w.s(10); visible: w.has
        Row {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; spacing: w.s(3)
            Repeater {
                model: 6
                delegate: Rectangle {
                    width: (scaleBar.width - w.s(15)) / 6; height: w.s(4); radius: height / 2
                    color: Qt.alpha(w.bands[index].col, index === w.level ? 1.0 : 0.28)
                }
            }
        }
        Rectangle {
            width: w.s(3); height: w.s(10); radius: w.s(1.5); color: w.cFg
            x: Math.max(0, Math.min(scaleBar.width - width, scaleBar.width * Math.min(w.aqi, 120) / 120 - width / 2))
            Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
    }

    // ---- particulates ------------------------------------------------------------------------------------------------------
    Column {
        anchors { left: parent.left; right: parent.right; top: scaleBar.bottom; topMargin: w.s(10) }
        spacing: w.s(6); visible: w.has
        Repeater {
            model: [
                { k: "PM2.5", v: w.d.pm25, max: 25 },
                { k: "PM10",  v: w.d.pm10, max: 50 },
                { k: I18n.tr("Ozone"),  v: w.d.o3,   max: 120 }
            ]
            delegate: Item {
                width: parent.width; height: w.s(18)
                GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.78; text: modelData.k }
                Rectangle {
                    anchors { left: parent.left; leftMargin: w.s(56); right: parent.right; rightMargin: w.s(92); verticalCenter: parent.verticalCenter }
                    height: w.s(5); radius: height / 2; color: Qt.alpha(w.cFg, 0.13)
                    Rectangle {
                        height: parent.height; radius: parent.radius; color: w.cAcc
                        width: Math.max(parent.height, parent.width * Math.min(1, (modelData.v || 0) / modelData.max))
                    }
                }
                GText { anchors { right: parent.right; verticalCenter: parent.verticalCenter } wstyle: w.style; font.pixelSize: w.fs * 0.78
                    text: (modelData.v === undefined || modelData.v === null ? "–" : Number(modelData.v).toFixed(1)) + " µg/m³" }
            }
        }
    }

    GText {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: w.has; elide: Text.ElideRight; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.68
        opacity: w.d.stale ? 1 : 0.6; color: w.d.stale ? w.cErr : w.style.fg
        text: (w.d.stale ? I18n.tr("Offline - last value from") + " " : I18n.tr("As of") + " ") + w.clock(w.d.time) + (w.d.stale ? " (" + w.ago(w.d.age) + ")" : "") + "  ·  Open-Meteo"
    }
    Column {
        anchors.centerIn: parent
        visible: !w.has; spacing: w.s(4)
        GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 1.3; text: w.d.error === "offline" ? I18n.tr("Offline") : (w.d.error === "no-location" ? I18n.tr("No location") : I18n.tr("Loading …")) }
        GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: w.style; opacity: 0.6; font.pixelSize: w.fs * 0.75; text: w.d.error === "no-location" ? I18n.tr("Builder → Settings → Location & units") : "" }
    }
}
