import QtQuick
import Quickshell.Io
import "../core"

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property real cpu: 0
    property real ram: 0
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property var prev: null

    readonly property var items: {
        var a = [];
        if (props.show_cpu) a.push({ name: "CPU", v: cpu, text: Math.round(cpu * 100) + "%" });
        if (props.show_ram) a.push({ name: "RAM", v: ram, text: ramUsedGb.toFixed(1) + " / " + Math.round(ramTotalGb) + " GB" });
        return a;
    }

    // one long-lived shell prints a sample per interval (cheaper than spawning a process every time)
    Process {
        id: poll
        running: true
        command: ["sh", "-c", "while :; do head -n1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; echo; sleep " + (w.props.interval / 1000) + "; done"]
        stdout: SplitParser {
            property real total: 0
            property real avail: 0
            onRead: line => {
                if (line.indexOf("cpu ") === 0) {
                    var v = line.trim().split(/\s+/).slice(1).map(Number);
                    var idle = v[3] + v[4], tot = v.reduce(function (a, b) { return a + b; }, 0);
                    if (w.prev && tot > w.prev[1]) w.cpu = Math.max(0, Math.min(1, 1 - (idle - w.prev[0]) / (tot - w.prev[1])));
                    w.prev = [idle, tot];
                } else if (line.indexOf("MemTotal") === 0) total = parseInt(line.split(/\s+/)[1]);
                else if (line.indexOf("MemAvailable") === 0) {
                    avail = parseInt(line.split(/\s+/)[1]);
                    if (total > 0) { w.ram = (total - avail) / total; w.ramUsedGb = (total - avail) / 1048576; w.ramTotalGb = total / 1048576; }
                }
            }
        }
    }
    onPropsChanged: if (poll.running) { poll.running = false; Qt.callLater(function () { poll.running = true; }); }

    // rings
    Row {
        visible: (w.props ? w.props.mode : "") === "rings"
        anchors.fill: parent
        Repeater {
            model: (w.props ? w.props.mode : "") === "rings" ? w.items : []
            delegate: Item {
                required property var modelData
                width: w.width / Math.max(1, w.items.length); height: w.height
                Ring {
                    anchors.centerIn: parent
                    width: Math.min(parent.width * 0.92, parent.height * 0.98); height: width
                    value: modelData.v
                    barColor: w.style.accent
                    trackColor: Qt.rgba(1, 1, 1, 0.13)
                    Behavior on value { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Column {
                        anchors.centerIn: parent
                        spacing: -2
                        GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.style.font_size * 1.7; text: Math.round(modelData.v * 100) + "%" }
                        GText { anchors.horizontalCenter: parent.horizontalCenter; wstyle: w.style; opacity: 0.6; font.pixelSize: w.style.font_size * 0.85; text: modelData.name }
                    }
                }
            }
        }
    }
    // bars
    Column {
        visible: (w.props ? w.props.mode : "") === "bars"
        anchors.fill: parent
        spacing: 0
        Repeater {
            model: (w.props ? w.props.mode : "") === "bars" ? w.items : []
            delegate: Item {
                required property var modelData
                width: w.width; height: w.height / Math.max(1, w.items.length)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: w.style.font_size * 2.6
                    GText { wstyle: w.style; font.bold: true; text: modelData.name }
                    GText { anchors.right: parent.right; wstyle: w.style; opacity: 0.65; font.pixelSize: w.style.font_size * 0.9; text: modelData.text }
                    Rectangle { y: parent.height - height; width: parent.width; height: Math.max(4, w.style.font_size * 0.55); radius: height / 2; color: Qt.rgba(1, 1, 1, 0.13)
                        Rectangle { width: Math.max(parent.height, parent.width * modelData.v); height: parent.height; radius: height / 2; color: w.style.accent
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
                    }
                }
            }
        }
    }
}
