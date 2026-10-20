// Timetable (Untis Mobile): the current / next lesson in the small layout, a day timeline or a week grid in the large one.
// Data: timetable/untis.py (own timetable only, every 15 minutes while the widget is on screen, cached on disk, offline-safe).
// Logic without UI: timetable/Model.js (tested by tools/timetable-test.js). Look: the shared glass panel only - this item draws NO fill,
// NO tint and NO shapes; the theme colour sits on text, icons, rings and the borders of small active elements.
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
    property int configRev: 0
    property bool persistent: false                       // set by WidgetHost: persistRequested(key, value) is saved into the layout
    signal persistRequested(string key, var value)

    readonly property real fs: style.font_size || 16
    function s(v) { return v * fs / 16; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: style.accent || "#8ab4ff"
    readonly property color cCancel: palette.error || "#ff8a80"
    readonly property color cChange: "#7bd88f"          // substitution: semantic green
    readonly property color cExam: "#f2c94c"            // exam: semantic yellow
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("timetable/").toString().replace("file://", ""))

    // ---- data -------------------------------------------------------------------------------------------------------
    property var d: null
    readonly property string state: d ? d.state : ""
    readonly property var lessons: d && d.lessons ? d.lessons : []
    readonly property var grid: d && d.grid ? d.grid : ({})
    readonly property string group: props.group ? String(props.group) : ""
    readonly property bool hasData: lessons.length > 0 || (d && d.fetched > 0)
    property date now: new Date()
    readonly property var sum: M.summary(lessons, now, group)
    // ONE view state: props.default_view (today | tomorrow | week). A click writes it through persist(), so it is saved, restored at start,
    // shown in the builder and can be set from outside (IPC setProp). `localView` only stands in when no host saves the choice.
    property string localView: ""
    readonly property string shownView: persistent ? (props.default_view || "today") : (localView !== "" ? localView : (props.default_view || "today"))
    function setView(v) {
        if (v === shownView) return;
        if (persistent) persistRequested("default_view", v); else localView = v;
        if (live && d && d.fetched > 0 && Date.now() / 1000 - d.fetched > 300) run();     // older than 5 min: refresh in the background, the cache stays visible
    }
    readonly property bool compact: width < s(500) || height < s(290)
    readonly property string asOf: d && d.fetched ? Qt.formatTime(new Date(d.fetched * 1000), "HH:mm") : ""

    readonly property string srcKey: props.source ? String(props.source) : "auto"
    readonly property var srcArgs: props.source && props.source !== "auto" ? ["demo"].concat(String(props.source).indexOf("holiday") >= 0 ? ["holiday"] : []) : ["fetch"]
    // one fetch for all timetable widgets (and monitors) with the same source
    Feed {
        id: poll
        key: "timetable:" + w.srcArgs.join(",")
        command: ["python3", "-I", w.dir + "untis.py"].concat(w.srcArgs)
        interval: 900000                                   // 15 min, only while a widget is visible
        active: w.live
        onGot: text => { try { var o = JSON.parse(text); if (o && o.state) w.d = o; } catch (e) { if (!w.d) w.d = { state: "error", lessons: [], grid: {}, fetched: 0 }; } }
    }
    function run() { poll.refresh(); }
    onConfigRevChanged: if (live) run()
    Timer { interval: 30000; repeat: true; running: w.live; onTriggered: w.now = new Date() }                          // minute resolution is enough
    function openSetup() {
        var p = Quickshell.env("HOME") + "/.local/bin/widgetdeck-untis-setup";
        Quickshell.execDetached(["sh", "-c", "exec \"$1\" --terminal 2>/dev/null || exec widgetdeck-untis-setup --terminal", "sh", p]);
    }

    // ---- helpers ----------------------------------------------------------------------------------------------------
    function dayName(dt, long) { return Qt.locale().dayName(dt.getDay(), long ? Locale.LongFormat : Locale.ShortFormat); }
    function mdText(dt) { return Qt.locale().toString(dt, "d. MMM"); }
    function stateColor(st) { return st === "cancelled" ? cCancel : (st === "changed" ? cChange : (st === "exam" ? cExam : cAcc)); }
    function stateIcon(st) { return st === "cancelled" ? "cancel" : (st === "changed" ? "swap" : (st === "exam" ? "pencil" : "")); }
    function stateText(st) { return st === "cancelled" ? I18n.tr("Cancelled") : (st === "changed" ? I18n.tr("Substitution") : (st === "exam" ? I18n.tr("Exam") : "")); }
    function where(l) {
        var a = [];
        if (props.show_room !== false && l.room) a.push(l.room);
        if (props.show_teacher !== false && l.teacher) a.push(l.teacher);
        return a.join("  ·  ");
    }
    readonly property bool usable: state === "ok" || state === "stale" || state === "expired" || (d && d.source === "demo")
    readonly property string notice: {
        if (d && d.source === "demo") return I18n.tr("Demo data (invented)");
        if (state === "expired") return I18n.tr("Access expired - please set it up again");
        if (state === "stale" || state === "offline" || state === "error") return asOf !== "" ? I18n.tr("As of") + " " + asOf : "";
        return "";
    }

    // ---- states without data ----------------------------------------------------------------------------------------
    Column {
        anchors.centerIn: parent; width: parent.width - s(24); spacing: s(8)
        visible: !w.usable || (w.state !== "" && !w.hasData)
        opacity: visible ? 1 : 0
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: w.state === "unconfigured" ? "calendar" : (w.state === "expired" ? "warning" : "wifi-off"); width: s(34); height: width
               color: w.state === "expired" ? w.cCancel : w.cAcc }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 1.05
                text: w.state === "unconfigured" ? I18n.tr("Not set up yet. Connect your Untis Mobile access to see your timetable.")
                    : w.state === "expired" ? I18n.tr("Access expired - please set it up again")
                    : w.state === "" ? I18n.tr("Loading …") : I18n.tr("Could not load the timetable") }
        Rectangle {
            visible: w.state === "unconfigured" || w.state === "expired"
            anchors.horizontalCenter: parent.horizontalCenter; height: s(30); width: setupLabel.implicitWidth + s(28); radius: height / 2
            color: "transparent"; border.width: 1; border.color: setupMa.containsMouse ? w.cAcc : Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.4)
            GText { id: setupLabel; anchors.centerIn: parent; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.85; color: w.cAcc; text: I18n.tr("Set up") }
            MouseArea { id: setupMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.openSetup() }
        }
    }

    // ================================================== compact layout ==================================================
    Item {
        id: compactView
        anchors.fill: parent
        visible: opacity > 0.01 && w.usable
        opacity: w.compact && w.usable ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        readonly property var cur: w.sum.cur
        readonly property var main: cur ? cur : w.sum.next          // what the big block shows
        readonly property bool empty: w.sum.kind === "free" && !w.sum.next

        // big block: ring with the remaining minutes (running lesson) or the start time (next lesson)
        Item {
            id: bigBlock
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: w.s(66)
            Item {
                id: ringBox
                width: w.s(60); height: width; anchors.verticalCenter: parent.verticalCenter
                visible: compactView.main !== null
                Ring { anchors.fill: parent; value: compactView.cur ? M.progress(compactView.cur, M.minutesOf(w.now)) : 0; trackColor: Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.18); barColor: w.cAcc }
                GText { anchors.centerIn: parent; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * (compactView.cur ? 1.15 : 0.9)
                        text: compactView.cur ? M.remaining(compactView.cur, M.minutesOf(w.now)) + "'" : (compactView.main ? compactView.main.start : "") }
            }
            Column {
                anchors { left: ringBox.visible ? ringBox.right : parent.left; leftMargin: ringBox.visible ? w.s(14) : 0; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: w.s(1)
                GText { width: parent.width; elide: Text.ElideRight; wstyle: w.style; opacity: 0.82; font.bold: true; font.pixelSize: w.fs * 0.68
                        text: compactView.empty ? "" : (compactView.cur ? I18n.tr("NOW") : (w.sum.kind === "free" && w.sum.nextDay ? w.dayName(w.sum.nextDay, true).toUpperCase() + " " + w.mdText(w.sum.nextDay).toUpperCase() : I18n.tr("NEXT"))) }
                Row {
                    spacing: w.s(8)
                    GText { id: bigSubject; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 1.9
                            font.strikeout: !!compactView.main && compactView.main.main.state === "cancelled"
                            color: compactView.main ? w.stateColor(compactView.main.main.state === "normal" ? "normal" : compactView.main.main.state) : w.cFg
                            text: compactView.empty ? I18n.tr("Free") : (compactView.main ? compactView.main.main.subject : "") }
                    Icon { anchors.verticalCenter: parent.verticalCenter; visible: !!compactView.main && w.stateIcon(compactView.main.main.state) !== ""
                           name: compactView.main ? w.stateIcon(compactView.main.main.state) : ""; width: w.s(20); height: width; color: compactView.main ? w.stateColor(compactView.main.main.state) : w.cAcc }
                }
                GText { width: parent.width; elide: Text.ElideRight; wstyle: w.style; opacity: 0.9; font.pixelSize: w.fs * 0.85
                        text: compactView.main ? w.where(compactView.main.main) + (compactView.main.parallel > 0 ? "   " + I18n.trf("+%1 parallel", compactView.main.parallel) : "") : "" }
            }
        }
        // the lesson after the big block
        Rectangle { id: sepLine; anchors { left: parent.left; right: parent.right; top: bigBlock.bottom; topMargin: w.s(8) } height: 1; color: Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.14); visible: nextRow.visible }
        Row {
            id: nextRow
            anchors { left: parent.left; right: parent.right; top: sepLine.bottom; topMargin: w.s(8) }
            visible: !!compactView.cur && !!w.sum.next
            spacing: w.s(10)
            GText { wstyle: w.style; opacity: 0.82; font.bold: true; font.pixelSize: w.fs * 0.68; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("NEXT") }
            GText { wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.9; anchors.verticalCenter: parent.verticalCenter; text: w.sum.next ? w.sum.next.start : "" }
            GText { wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 1.0; anchors.verticalCenter: parent.verticalCenter
                    font.strikeout: !!w.sum.next && w.sum.next.main.state === "cancelled"
                    color: w.sum.next ? w.stateColor(w.sum.next.main.state === "normal" ? "normal" : w.sum.next.main.state) : w.cFg
                    text: w.sum.next ? w.sum.next.main.subject : "" }
            GText { wstyle: w.style; opacity: 0.88; font.pixelSize: w.fs * 0.8; anchors.verticalCenter: parent.verticalCenter; text: w.sum.next ? w.where(w.sum.next.main) : "" }
            Icon { anchors.verticalCenter: parent.verticalCenter; visible: !!w.sum.next && w.stateIcon(w.sum.next.main.state) !== ""
                   name: w.sum.next ? w.stateIcon(w.sum.next.main.state) : ""; width: w.s(16); height: width; color: w.sum.next ? w.stateColor(w.sum.next.main.state) : w.cAcc }
        }
        // a note of the shown lesson
        GText { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: w.notice !== "" ? w.s(16) : 0 } elide: Text.ElideRight; wstyle: w.style; opacity: 0.84; font.pixelSize: w.fs * 0.72
                text: compactView.main && compactView.main.main.note ? compactView.main.main.note : "" }
    }

    // ================================================== large layout ====================================================
    Item {
        id: largeView
        anchors.fill: parent
        visible: opacity > 0.01 && w.usable
        opacity: !w.compact && w.usable ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        readonly property bool isWeek: w.shownView === "week"
        readonly property date shownDate: w.shownView === "tomorrow" ? M.addDays(w.now, 1) : w.now
        readonly property var es: M.entries(w.lessons, M.ymd(shownDate), w.group)
        readonly property int curIdx: w.shownView === "today" ? M.currentIndex(es, M.minutesOf(w.now)) : -1
        readonly property int nextIdx: w.shownView === "today" ? M.nextIndex(es, M.minutesOf(w.now)) : -1
        // today <-> tomorrow: the list fades out, swaps and fades in (the glass underneath is not touched)
        property string lastView: w.shownView
        onEsChanged: {
            if (lastView !== w.shownView && dayList.visible) { lastView = w.shownView; swap.restart(); }
            else if (!swap.running) dayCol.shown = es;
        }
        Component.onCompleted: dayCol.shown = es
        SequentialAnimation {
            id: swap
            NumberAnimation { target: dayCol; property: "opacity"; to: 0; duration: 90; easing.type: Easing.OutCubic }
            ScriptAction { script: dayCol.shown = largeView.es }
            NumberAnimation { target: dayCol; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
        }

        // header: tabs + reload. Hit areas are at least 28 px; hover / press change size and position of the pill (never scale), the
        // active tab is marked by the accent colour on border and text (no fill on the glass).
        readonly property real hitH: Math.max(28, w.s(30))
        Row {
            id: tabs
            objectName: "tabs"
            anchors { left: parent.left; top: parent.top }
            spacing: w.s(2)
            Repeater {
                model: [["today", I18n.tr("Today")], ["tomorrow", I18n.tr("Tomorrow")], ["week", I18n.tr("Week")]]
                delegate: Item {
                    id: tab
                    required property var modelData
                    readonly property bool on: w.shownView === modelData[0]
                    height: largeView.hitH; width: tl.implicitWidth + w.s(20) + w.s(4) + 6
                    Rectangle {
                        id: pill
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: tma.pressed ? 1 : 0
                        height: w.s(26) + (tma.pressed ? -2 : (tma.containsMouse ? 2 : 0))
                        width: tl.implicitWidth + w.s(20) + (tma.pressed ? -2 : (tma.containsMouse ? 4 : 0))
                        radius: height / 2; color: "transparent"
                        border.width: 1
                        border.color: tab.on ? w.cAcc : (tma.containsMouse ? Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.45) : Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.16))
                        Behavior on border.color { ColorAnimation { duration: 160 } }
                        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    }
                    GText { id: tl; anchors.centerIn: pill; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.78; color: tab.on ? w.cAcc : w.cFg; opacity: tab.on ? 1 : (tma.containsMouse ? 0.95 : 0.75); text: modelData[1] }
                    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.setView(modelData[0]) }
                }
            }
        }
        GText { anchors { left: tabs.right; leftMargin: w.s(10); verticalCenter: tabs.verticalCenter; right: reload.left; rightMargin: w.s(8) } elide: Text.ElideRight; wstyle: w.style; opacity: 0.82; font.pixelSize: w.fs * 0.78
                visible: !largeView.isWeek
                text: w.dayName(largeView.shownDate, true) + ", " + w.mdText(largeView.shownDate) }
        Item {
            id: reload
            anchors { right: parent.right; verticalCenter: tabs.verticalCenter }
            width: largeView.hitH; height: width
            Icon { anchors.centerIn: parent; anchors.verticalCenterOffset: rma.pressed ? 1 : 0; width: w.s(16) + (rma.pressed ? -2 : (rma.containsMouse ? 2 : 0)); height: width; name: "refresh"
                   color: rma.containsMouse ? w.cAcc : w.cFg; opacity: 0.8
                   Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } } }
            MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: w.run() }
        }

        // ---- day timeline ----
        Flickable {
            id: dayList
            anchors { left: parent.left; right: parent.right; top: tabs.bottom; topMargin: w.s(10) - (largeView.hitH - w.s(26)); bottom: footer.top; bottomMargin: w.s(4) }
            clip: true; contentHeight: dayCol.height; boundsBehavior: Flickable.StopAtBounds
            visible: opacity > 0.01
            opacity: !largeView.isWeek ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Column {
                id: dayCol
                property var shown: []
                width: parent.width; spacing: w.s(3)
                GText { visible: dayCol.shown.length === 0; width: parent.width; wrapMode: Text.WordWrap; wstyle: w.style; opacity: 0.86; font.pixelSize: w.fs * 0.95
                        text: I18n.tr("No lessons (holidays or a day off)") }
                Repeater {
                    model: dayCol.shown
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property var l: modelData.main
                        readonly property bool isCur: index === largeView.curIdx
                        readonly property bool isNext: index === largeView.nextIdx
                        width: dayCol.width; height: w.s(32) + (l.note ? w.s(13) : 0)
                        GText { x: 0; width: w.s(44); anchors.top: parent.top; anchors.topMargin: w.s(5); wstyle: w.style; font.pixelSize: w.fs * 0.8; opacity: row.isCur || row.isNext ? 1 : 0.7; font.bold: row.isCur || row.isNext
                                color: row.isCur ? w.cAcc : w.cFg; text: modelData.start }
                        GText { x: w.s(48); width: w.s(54); anchors.top: parent.top; anchors.topMargin: w.s(3); wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 1.1
                                font.strikeout: row.l.state === "cancelled"; elide: Text.ElideRight
                                color: row.l.state === "normal" ? w.cFg : w.stateColor(row.l.state); text: row.l.subject }
                        GText { x: w.s(106); anchors.right: icons.left; anchors.rightMargin: w.s(8); anchors.top: parent.top; anchors.topMargin: w.s(6); elide: Text.ElideRight; wstyle: w.style; opacity: 0.9; font.weight: Font.DemiBold; font.pixelSize: w.fs * 0.82
                                font.strikeout: row.l.state === "cancelled"; text: w.where(row.l) }
                        Row {
                            id: icons
                            anchors { right: parent.right; top: parent.top; topMargin: w.s(6) }
                            spacing: w.s(6)
                            GText { visible: modelData.parallel > 0; wstyle: w.style; opacity: 0.88; font.pixelSize: w.fs * 0.74; anchors.verticalCenter: parent.verticalCenter; text: I18n.trf("+%1 parallel", modelData.parallel) }
                            Icon { visible: modelData.replaced; name: "swap"; width: w.s(15); height: width; color: w.cChange; anchors.verticalCenter: parent.verticalCenter }
                            Icon { visible: w.stateIcon(row.l.state) !== "" && !modelData.replaced; name: w.stateIcon(row.l.state); width: w.s(15); height: width; color: w.stateColor(row.l.state); anchors.verticalCenter: parent.verticalCenter }
                        }
                        GText { visible: row.l.note !== ""; x: w.s(48); width: parent.width - w.s(48); y: w.s(29); elide: Text.ElideRight; wstyle: w.style; opacity: 0.82; font.pixelSize: w.fs * 0.7; text: row.l.note }
                        // progress of the running lesson: a thin line under the row (no fill)
                        Rectangle { visible: row.isCur; x: 0; y: row.height - 2; height: 2; radius: 1; color: w.cAcc
                                    width: row.width * M.progress(modelData, M.minutesOf(w.now)); Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } } }
                        Rectangle { visible: row.isNext && largeView.curIdx < 0; x: 0; y: row.height - 2; width: row.width; height: 1; color: Qt.rgba(w.cAcc.r, w.cAcc.g, w.cAcc.b, 0.6) }
                    }
                }
            }
        }

        // ---- week grid ----
        Item {
            id: weekGrid
            anchors { left: parent.left; right: parent.right; top: tabs.bottom; topMargin: w.s(10) - (largeView.hitH - w.s(26)); bottom: footer.top; bottomMargin: w.s(4) }
            visible: opacity > 0.01
            opacity: largeView.isWeek ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            readonly property var days: M.weekDays(w.now)
            readonly property var rows: M.trimRows(M.gridRows(w.grid, days), w.lessons, days)
            readonly property bool none: { var set = {}, i; for (i = 0; i < days.length; i++) set[M.ymd(days[i])] = true; for (i = 0; i < w.lessons.length; i++) if (set[w.lessons[i].date]) return false; return true; }
            readonly property real labelW: w.s(22)
            readonly property real headH: w.s(18)
            readonly property real cw: (width - labelW) / 5
            readonly property real rh: rows.length > 0 ? Math.max(w.s(18), (height - headH) / rows.length) : w.s(24)
            GText { visible: weekGrid.none; anchors.centerIn: parent; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; wstyle: w.style; opacity: 0.86; font.pixelSize: w.fs * 0.95
                    text: I18n.tr("No lessons this week") }
            Repeater {
                model: weekGrid.days
                delegate: GText {
                    required property var modelData
                    required property int index
                    x: weekGrid.labelW + index * weekGrid.cw; width: weekGrid.cw; horizontalAlignment: Text.AlignHCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.72
                    opacity: M.ymd(modelData) === M.ymd(w.now) ? 1 : 0.6; color: M.ymd(modelData) === M.ymd(w.now) ? w.cAcc : w.cFg; text: w.dayName(modelData, false)
                }
            }
            Repeater {
                model: weekGrid.rows
                delegate: Item {
                    id: wrow
                    required property var modelData
                    required property int index
                    y: weekGrid.headH + index * weekGrid.rh; width: weekGrid.width; height: weekGrid.rh
                    GText { x: 0; width: weekGrid.labelW; anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; opacity: 0.75; font.pixelSize: w.fs * 0.68; text: wrow.modelData.label }
                    Repeater {
                        model: weekGrid.days
                        delegate: Item {
                            id: wcell
                            required property var modelData
                            required property int index
                            readonly property var e: M.cell(w.lessons, modelData, wrow.modelData.start, w.group)
                            readonly property bool isNow: e !== null && M.ymd(modelData) === M.ymd(w.now) && M.currentIndex([e], M.minutesOf(w.now)) === 0
                            x: weekGrid.labelW + index * weekGrid.cw; width: weekGrid.cw; height: wrow.height
                            Rectangle { visible: wcell.isNow; anchors { fill: parent; margins: 1 } color: "transparent"; radius: w.s(5); border.width: 1; border.color: w.cAcc }
                            Column {
                                anchors.centerIn: parent; width: parent.width - 4
                                visible: wcell.e !== null
                                GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.82
                                        font.strikeout: !!wcell.e && wcell.e.main.state === "cancelled"
                                        color: wcell.e ? (wcell.e.main.state === "normal" ? w.cFg : w.stateColor(wcell.e.main.state)) : w.cFg
                                        text: wcell.e ? wcell.e.main.subject + (wcell.e.parallel > 0 ? " +" + wcell.e.parallel : "") : "" }
                                GText { visible: weekGrid.rh > w.s(30) && w.props.show_room !== false; width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: w.style; opacity: 0.82; font.pixelSize: w.fs * 0.62
                                        text: wcell.e ? wcell.e.main.room : "" }
                            }
                        }
                    }
                }
            }
        }

        GText { id: footer; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: w.notice !== "" ? Math.round(w.fs * 0.7 * 1.35) : 0; elide: Text.ElideRight; wstyle: w.style; font.pixelSize: w.fs * 0.7
                color: w.state === "expired" ? w.cCancel : w.cFg; opacity: 0.86; text: w.notice
                MouseArea { anchors.fill: parent; enabled: w.state === "expired"; cursorShape: Qt.PointingHandCursor; onClicked: w.openSetup() } }
    }

    // compact: the "as of" / expired notice
    GText { visible: w.compact && w.usable && w.notice !== ""; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } elide: Text.ElideRight; wstyle: w.style; font.pixelSize: w.fs * 0.7
            color: w.state === "expired" ? w.cCancel : w.cFg; opacity: 0.86; text: w.notice
            MouseArea { anchors.fill: parent; enabled: w.state === "expired"; cursorShape: Qt.PointingHandCursor; onClicked: w.openSetup() } }
}
