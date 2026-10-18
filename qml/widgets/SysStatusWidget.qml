// Uptime and system status: run time (days / hours / minutes), kernel, failed systemd units (system + user).
// Feed: sysmon/sysstatus.sh every 30 s while the widget is on screen; the run time keeps counting locally in between.
// 0 failures: a calm "OK". Otherwise a warning in the theme's error colour with up to 3 unit names, then "+N".
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

    property var d: ({ up: 0, kernel: "", sys: [], user: [] })
    property double sampleMs: Date.now()
    property double nowMs: Date.now()
    readonly property double upSec: d.up + Math.max(0, nowMs - sampleMs) / 1000
    readonly property int days: Math.floor(upSec / 86400)
    readonly property int hours: Math.floor(upSec % 86400 / 3600)
    readonly property int mins: Math.floor(upSec % 3600 / 60)
    readonly property var failed: (d.sys || []).concat(d.user || [])
    readonly property bool ok: failed.length === 0

    Process {
        id: poll
        command: ["bash", w.dir + "sysstatus.sh"]
        stdout: StdioCollector {
            onStreamFinished: { try { w.d = JSON.parse(this.text); w.sampleMs = Date.now(); w.nowMs = w.sampleMs; } catch (e) { } }
        }
    }
    Timer {                                                         // fresh reading when the widget appears and every N seconds (default 30)
        interval: Math.max(5, Number(w.props.poll_s || 30)) * 1000; repeat: true; running: w.live; triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }
    Timer { interval: 10000; repeat: true; running: w.live; onTriggered: w.nowMs = Date.now() }     // the clock part counts locally

    Column {
        id: up
        anchors { left: parent.left; top: parent.top }
        spacing: w.s(2)
        GText { wstyle: w.style; opacity: 0.6; font.bold: true; font.pixelSize: w.fs * 0.68; text: I18n.tr("UPTIME") + (w.d.kernel && w.props.show_kernel !== false ? "   ·   Linux " + w.d.kernel : "") }
        Row {
            spacing: w.s(10)
            Repeater {
                model: [ { n: w.days, u: w.days === 1 ? I18n.tr("day") : I18n.tr("days") }, { n: w.hours, u: I18n.tr("h") }, { n: w.mins, u: I18n.tr("min") } ]
                delegate: Row {
                    spacing: w.s(4)
                    GText { id: num; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 2.1; text: modelData.n }
                    GText { anchors.baseline: num.baseline; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.75; color: w.cAcc; text: modelData.u }
                }
            }
        }
    }

    Rectangle {                                                     // hairline between the blocks
        anchors { left: parent.left; right: parent.right; bottom: status.top; bottomMargin: w.s(10) }
        height: 1; color: Qt.alpha(w.cFg, 0.12)
    }
    Column {
        id: status
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: w.s(4)
        Row {
            spacing: w.s(8)
            Icon { anchors.verticalCenter: parent.verticalCenter; name: w.ok ? "check" : "warning"; width: w.fs * 1.4; height: width; color: w.ok ? w.cAcc : w.cErr }
            GText {
                anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 1.0
                color: w.ok ? w.style.fg : w.cErr
                text: w.ok ? "OK" : (w.failed.length === 1 ? I18n.tr("1 service failed") : I18n.trf("%1 services failed", w.failed.length))
            }
        }
        Repeater {                                                  // at most three names, then "+N"
            model: Math.min(3, w.failed.length)
            delegate: GText {
                width: parent.width; elide: Text.ElideMiddle; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.78; color: w.cErr
                text: "  " + w.failed[index] + ((w.d.user || []).indexOf(w.failed[index]) >= 0 && (w.d.sys || []).indexOf(w.failed[index]) < 0 ? "  (user)" : "")
            }
        }
        GText { visible: w.failed.length > 3; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.78; color: w.cErr; text: "  +" + (w.failed.length - 3) }
        GText { visible: w.ok; wstyle: w.style; opacity: 0.6; font.pixelSize: w.fs * 0.78; text: I18n.tr("System and user services are running") }
    }
}
