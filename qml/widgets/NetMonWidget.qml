// Network: live download / upload (auto unit B/s .. GB/s), a 60 s curve of both directions, WLAN name or "Ethernet",
// signal strength and ping. Feed: sysmon/netmon.sh (one JSON line per second) - started only while the widget is on screen.
// The glass is the widget's GlassPanel (style.mode frosted | liquid); this item only draws text, bars and curves on top.
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
    readonly property color cUp: palette.tertiary || Qt.lighter(cAcc, 1.4)
    readonly property color cErr: palette.error || "#ff8a80"
    readonly property color cDim: Qt.alpha(cFg, 0.62)
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("sysmon/").toString().replace("file://", ""))

    // ---- data -----------------------------------------------------------------------------------------
    property var d: ({ online: false })
    readonly property bool online: d.online === true
    readonly property int points: 60
    property var rxH: []
    property var txH: []
    property var rxPts: []
    property var txPts: []
    property real ymax: 16 * 1024

    function sample(o) {
        d = o;
        if (!online) return;
        var r = rxH.slice(-(points - 1)), t = txH.slice(-(points - 1));
        r.push(o.rx); t.push(o.tx);
        rxH = r; txH = t;
        rebuild();
    }
    function rebuild() {
        var m = 16 * 1024;                                          // floor: a quiet line does not blow up to full height
        for (var i = 0; i < rxH.length; i++) m = Math.max(m, rxH[i], txH[i]);
        ymax = m > ymax ? m : ymax * 0.97 + m * 0.03;               // grows at once, shrinks slowly
        var pw = plot.width, ph = plot.height, n = rxH.length, a = [], b = [];
        for (var k = 0; k < n; k++) {
            var x = pw * (points - n + k) / (points - 1);
            a.push(Qt.point(x, ph - Math.min(1, rxH[k] / ymax) * (ph - 4) - 2));
            b.push(Qt.point(x, ph - Math.min(1, txH[k] / ymax) * (ph - 4) - 2));
        }
        rxPts = a; txPts = b;
    }
    function reset() { d = ({ online: false }); rxH = []; txH = []; rxPts = []; txPts = []; ymax = 16 * 1024; }
    function fmt(v) {                                               // 1536 -> "1.50" "KB/s"
        var u = ["B/s", "KB/s", "MB/s", "GB/s"], i = 0;
        while (v >= 1024 && i < 3) { v /= 1024; i++; }
        return { n: i === 0 ? String(Math.round(v)) : (v < 10 ? v.toFixed(2) : v < 100 ? v.toFixed(1) : String(Math.round(v))), u: u[i] };
    }
    readonly property var dl: fmt(online ? d.rx : 0)
    readonly property var ul: fmt(online ? d.tx : 0)

    Process {
        id: feed
        running: w.live
        command: ["bash", w.dir + "netmon.sh", String(w.props.ping_target || "1.1.1.1")]
        stdout: SplitParser { onRead: line => { try { w.sample(JSON.parse(line)); } catch (e) { } } }
        onRunningChanged: if (!running) w.reset()
    }
    onPropsChanged: { var t = String(props.ping_target || "1.1.1.1"); if (feed.running && feed.command[2] !== t) { feed.running = false; Qt.callLater(function () { feed.running = true; }); } }

    // ---- top line: name, signal, ping ------------------------------------------------------------------------
    Item {
        id: top
        width: parent.width; height: w.s(26)
        opacity: w.online ? 1 : 0
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: w.s(8)
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: w.d.kind === "wifi" ? "wifi" : "ethernet"
                width: w.fs * 1.4; height: width; color: w.cAcc
            }
            GText {
                anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.9
                width: Math.min(implicitWidth, w.width * 0.35); elide: Text.ElideRight
                text: w.d.kind === "wifi" ? (w.d.ssid || "WLAN") : (w.d.kind === "ethernet" ? "Ethernet" : (w.d.iface || ""))
            }
            Row {                                                   // signal strength (wifi only)
                anchors.verticalCenter: parent.verticalCenter
                visible: w.d.kind === "wifi" && w.d.signal >= 0
                spacing: w.s(6)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: w.s(2)
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            width: w.s(4); height: w.s(5 + index * 4); radius: w.s(1)
                            anchors.bottom: parent.bottom
                            color: w.d.signal >= (index + 1) * 25 - 12 ? w.cAcc : Qt.alpha(w.cFg, 0.2)
                        }
                    }
                }
                GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; opacity: 0.7; font.pixelSize: w.fs * 0.8; text: w.d.signal + " %" }
            }
        }
        GText {                                                     // ping
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.85
            text: w.d.ping === null || w.d.ping === undefined ? "Ping – ms" : "Ping " + Math.round(w.d.ping) + " ms"
            color: w.d.ping === null || w.d.ping === undefined || w.d.ping > 250 ? w.cErr : w.style.fg
        }
    }

    // ---- numbers ----------------------------------------------------------------------------------------------
    Row {
        id: numbers
        anchors { left: parent.left; right: parent.right; top: top.bottom; topMargin: w.s(6) }
        height: w.s(58)
        opacity: w.online ? 1 : 0
        Repeater {
            model: [ { label: I18n.tr("DOWNLOAD"), icon: "arrow-down", col: w.cAcc, v: w.dl }, { label: I18n.tr("UPLOAD"), icon: "arrow-up", col: w.cUp, v: w.ul } ]
            delegate: Column {
                width: numbers.width / 2
                spacing: w.s(1)
                Row {
                    spacing: w.s(4)
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: modelData.icon; width: w.fs * 0.8; height: width; color: modelData.col; opacity: 0.8 }
                    GText { wstyle: w.style; opacity: 0.6; font.bold: true; font.pixelSize: w.fs * 0.68; text: modelData.label }
                }
                Row {
                    spacing: w.s(6)
                    GText { id: num; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 1.9; color: modelData.col; text: modelData.v.n }
                    GText { anchors.baseline: num.baseline; wstyle: w.style; opacity: 0.8; font.pixelSize: w.fs * 0.75; text: modelData.v.u }
                }
            }
        }
    }

    // ---- 60 s curve ----------------------------------------------------------------------------------------------
    Item {
        id: plot
        anchors { left: parent.left; right: parent.right; top: numbers.bottom; topMargin: w.s(4); bottom: parent.bottom }
        opacity: w.online && w.props.show_curve !== false ? 1 : 0
        onWidthChanged: w.rebuild()
        onHeightChanged: w.rebuild()
        Repeater {
            model: 3
            delegate: Rectangle { width: plot.width; height: 1; y: plot.height * (index + 1) / 4; color: Qt.alpha(w.cFg, 0.08) }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: w.cUp; strokeWidth: w.s(2); fillColor: "transparent"; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                PathPolyline { path: w.txPts }
            }
            ShapePath {
                strokeColor: w.cAcc; strokeWidth: w.s(2); fillColor: "transparent"; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                PathPolyline { path: w.rxPts }
            }
        }
        GText { anchors { left: parent.left; top: parent.top } wstyle: w.style; opacity: 0.55; font.pixelSize: w.fs * 0.62; text: { var f = w.fmt(w.ymax); return f.n + " " + f.u; } }
        GText { anchors { right: parent.right; bottom: parent.bottom } wstyle: w.style; opacity: 0.55; font.pixelSize: w.fs * 0.62; text: "60 s" }
    }

    // ---- offline ------------------------------------------------------------------------------------------------------
    Column {
        anchors.centerIn: parent
        spacing: w.s(4)
        opacity: w.online ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "wifi-off"; width: w.fs * 2.8; height: width; color: w.cErr }
        GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 1.4; text: I18n.tr("Offline") }
        GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: w.style; opacity: 0.6; font.pixelSize: w.fs * 0.8; text: I18n.tr("No connection") }
    }
}
