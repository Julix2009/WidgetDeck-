// Formula 1 (unofficial fan widget): the next race weekend - track outline, countdown, all sessions in local time, last result and standings.
// Data: f1/F1Data.qml (ONE shared model for every instance and monitor; helper f1/f1.py: Jolpica-F1, cached, rate-limit aware). The outline comes
// from f1/circuits.js (own, pre-processed paths). Look: the shared glass panel only - this item draws NO fill, NO tint, no shapes on the glass but
// text, thin lines and the outline. Logic without UI: f1/Model.js (tested by tools/f1-test.js).
import QtQuick
import QtQuick.Window
import Quickshell
import "../core"
import "f1"
import "f1/Model.js" as M

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})
    property int configRev: 0
    property var appConfig: ({})

    readonly property real fs: style.font_size || 16
    function s(v) { return v * fs / 16; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: style.accent || "#8ab4ff"
    readonly property color cErr: palette.error || "#ff8a80"
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property bool liquid: style.mode === "liquid"
    readonly property string lang: I18n.lang
    readonly property bool twelve: M.use12h(props.time_format && props.time_format !== "auto" ? props.time_format : (appConfig && appConfig.time_format), Qt.locale().timeFormat(Locale.ShortFormat))
    // 0 = small layout, 1 = large layout, continuous while the size animates (everything below interpolates: no layout jumps)
    readonly property real u: Math.max(0, Math.min(1, (width - s(384)) / s(160)))
    readonly property real f: Math.max(0, Math.min(1, (u - 0.55) / 0.45))       // sessions, results (the large layout)
    readonly property real g: Math.max(0, Math.min(1, (u - 0.1) / 0.3))         // fine lines that only fit when there is room
    function lerp(a, b) { return a + (b - a) * u; }

    // ---- data: the shared model (real) or the helper's invented scenario (test switch) --------------------------------------
    readonly property string dbgScenario: props.debug_scenario && props.debug_scenario !== "auto" ? String(props.debug_scenario) : ""
    readonly property string dbgCircuit: props.debug_circuit && props.debug_circuit !== "auto" ? String(props.debug_circuit) : ""
    property var demoData: null
    Feed {
        id: demoFeed
        key: "f1:demo:" + w.dbgScenario + ":" + w.dbgCircuit
        command: ["python3", "-I", F1Data.dir + "f1.py", "demo", w.dbgScenario || "weekend", w.dbgCircuit]
        interval: 60000
        active: w.dbgScenario !== "" || w.dbgCircuit !== ""
        onGot: text => { try { w.demoData = JSON.parse(text); } catch (e) { } }
    }
    readonly property bool demoOn: dbgScenario !== "" || dbgCircuit !== ""
    readonly property var fd: demoOn ? demoData : F1Data.d
    readonly property bool wantsData: live || props.reminder === true
    onWantsDataChanged: F1Data.watch(wantsData)
    Component.onCompleted: { if (wantsData) F1Data.watch(true); }
    Component.onDestruction: if (wantsData) F1Data.watch(false)
    onConfigRevChanged: if (live && !demoOn) F1Data.refresh()

    property date now: new Date()
    readonly property var st: M.stateOf(fd, now)
    readonly property string stKey: st.kind + ":" + (st.race ? st.race.round : "") + ":" + (st.race ? st.race.circuitId : "")
    // what is on screen: the state blends over (cross-fade) when the kind or the weekend changes, otherwise it follows the clock
    property var shown: st
    property bool swapping: false
    Binding { target: w; property: "shown"; value: w.st; when: !w.swapping }
    onStKeyChanged: if (shown && shown.kind !== undefined && stKey !== shownKey) swap.restart()
    readonly property string shownKey: shown.kind + ":" + (shown.race ? shown.race.round : "") + ":" + (shown.race ? shown.race.circuitId : "")
    SequentialAnimation {
        id: swap
        ScriptAction { script: w.swapping = true }
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: 140; easing.type: Easing.OutCubic }
        ScriptAction { script: { w.shown = w.st; w.swapping = false; } }
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
    }
    readonly property var race: shown.race || null
    readonly property var raceT: race ? M.raceStart(race) : null
    readonly property var target: shown.kind === "upcoming" ? raceT : (shown.kind === "running" ? raceT : null)
    readonly property var nextSession: { var l = shown.sessions || []; for (var i = 0; i < l.length; i++) if (l[i].state === "next") return l[i]; return null; }
    readonly property var circuit: race && props.show_track !== false ? F1Data.circuit(race.circuitId) : null
    readonly property bool hasTrack: !!circuit && shown.kind !== "seasonend" && shown.kind !== "empty"
    Timer {                                                       // 1 s in the last hour before a start, else once a minute; only the text changes, never the glass
        id: tick
        interval: M.tickMs(w.nextSession ? w.nextSession.start : w.target, w.now)
        repeat: true; running: w.live || w.props.reminder === true
        onTriggered: w.now = new Date()
    }
    Timer { interval: 60000; repeat: true; running: w.live; onTriggered: if (!w.demoOn && w.fd && w.fd.state !== "ok") F1Data.refresh() }
    // a race has just finished: ask now and then for the result (the helper itself asks the source at most every 10 minutes)
    Timer { interval: 300000; repeat: true; running: w.live && !w.demoOn && w.shown.kind === "finished"; onTriggered: F1Data.refresh() }

    // ---- live view (OpenF1, optional): only while a session is running and the widget is visible ---------------------------------
    property var liveD: null
    readonly property bool liveWanted: props.live_data === true && live && !demoOn && shown.kind === "running"
    Feed {
        key: "f1:live"
        command: ["python3", "-I", F1Data.dir + "f1.py", "live"]
        interval: 15000
        active: w.liveWanted
        onGot: text => { try { w.liveD = JSON.parse(text); } catch (e) { } }
    }
    onLiveWantedChanged: if (!liveWanted) liveD = null
    readonly property bool liveOk: liveWanted && !!liveD && liveD.running === true
    function flagText(f) { return f === "GREEN" || f === "CLEAR" ? I18n.tr("Green flag") : f === "YELLOW" || f === "DOUBLE YELLOW" ? I18n.tr("Yellow flag") : f === "RED" ? I18n.tr("Red flag") : f === "CHEQUERED" ? I18n.tr("Chequered flag") : f === "SC" ? I18n.tr("Safety car") : ""; }
    function flagColor(f) { return f === "RED" ? "#ff6b5e" : (f === "YELLOW" || f === "DOUBLE YELLOW" || f === "SC") ? "#f2c94c" : (f === "GREEN" || f === "CLEAR") ? "#7bd88f" : cFg; }

    // ---- reminders (optional): a notification N minutes before the chosen sessions -------------------------------------------------
    readonly property var remKeys: {
        var k = [];
        if (props.rem_practice === true) k = k.concat(["FirstPractice", "SecondPractice", "ThirdPractice"]);
        if (props.rem_quali !== false) k = k.concat(["Qualifying", "SprintQualifying"]);
        if (props.rem_race !== false) k = k.concat(["Race", "Sprint"]);
        return k;
    }
    Timer {
        interval: 30000; repeat: true; running: w.props.reminder === true && !w.demoOn; triggeredOnStart: true
        onTriggered: {
            if (!w.fd || !w.fd.races) return;
            var races = w.fd.races, now = new Date();
            for (var i = 0; i < races.length; i++) {
                if (races[i].cancelled) continue;
                var due = M.remindersDue(races[i], now, 15, w.remKeys, F1Data.notified);
                for (var j = 0; j < due.length; j++) {
                    F1Data.notified = F1Data.notified.concat([due[j].id]);
                    Quickshell.execDetached(["notify-send", "-a", "WidgetDeck", "-t", "20000", M.raceName(races[i].name, w.lang),
                                             I18n.trf("%1 starts at %2", w.sessionName(due[j].key), M.timeText(due[j].start, w.twelve))]);
                }
            }
        }
    }

    // ---- labels ---------------------------------------------------------------------------------------------------------------------------
    function sessionName(k) {
        return k === "FirstPractice" ? I18n.tr("Practice 1") : k === "SecondPractice" ? I18n.tr("Practice 2") : k === "ThirdPractice" ? I18n.tr("Practice 3")
             : k === "SprintQualifying" ? I18n.tr("Sprint qualifying") : k === "Sprint" ? I18n.tr("Sprint") : k === "Qualifying" ? I18n.tr("Qualifying") : k === "Race" ? I18n.tr("Race") : k;
    }
    function shortSession(k) { return k === "Qualifying" ? I18n.tr("Qualifying") : k === "Race" ? I18n.tr("Race") : sessionName(k); }
    readonly property var dayShort: [I18n.tr("Sun"), I18n.tr("Mon"), I18n.tr("Tue"), I18n.tr("Wed"), I18n.tr("Thu"), I18n.tr("Fri"), I18n.tr("Sat")]
    readonly property var monShort: [I18n.tr("Jan"), I18n.tr("Feb"), I18n.tr("Mar"), I18n.tr("Apr"), I18n.tr("May"), I18n.tr("Jun"), I18n.tr("Jul"), I18n.tr("Aug"), I18n.tr("Sep"), I18n.tr("Oct"), I18n.tr("Nov"), I18n.tr("Dec")]
    function dt(d) { return M.dateText(d, dayShort, monShort, lang); }
    function tm(d) { return M.timeText(d, twelve); }
    function dayOnly(s) { var p = String(s).split("-"); return p.length === 3 ? dt(new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]), 12)) : ""; }       // a published date without a time: the date as given
    function remaining(target) {                                    // "2 d 5 h" / "5 h 12 min" / "12 min 30 s"
        var p = M.parts(target, now);
        if (p.total < 3600) return p.m + " " + I18n.tr("min") + " " + p.s + " " + I18n.tr("s");
        if (p.d > 0) return p.d + " " + I18n.tr("d") + " " + p.h + " " + I18n.tr("h");
        return p.h + " " + I18n.tr("h") + " " + p.m + " " + I18n.tr("min");
    }
    readonly property bool emojiOk: Fonts.has("Noto Color Emoji") || Fonts.has("Twemoji Mozilla") || Fonts.has("Apple Color Emoji") || Fonts.has("JoyPixels") || Fonts.has("Segoe UI Emoji")
    readonly property string raceLine: {
        if (!race) return "";
        var d = raceT, base = d ? dt(d) + " · " + tm(d) : (race.date || "");
        return (race.moved_from ? I18n.tr("Postponed") + " · " : "") + I18n.tr("Race") + " " + base;
    }
    readonly property string countryText: race ? M.countryName(race.country, lang) : ""
    readonly property string flagText_: race && emojiOk ? M.flag(race.country) : ""      // no emoji font: no flag (the country is spelled out anyway)
    readonly property string asOf: fd && fd.checked ? Qt.formatTime(new Date(fd.checked * 1000), twelve ? "h:mm AP" : "HH:mm") : ""
    readonly property bool offline: !demoOn && fd && fd.state === "ok" && fd.stale === true

    // ================================================================================== content ==================================================================================
    Item {
        id: content
        anchors.fill: parent
        readonly property real hh: w.fs * 1.05
        readonly property real topY: hh + w.s(8)
        readonly property real topH: w.lerp(w.s(124), w.s(176))
        readonly property real footH: w.s(16)
        readonly property real trackW: w.hasTrack ? w.lerp(w.s(112), w.s(236)) : 0
        readonly property real trackH: Math.min(topH, w.lerp(w.s(92), w.s(168)))
        readonly property real leftW: Math.max(w.s(120), w.width - trackW - (trackW > 0 ? w.s(12) : 0))
        readonly property bool have: w.shown.kind !== "empty" && !!w.race || w.shown.kind === "seasonend"

        // header: title + round
        GText { x: 0; y: 0; wstyle: w.style; font.bold: true; font.letterSpacing: 1.4; font.pixelSize: w.fs * 0.68; opacity: 0.8; text: I18n.tr("Formula 1").toUpperCase() }
        GText {
            visible: w.race !== null && w.fd && w.fd.races && w.shown.kind !== "seasonend"
            anchors { right: parent.right } y: 0; opacity: w.g * 0.8; wstyle: w.style; font.pixelSize: w.fs * 0.68
            width: Math.max(0, parent.width - w.s(120)); horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
            text: w.race && w.fd && w.fd.races ? I18n.trf("Round %1 of %2", w.race.round, w.fd.total || w.fd.races.length) : ""
        }

        // ---- the main block: name, place, countdown, date -----------------------------------------------------------------------------
        Item {
            id: main
            visible: content.have
            x: 0; y: content.topY; width: content.leftW; height: content.topH
            GText {
                id: gpName
                x: 0; y: 0; width: parent.width; elide: Text.ElideRight; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * w.lerp(1.0, 1.28)
                text: w.shown.kind === "seasonend" ? I18n.tr("Season finished") : (w.race ? M.raceName(w.race.name, w.lang) : "")
            }
            GText {
                id: gpSub
                x: 0; y: gpName.height + w.s(1); width: parent.width; elide: Text.ElideRight; wstyle: w.style; opacity: 0.8; font.pixelSize: w.fs * 0.78
                visible: w.shown.kind !== "seasonend" && !!w.race
                text: {
                    if (!w.race) return "";
                    var c = w.flagText_ !== "" ? w.flagText_ + " " : "";
                    var ci = w.circuit ? w.circuit : null;
                    if (w.u < 0.5) return c + (w.race.locality !== "" ? w.race.locality + ", " : "") + w.countryText;
                    return c + (w.race.circuitName !== "" ? w.race.circuitName + " · " : "") + (w.race.locality !== "" ? w.race.locality + ", " : "") + w.countryText;
                }
            }

            // status / countdown (upcoming, running, finished, cancelled, season end)
            Item {
                id: cd
                x: 0; y: gpName.height + (gpSub.visible ? gpSub.height : 0) + w.s(8); width: parent.width; height: parent.height - y
                readonly property var p: w.target ? M.parts(w.target, w.now) : null
                readonly property var segs: {
                    if (!p) return [];
                    if (p.total < 3600) return [{ n: p.m, l: I18n.tr("min") }, { n: p.s, l: I18n.tr("s") }];
                    if (p.d > 0) return w.u > 0.5 ? [{ n: p.d, l: I18n.tr("d") }, { n: p.h, l: I18n.tr("h") }, { n: p.m, l: I18n.tr("min") }] : [{ n: p.d, l: I18n.tr("d") }, { n: p.h, l: I18n.tr("h") }];
                    return [{ n: p.h, l: I18n.tr("h") }, { n: p.m, l: I18n.tr("min") }];
                }
                // 1) the countdown to the race (upcoming) and below it the local date and time of the start
                Column {
                    visible: w.shown.kind === "upcoming" && !!w.target
                    spacing: w.s(2)
                    Row {
                        spacing: w.s(12)
                        Repeater {
                            model: cd.segs
                            delegate: Item {
                                required property var modelData
                                width: num.width + w.s(3) + lab.width; height: num.height
                                GText { id: num; wstyle: w.style; font.weight: Font.Light; font.pixelSize: w.fs * w.lerp(1.9, 3.1); font.features: { "tnum": 1 }; text: (modelData.l === I18n.tr("d") ? "" : (modelData.n < 10 ? "0" : "")) + modelData.n }
                                GText { id: lab; x: num.width + w.s(3); y: num.height - height - w.fs * 0.32; wstyle: w.style; opacity: 0.72; font.pixelSize: w.fs * 0.74; text: modelData.l }
                            }
                        }
                    }
                    GText { width: cd.width; elide: Text.ElideRight; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * w.lerp(0.88, 1.0); text: w.raceLine }
                }
                // race time unknown
                GText { visible: w.shown.kind === "upcoming" && !w.target; wstyle: w.style; opacity: 0.85; font.pixelSize: w.fs * 1.0; text: I18n.tr("Time open") }
                // 2) a session is running
                Column {
                    visible: w.shown.kind === "running"
                    spacing: w.s(2)
                    GText { wstyle: w.style; font.bold: true; font.letterSpacing: 1.2; color: w.cAcc; font.pixelSize: w.fs * w.lerp(1.0, 1.25); text: I18n.tr("Live now").toUpperCase() }
                    GText { wstyle: w.style; font.pixelSize: w.fs * w.lerp(0.9, 1.1); text: w.shown.running ? w.sessionName(w.shown.running.key) : "" }
                    GText { visible: !w.liveOk; width: cd.width; elide: Text.ElideRight; wstyle: w.style; opacity: 0.85; font.pixelSize: w.fs * 0.8; text: w.raceT ? I18n.tr("Race") + " " + w.dt(w.raceT) + " · " + w.tm(w.raceT) : "" }
                    GText {
                        visible: w.liveOk; wstyle: w.style; font.pixelSize: w.fs * 0.78; opacity: 0.95; width: cd.width; elide: Text.ElideRight
                        color: w.flagColor(w.liveD ? w.liveD.flag : ""); text: w.liveD ? w.flagText(w.liveD.flag) + (w.liveD.top && w.liveD.top.length ? "   " + w.liveD.top.map(function (t) { return t.pos + " " + t.code; }).join("  ") : "") : ""
                    }
                }
                // 3) finished
                Column {
                    visible: w.shown.kind === "finished"
                    spacing: w.s(2)
                    GText { wstyle: w.style; font.bold: true; font.pixelSize: w.fs * w.lerp(1.0, 1.3); text: I18n.tr("Race finished") }
                    GText { visible: !!w.shown.next; width: cd.width; elide: Text.ElideRight; wstyle: w.style; opacity: 0.8; font.pixelSize: w.fs * 0.8
                            text: w.shown.next ? I18n.tr("Next race") + ": " + M.raceName(w.shown.next.name, w.lang) : "" }
                }
                // 4) cancelled / postponed
                Column {
                    visible: w.shown.kind === "cancelled"
                    spacing: w.s(2)
                    GText { wstyle: w.style; font.bold: true; color: w.cErr; font.pixelSize: w.fs * w.lerp(1.0, 1.3); text: I18n.tr("Cancelled") }
                    GText { visible: !!w.shown.next; width: cd.width; elide: Text.ElideRight; wstyle: w.style; opacity: 0.8; font.pixelSize: w.fs * 0.8
                            text: w.shown.next ? I18n.tr("Next race") + ": " + M.raceName(w.shown.next.name, w.lang) + " · " + w.dt(M.raceStart(w.shown.next) || new Date(w.shown.next.date + "T12:00:00")) : "" }
                }
                // 5) season finished: the world champion
                Column {
                    visible: w.shown.kind === "seasonend"
                    spacing: w.s(2)
                    readonly property var champ: M.champion(w.fd)
                    GText { visible: !!parent.champ; width: cd.width; elide: Text.ElideRight; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * w.lerp(1.0, 1.3); text: parent.champ ? I18n.tr("World champion") + ": " + parent.champ.name : "" }
                    GText { width: cd.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; wstyle: w.style; opacity: 0.75; font.pixelSize: w.fs * 0.78; text: I18n.tr("The calendar of the next season is not available yet.") }
                }
            }
        }
        // ---- the track outline ----------------------------------------------------------------------------------------------------------------
        Track {
            id: track
            visible: w.hasTrack
            x: w.width - content.trackW; y: content.topY - w.s(4); width: content.trackW; height: content.trackH + w.s(4)
            circuit: w.circuit; runKey: w.race ? String(w.race.round) + w.race.circuitId : ""
            color: Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.92); lineWidth: w.lerp(w.s(2.6), w.s(3.4)); draw: w.props.draw_in !== false && w.props.animations !== "off"
        }
        // no outline for this circuit: nothing is drawn (the subtitle already names the circuit); F1Data.circuit() logs the missing outline once

        // ---- small layout: the key times in one line -----------------------------------------------------------------------------------------
        GText {
            visible: content.have && (w.shown.kind === "upcoming" || w.shown.kind === "running") && w.u < 0.98
            x: 0; y: content.topY + content.topH + w.s(24); width: parent.width; elide: Text.ElideRight; wstyle: w.style; opacity: (1 - w.f) * 0.8; font.pixelSize: w.fs * 0.74
            text: {
                var l = w.shown.sessions || [], out = [], i, q = null, r = null, show = [];
                for (i = 0; i < l.length; i++) { if (l[i].key === "Qualifying") q = l[i]; if (l[i].key === "Race") r = l[i]; }
                if (q) out.push(w.shortSession("Qualifying") + " " + (q.start ? w.dayShort[q.start.getDay()] + " " + w.tm(q.start) : I18n.tr("Time open")));
                if (r) out.push(w.shortSession("Race") + " " + (r.start ? w.dayShort[r.start.getDay()] + " " + w.tm(r.start) : I18n.tr("Time open")));
                return out.join(" · ");
            }
        }

        // ---- large layout: the sessions of the weekend -----------------------------------------------------------------------------------------
        readonly property real sessY: topY + topH + w.s(28)
        readonly property real rowH: w.s(27)
        Item {
            id: sessions
            visible: opacity > 0.02 && (w.shown.kind === "upcoming" || w.shown.kind === "running" || w.shown.kind === "finished")
            x: 0; y: content.sessY; width: parent.width; height: (w.shown.sessions || []).length * content.rowH
            opacity: w.f
            Rectangle { x: 0; y: -w.s(5); width: parent.width; height: 1; color: Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.16) }
            Repeater {
                model: w.shown.sessions || []
                delegate: Item {
                    id: srow
                    required property var modelData
                    required property int index
                    readonly property bool isRace: modelData.key === "Race"
                    readonly property bool past: modelData.state === "past"
                    width: sessions.width; height: content.rowH; y: index * content.rowH
                    opacity: past ? 0.5 : 1
                    // marker: a ring (accent) for the next session, a check for past ones, "live" for a running one
                    Item {
                        x: 0; anchors.verticalCenter: parent.verticalCenter; width: w.s(16); height: width
                        Icon { visible: srow.past; anchors.centerIn: parent; width: w.s(13); height: width; name: "check"; color: w.cFg }
                        Rectangle { visible: srow.modelData.state === "next"; anchors.centerIn: parent; width: w.s(10); height: width; radius: width / 2; color: "transparent"; border.width: 2; border.color: w.cAcc }
                        Rectangle { visible: srow.modelData.state === "running"; anchors.centerIn: parent; width: w.s(10); height: width; radius: width / 2; color: w.cAcc }
                    }
                    GText { x: w.s(24); anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.42; elide: Text.ElideRight; wstyle: w.style; font.bold: srow.isRace; font.pixelSize: w.fs * (srow.isRace ? 1.0 : 0.88)
                            color: srow.modelData.state === "next" || srow.modelData.state === "running" ? w.cAcc : w.cFg; text: w.sessionName(srow.modelData.key) }
                    GText { visible: srow.modelData.state === "running"; x: w.s(24) + parent.width * 0.42 - w.s(8); anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.pixelSize: w.fs * 0.68; font.bold: true; color: w.cAcc; text: "· " + I18n.tr("Live now") }
                    GText { anchors { right: timeCol.left; rightMargin: w.s(10); verticalCenter: parent.verticalCenter } wstyle: w.style; opacity: 0.8; font.pixelSize: w.fs * 0.84; text: srow.modelData.start ? w.dt(srow.modelData.start) : (srow.modelData.date ? w.dayOnly(srow.modelData.date) : "") }
                    GText { id: timeCol; anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: w.s(78); horizontalAlignment: Text.AlignRight; wstyle: w.style; font.bold: srow.isRace; font.pixelSize: w.fs * (srow.isRace ? 1.0 : 0.88); font.features: { "tnum": 1 }
                            text: srow.modelData.start ? w.tm(srow.modelData.start) : I18n.tr("Time open") }
                }
            }
        }
        // "next session in ..." under the sessions
        GText {
            visible: sessions.visible && !!w.nextSession && w.nextSession.key !== "Race" && w.shown.kind !== "finished"
            x: 0; y: content.sessY + sessions.height + w.s(2); width: parent.width; elide: Text.ElideRight; wstyle: w.style; opacity: w.f * 0.72; font.pixelSize: w.fs * 0.74
            text: w.nextSession && w.nextSession.start ? I18n.tr("Next session in") + " " + w.remaining(w.nextSession.start) + " · " + w.sessionName(w.nextSession.key) : ""
        }

        // ---- large layout: last result and standings -------------------------------------------------------------------------------------------
        readonly property real resY: sessY + (w.shown.sessions ? w.shown.sessions.length : 5) * rowH + w.s(32)
        readonly property real resH: Math.max(0, parent.height - resY - footH)
        readonly property int nStd: Math.max(3, Math.min(10, Number(w.props.standings !== undefined ? w.props.standings : 3)))
        Item {
            id: results
            visible: opacity > 0.02 && w.fd && (w.shown.kind !== "empty") && (w.props.show_results !== false || w.props.show_standings !== false)
            x: 0; y: content.resY; width: parent.width; height: content.resH
            opacity: w.f
            clip: true
            Rectangle { x: 0; y: -w.s(6); width: parent.width; height: 1; color: Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.16) }
            readonly property bool both: w.props.show_results !== false && w.props.show_standings !== false && !!w.fd && !!w.fd.last && !!w.fd.standings && w.fd.standings.length > 0
            readonly property real colW: both ? (width - w.s(18)) / 2 : width
            // last result
            Column {
                visible: w.props.show_results !== false && !!w.fd && !!w.fd.last
                x: 0; width: results.colW; spacing: 1
                GText { width: parent.width; elide: Text.ElideRight; wstyle: w.style; font.bold: true; font.letterSpacing: 1.0; opacity: 0.75; font.pixelSize: w.fs * 0.66
                        text: w.fd && w.fd.last ? (I18n.tr("Last result") + " · " + M.raceName(w.fd.last.name, w.lang)).toUpperCase() : "" }
                Repeater {
                    model: w.fd && w.fd.last ? w.fd.last.podium : []
                    delegate: Row {
                        required property var modelData
                        spacing: w.s(8); height: w.s(20)
                        GText { width: w.s(14); wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.84; text: modelData.pos }
                        GText { width: results.colW - w.s(24); elide: Text.ElideRight; wstyle: w.style; font.pixelSize: w.fs * 0.84; text: modelData.name + (modelData.team !== "" ? "  ·  " : "") + modelData.team }
                    }
                }
            }
            // driver standings
            Column {
                visible: w.props.show_standings !== false && !!w.fd && !!w.fd.standings && w.fd.standings.length > 0
                x: results.both ? results.colW + w.s(18) : 0; width: results.colW; spacing: 1
                GText { width: parent.width; elide: Text.ElideRight; wstyle: w.style; font.bold: true; font.letterSpacing: 1.0; opacity: 0.75; font.pixelSize: w.fs * 0.66; text: I18n.tr("Driver standings").toUpperCase() }
                Repeater {
                    model: w.fd && w.fd.standings ? w.fd.standings.slice(0, Math.max(0, Math.min(content.nStd, Math.floor((content.resH - w.s(18)) / w.s(20))))) : []
                    delegate: Row {
                        required property var modelData
                        spacing: w.s(8); height: w.s(20)
                        GText { width: w.s(14); wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.84; text: modelData.pos }
                        GText { width: results.colW - w.s(24) - w.s(52); elide: Text.ElideRight; wstyle: w.style; font.pixelSize: w.fs * 0.84; text: modelData.name }
                        GText { width: w.s(44); horizontalAlignment: Text.AlignRight; wstyle: w.style; opacity: 0.85; font.pixelSize: w.fs * 0.84; font.features: { "tnum": 1 }; text: modelData.points }
                    }
                }
            }
        }

        // ---- footer: as of / notices ------------------------------------------------------------------------------------------------------
        GText {
            visible: content.have && w.asOf !== "" && (w.offline || w.demoOn || w.shown.kind !== "empty") && (w.offline || w.demoOn)
            anchors { right: parent.right; bottom: parent.bottom } wstyle: w.style; opacity: 0.72; font.pixelSize: w.fs * 0.66
            text: w.demoOn ? I18n.tr("Demo data (invented)") : I18n.tr("As of") + " " + w.asOf
        }
        GText {
            visible: content.have && !!w.fd && !!w.fd.removed && w.fd.removed.length > 0 && w.shown.kind !== "seasonend"
            anchors { left: parent.left; bottom: parent.bottom } width: parent.width * 0.6; elide: Text.ElideRight; wstyle: w.style; color: w.cErr; opacity: 0.85; font.pixelSize: w.fs * 0.66
            text: w.fd && w.fd.removed && w.fd.removed.length > 0 ? I18n.tr("Cancelled") + ": " + M.raceName(w.fd.removed[0].name, w.lang) : ""
        }
    }

    // ---- no data yet / error ------------------------------------------------------------------------------------------------------------------
    Column {
        visible: !content.have
        anchors.centerIn: parent; width: parent.width - w.s(24); spacing: w.s(8)
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; wstyle: w.style; font.pixelSize: w.fs * 0.95; opacity: 0.8
                text: !w.fd ? I18n.tr("Loading …") : I18n.tr("No data yet") }
        Rectangle {
            visible: !!w.fd
            anchors.horizontalCenter: parent.horizontalCenter; height: w.s(30); width: reloadLabel.implicitWidth + w.s(28); radius: height / 2; color: "transparent"
            border.width: 1; border.color: rma.containsMouse ? w.cAcc : Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.4)
            GText { id: reloadLabel; anchors.centerIn: parent; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.85; color: w.cAcc; text: I18n.tr("Reload") }
            MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: F1Data.refresh() }
        }
    }
}
