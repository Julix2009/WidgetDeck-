// Temperatures and fans: CPU / GPU / SSD as rings (or bars) with the value, fan speeds as bars.
// Feed: sysmon/thermals.sh (every 2.5 s, only while the widget is on screen). Sensors are detected from /sys/class/hwmon;
// one that does not exist (no GPU temperature on Intel iGPUs, no fan) is simply not drawn - never a made-up value.
// From the threshold (prop warn_c, default 80 degC) a value turns into the theme's error colour.
import QtQuick
import QtQuick.Shapes
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
    readonly property color cAlt: palette.tertiary || Qt.lighter(cAcc, 1.4)
    readonly property color cErr: palette.error || "#ff8a80"
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("sysmon/").toString().replace("file://", ""))

    property var d: ({})
    readonly property real warn: Number(props.warn_c !== undefined ? props.warn_c : 80)
    readonly property var temps: {            // what is there: [{ label, v, col }]
        var a = [];
        if (d.cpu !== undefined && d.cpu !== null) a.push({ label: "CPU", v: d.cpu, col: cAcc });
        if (d.gpu !== undefined && d.gpu !== null) a.push({ label: "GPU", v: d.gpu, col: cAlt });
        var q = d.ssd || [];
        for (var i = 0; i < q.length; i++) if (q[i] !== null) a.push({ label: q.length > 1 ? "SSD " + (i + 1) : "SSD", v: q[i], col: Qt.lighter(cAcc, 1.15) });
        return a;
    }
    readonly property var fans: props.show_fans === false ? [] : (d.fans || [])

    Process {
        id: feed
        running: w.live
        command: ["bash", w.dir + "thermals.sh", String(Math.round(w.warn))]
        stdout: SplitParser { onRead: line => { try { w.d = JSON.parse(line); } catch (e) { } } }
        onRunningChanged: if (!running) w.d = ({})
    }
    onWarnChanged: if (feed.running) { feed.running = false; Qt.callLater(function () { feed.running = true; }); }

    // ---- temperatures: rings -------------------------------------------------------------------------------------
    Row {
        id: ringRow
        visible: w.props.mode !== "bars"
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
        spacing: w.s(14)
        Repeater {
            model: w.props.mode !== "bars" ? w.temps : []
            delegate: Item {
                id: ring
                readonly property bool hot: modelData.v >= w.warn
                readonly property real dia: Math.min(w.s(96), (w.height - (w.fans.length * w.s(26)) - w.s(34)))
                width: dia; height: dia + w.s(22)
                Ring {
                    width: ring.dia; height: ring.dia
                    value: Math.max(0.02, Math.min(1, (modelData.v - 20) / 80))
                    barColor: ring.hot ? w.cErr : modelData.col
                    trackColor: Qt.alpha(w.cFg, 0.13)
                    thickness: ring.dia * 0.09
                    Behavior on value { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    GText { anchors.centerIn: parent; wstyle: w.style; font.bold: true; font.pixelSize: ring.dia * 0.28; color: ring.hot ? w.cErr : w.style.fg; text: modelData.v + "°" }
                }
                GText { y: ring.dia + w.s(2); width: ring.dia; horizontalAlignment: Text.AlignHCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.78; opacity: ring.hot ? 1 : 0.65; color: ring.hot ? w.cErr : w.style.fg; text: modelData.label }
            }
        }
    }
    // ---- temperatures: bars ------------------------------------------------------------------------------------------
    Column {
        visible: w.props.mode === "bars"
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: w.s(8)
        Repeater {
            model: w.props.mode === "bars" ? w.temps : []
            delegate: Item {
                readonly property bool hot: modelData.v >= w.warn
                width: parent.width; height: w.s(24)
                GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.85; color: parent.hot ? w.cErr : w.style.fg; text: modelData.label }
                Rectangle {
                    anchors { left: parent.left; leftMargin: w.s(64); right: parent.right; rightMargin: w.s(56); verticalCenter: parent.verticalCenter }
                    height: w.s(7); radius: height / 2; color: Qt.alpha(w.cFg, 0.13)
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, (modelData.v - 20) / 80)))
                        color: parent.parent.hot ? w.cErr : modelData.col
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
                GText { anchors { right: parent.right; verticalCenter: parent.verticalCenter } wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.85; color: parent.hot ? w.cErr : w.style.fg; text: modelData.v + " °C" }
            }
        }
    }

    // ---- fans ----------------------------------------------------------------------------------------------------------
    Column {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: w.s(6)
        Repeater {
            model: w.fans
            delegate: Item {
                width: parent.width; height: w.s(20)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰈐"; font.family: "Iosevka Nerd Font"; font.pixelSize: w.fs * 1.0; color: w.cAcc
                    style: w.style.mode === "liquid" ? Text.Raised : Text.Normal; styleColor: "#73000000"; renderType: Text.QtRendering
                }
                GText { anchors { left: parent.left; leftMargin: w.s(24); verticalCenter: parent.verticalCenter } wstyle: w.style; font.pixelSize: w.fs * 0.78; text: modelData.label }
                Rectangle {                                         // 0 .. 6000 rpm
                    anchors { left: parent.left; leftMargin: w.s(104); right: parent.right; rightMargin: w.s(70); verticalCenter: parent.verticalCenter }
                    height: w.s(6); radius: height / 2; color: Qt.alpha(w.cFg, 0.13)
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        width: Math.max(parent.height, parent.width * Math.min(1, modelData.rpm / 6000)); color: w.cAcc
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
                GText { anchors { right: parent.right; verticalCenter: parent.verticalCenter } wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.78; text: modelData.rpm + " rpm" }
            }
        }
    }

    GText {                                                         // no sensor at all (e.g. a VM)
        anchors.centerIn: parent
        visible: w.temps.length === 0 && w.fans.length === 0
        wstyle: w.style; opacity: 0.65; text: "Keine Sensoren gefunden"
    }
}
