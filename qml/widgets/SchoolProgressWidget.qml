// School progress: how much of the school day or the school week is over - counted in lessons of the timetable (cancelled lessons do not count),
// shown as a ring with the percentage. Click = switch between day and week (saved). Data: the cache of the timetable widget (timetable/untis.py writes it);
// when that is older than 25 minutes (no timetable widget on the desktop) this widget refreshes it itself. Logic: timetable/Model.js.
// Look: the shared glass panel only - this item draws NO fill, NO tint: a ring, text.
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../core"
import "timetable/Model.js" as M

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})
    property bool persistent: false
    signal persistRequested(string key, var value)

    readonly property real fs: style.font_size || 16
    function s(v) { return v * fs / 16; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: style.accent || "#8ab4ff"
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("timetable/").toString().replace("file://", ""))
    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/widgetdeck/timetable.json"

    property date now: new Date()
    Timer { interval: 30000; repeat: true; running: w.live; onTriggered: w.now = new Date() }
    onLiveChanged: if (live) { now = new Date(); fileView.reload(); }

    // ---- data: the timetable cache (read only), refreshed here only when nobody else keeps it fresh
    property var d: null
    readonly property var lessons: d && d.lessons ? d.lessons : []
    readonly property bool hasData: d !== null && lessons.length > 0
    FileView {
        id: fileView
        path: w.cachePath
        watchChanges: true
        printErrors: false
        onLoaded: { try { const o = JSON.parse(text()); if (o && o.lessons) w.d = o; } catch (e) { } w.maybeFetch(); }
        onLoadFailed: err => w.maybeFetch()
        onFileChanged: reload()
    }
    function maybeFetch() {
        if (!live || fetch.running) return;
        var age = d && d.fetched ? Date.now() / 1000 - d.fetched : 1e9;
        if (age > 25 * 60) { fetch.command = ["python3", "-I", w.dir + "untis.py", "fetch"]; fetch.running = true; }
    }
    Process { id: fetch; stdout: StdioCollector { onStreamFinished: fileView.reload() } }
    Timer { interval: 600000; repeat: true; running: w.live; onTriggered: w.maybeFetch() }

    // ---- what is shown
    readonly property string mode: props.mode === "day" ? "day" : "week"
    readonly property var pr: M.schoolProgress(lessons, now, props.group ? String(props.group) : "", mode)
    readonly property bool empty: !hasData || pr.total === 0
    readonly property string label: (mode === "day" ? I18n.tr("School day") : I18n.tr("School week")).toUpperCase()
    readonly property string note: !hasData ? I18n.tr("No timetable") : (pr.total === 0 ? (mode === "day" ? I18n.tr("No lessons today") : I18n.tr("No lessons")) : (props.show_count !== false ? I18n.trf("%1 of %2 lessons", pr.done, pr.total) : ""))

    readonly property real dia: Math.min(width, height)
    Ring {
        id: ring
        anchors.centerIn: parent
        width: w.dia; height: w.dia
        value: w.empty ? 0 : w.pr.percent / 100
        barColor: w.cAcc
        trackColor: Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.16)
        thickness: w.dia * 0.075
        opacity: w.empty ? 0.35 : 1
    }
    Column {
        anchors.centerIn: parent
        width: w.dia * 0.7
        spacing: w.s(1)
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wstyle: w.style; font.bold: true; font.letterSpacing: 1.2; font.pixelSize: w.fs * 0.62; color: w.cAcc; opacity: 0.95; text: w.label }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wstyle: w.style; font.weight: Font.Light; font.pixelSize: w.dia * 0.26; font.features: { "tnum": 1 }
                text: w.empty ? "–" : w.pr.percent + " %" }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: w.style; opacity: 0.85; font.pixelSize: w.fs * 0.68; text: w.note }
    }
    MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: { var m = w.mode === "week" ? "day" : "week"; if (w.persistent) w.persistRequested("mode", m); }
    }
}
