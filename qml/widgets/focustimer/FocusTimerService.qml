// The focus timer: ONE shared timer for every widget instance and every monitor, living with the shell (not with a widget window), so hiding, moving,
// resizing a widget or unplugging its monitor never touches it. All logic is in Model.js (tested by tools/focus-timer-test.js); this file keeps it
// alive: the saved state, the statistics, the wake-up at the end of the phase, sound, notification and "do not disturb".
// Idle cost: nothing at all while the timer is paused; while it runs one timer that sleeps until the end of the phase (at most 20 s per sleep, so a
// computer that was asleep is noticed). A visible widget adds its own one-second tick; this service has none.
// NOTE: no curly braces in the comment lines above "pragma Singleton" (Quickshell's scanner stops at the first one).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"
import "Model.js" as M

Singleton {
    id: svc
    property var store: null                      // the layout / settings store (set by shell.qml)
    property var notifyItem: null                 // WidgetDeck's own notification module, when it runs (set by shell.qml)
    readonly property string dir: store ? store.dir : ""
    readonly property bool storeReady: !!store && store.loaded === true        // the saved state is read after the settings of the widgets are known
    readonly property string here: decodeURIComponent(Qt.resolvedUrl("./").toString().replace("file://", ""))

    // ---- settings: the props of the focus timer widgets (shared: every instance has the same ones); the last known ones when there is none
    property var lastSettings: ({})
    readonly property var settings: {
        if (!store) return M.cleanSettings(lastSettings);
        store.rev;
        var w = store.data.widgets, p = null;
        for (var i = 0; i < w.length; i++) if (w[i].type === "focustimer") { p = store.propsOf(w[i].id); break; }
        return M.cleanSettings(p ? p : lastSettings);
    }
    readonly property bool haveWidget: { if (!store) return false; store.rev; var w = store.data.widgets; for (var i = 0; i < w.length; i++) if (w[i].type === "focustimer") return true; return false; }
    readonly property var props: { if (!store) return ({}); store.rev; var w = store.data.widgets; for (var i = 0; i < w.length; i++) if (w[i].type === "focustimer") return store.propsOf(w[i].id); return ({}); }
    readonly property bool focusMode: props.focus_mode === true
    readonly property bool soundOn: props.sound !== false
    readonly property bool notifyOn: props.notify !== false
    readonly property real volume: Math.max(0, Math.min(100, Number(props.volume !== undefined ? props.volume : 70))) / 100

    // ---- the state (see Model.js); `rev` changes with every change of it, readers compute the remaining time from endsAt themselves
    property var st: M.fresh({})
    property int rev: 0
    readonly property string phase: st.phase
    readonly property int cycle: st.cycle
    readonly property bool running: st.running
    readonly property real endsAt: st.endsAt
    readonly property real remainingMs: st.remainingMs
    property bool loaded: false
    function now() { return Date.now(); }
    function remaining() { return M.remaining(st, now()); }
    function describe() { return M.describe(st, settings, now()); }
    function statusJson() {
        if (!loaded) return JSON.stringify({ state: "starting" });
        var d = describe(); d.today = { sessions: today.sessions, focus_minutes: today.minutes }; d.dnd = { backend: dndBackend0, active: dndOwned };
        return JSON.stringify(d);
    }

    // ---- statistics (per local day)
    property var stats: ({ v: 1, days: {} })
    property int dayRev: 0
    readonly property var today: { dayRev; rev; return M.today(stats, M.dateKey(new Date())); }

    // ---- commands (widgets, IPC, keybinds)
    function setState(s, event) {
        var was = st;
        st = s; rev++;
        if (event) handleEvent(event);
        persist(); arm(); syncDnd(was);
    }
    function start() { if (loaded && !st.running) setState(M.start(st, now()), null); }
    function pause() { if (loaded && st.running) setState(M.pause(st, now()), null); }
    function toggle() { if (loaded) setState(M.toggle(st, now()), null); }
    function reset() { if (loaded) setState(M.reset(settings), null); }
    function skip() { if (loaded) { var r = M.skip(st, settings, now()); setState(r.state, r.event); } }
    // the end of a phase (called by the wake-up, by the widgets' tick and after a restart)
    function check() { if (loaded && M.due(st, now())) { var r = M.finish(st, settings, now()); setState(r.state, r.event); } }

    function handleEvent(ev) {
        if (!ev) return;
        if (ev.completed && ev.seconds > 0) addSession(ev.seconds);
        if (!ev.completed) return;                                   // skipped: nothing to announce
        if (ev.late) { if (notifyOn) announce(ev, false); return; }  // it ended while nobody was looking: one quiet notice, no sound
        if (soundOn) playChime();
        if (notifyOn) announce(ev, true);
    }
    function announce(ev, afterRelease) {
        var title, body;
        if (ev.phase === "focus") { title = I18n.tr("Focus finished"); body = ev.next === "long" ? I18n.tr("Time for a long break.") : I18n.tr("Time for a short break."); }
        else { title = I18n.tr("Break over"); body = I18n.tr("Ready for the next focus session?"); }
        if (ev.late) body = body + " " + I18n.tr("(it ended while the computer was busy elsewhere)");
        pendingNote = { title: title, body: body };
        // "do not disturb" is lifted first (it was on during the focus phase): the notice must be seen; the daemon needs a moment to notice
        noteTimer.interval = (dndOwned && dndBackend === "flagfile") ? 1600 : 250;
        noteTimer.restart();
    }
    property var pendingNote: null
    Timer { id: noteTimer; onTriggered: { var n = svc.pendingNote; svc.pendingNote = null; if (n) Quickshell.execDetached(["notify-send", "-a", "WidgetDeck", "-i", "alarm-symbolic", "-u", "normal", n.title, n.body]); } }

    // ---- the wake-up: sleeps until the phase ends (at most 20 s at a time: the monotonic clock does not run during standby, the wall clock does)
    Timer {
        id: wake
        repeat: false
        onTriggered: { svc.check(); svc.arm(); }
    }
    function arm() {
        if (!st.running) { wake.stop(); return; }
        wake.interval = Math.max(30, Math.min(20000, st.endsAt - now() + 20));
        wake.restart();
    }
    // midnight: "today" starts over (one wake-up a day)
    Timer {
        id: midnight
        running: true; repeat: false
        interval: 1000
        onTriggered: { var d = new Date(); var next = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1, 0, 0, 1); interval = Math.max(1000, next.getTime() - d.getTime()); svc.dayRev++; restart(); }
    }

    // ---- saving
    property string lastStateText: ""
    function persist() {
        if (!loaded || dir === "") return;
        var o = { v: 1, phase: st.phase, cycle: st.cycle, running: st.running, endsAt: st.endsAt, remainingMs: st.remainingMs, settings: settings, dnd: { owned: dndOwned, backend: dndBackend } };
        var t = JSON.stringify(o);
        if (t === lastStateText) return;
        lastStateText = t; stateFile.setText(t);
    }
    FileView {
        id: stateFile
        path: svc.storeReady ? svc.dir + "/focus-state.json" : ""
        atomicWrites: true
        printErrors: false                        // no file yet on the first start is normal
        onLoaded: { svc.pendingState = text(); svc.stateDone = true; svc.tryRestore(); }
        onLoadFailed: err => { svc.pendingState = ""; svc.stateDone = true; svc.tryRestore(); }
    }
    property string lastStatsText: ""
    function saveStats(s) {
        stats = s; rev++;
        var t = JSON.stringify(s);
        if (t === lastStatsText) return;
        lastStatsText = t; statsFile.setText(t);
    }
    function addSession(seconds) { saveStats(M.addSession(stats, M.dateKey(new Date()), seconds)); }
    FileView {
        id: statsFile
        path: svc.storeReady ? svc.dir + "/focus-stats.json" : ""
        atomicWrites: true
        printErrors: false
        onLoaded: { svc.loadStats(text()); svc.statsDone = true; svc.tryRestore(); }
        onLoadFailed: err => { svc.loadStats(""); svc.statsDone = true; svc.tryRestore(); }
    }
    function loadStats(t) {
        var s = null;
        if (t && t.trim() !== "") { try { s = M.cleanStats(JSON.parse(t)); } catch (e) { s = null; } }
        if (s) { stats = s; lastStatsText = JSON.stringify(s); }
        else if (t && t.trim() !== "") {                                   // damaged: keep it for a look, start a new one, never crash
            Quickshell.execDetached(["sh", "-c", "cp -f \"$1\" \"$1.damaged-$(date +%Y%m%d-%H%M%S)\" 2>/dev/null", "sh", dir + "/focus-stats.json"]);
            console.warn("[focus-timer] focus-stats.json is damaged: a copy was kept (focus-stats.json.damaged-*), starting a new statistics");
            stats = ({ v: 1, days: {} }); lastStatsText = "";
        }
        rev++;
    }
    // the state is restored only when the statistics are known too: a phase that ended while the shell was away is counted into them
    property string pendingState: ""
    property bool stateDone: false
    property bool statsDone: false
    function tryRestore() { if (stateDone && statsDone && !loaded) restoreState(pendingState); }
    function restoreState(t) {
        var raw = null;
        if (t && t.trim() !== "") { try { raw = JSON.parse(t); } catch (e) { raw = null; console.warn("[focus-timer] focus-state.json is not valid, starting fresh"); } }
        if (raw && raw.settings) lastSettings = raw.settings;
        var r = M.restore(raw, settings, now());
        st = r.state; rev++;
        lastDur = { focus: M.durationMs(settings, "focus"), short: M.durationMs(settings, "short"), long: M.durationMs(settings, "long") };
        if (raw && raw.dnd && raw.dnd.owned === true) { dndOwned = true; dndBackend = String(raw.dnd.backend || ""); }
        loaded = true;
        if (r.event) handleEvent(r.event);
        persist(); arm();
        syncDnd(null);
    }
    Component.onCompleted: { detect.running = true; }
    Component.onDestruction: { releaseDndNow(); }

    // ---- settings that change while the timer is paused at its full length follow the new length
    property var lastDur: ({})
    onSettingsChanged: {
        if (loaded && !st.running && st.remainingMs === (lastDur[st.phase] || -1)) { st = { v: 1, phase: st.phase, cycle: st.cycle, running: false, endsAt: 0, remainingMs: M.durationMs(settings, st.phase) }; rev++; }
        lastDur = { focus: M.durationMs(settings, "focus"), short: M.durationMs(settings, "short"), long: M.durationMs(settings, "long") };
        if (loaded) { persist(); syncDnd(null); }
    }

    // ---- sound: a short own chime through the first player that exists
    property var players: []
    function playChime() {
        var f = here + "chime.wav", v = volume, p = players;
        if (p.length === 0 || v <= 0) return;
        var c = p[0];
        if (c === "pw-play") Quickshell.execDetached(["pw-play", "--volume=" + v.toFixed(2), f]);
        else if (c === "paplay") Quickshell.execDetached(["paplay", "--volume=" + Math.round(v * 65536), f]);
        else if (c === "ffplay") Quickshell.execDetached(["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", "-volume", String(Math.round(v * 100)), f]);
        else if (c === "canberra-gtk-play") Quickshell.execDetached(["canberra-gtk-play", "-f", f]);
        else Quickshell.execDetached(["aplay", "-q", f]);
    }
    Process {
        id: detect
        command: ["sh", "-c", "for p in pw-play paplay ffplay canberra-gtk-play aplay; do command -v $p >/dev/null 2>&1 && echo $p; done; echo '--'; sh \"$1/dnd.sh\" detect", "sh", svc.here.replace(/\/$/, "")]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n").map(function (x) { return x.trim(); }).filter(function (x) { return x !== ""; }), i = l.indexOf("--");
                svc.players = i >= 0 ? l.slice(0, i) : l;
                svc.detected = i >= 0 && l[i + 1] ? l[i + 1] : "none";
                svc.syncDnd(null);
            }
        }
    }
    property string detected: ""                  // dunst | mako | swaync | flagfile | none   ("widgetdeck" when the own notification module runs)
    readonly property string dndBackend0: notifyItem ? "widgetdeck" : detected
    property string dndBackend: ""
    property bool dndOwned: false                 // we switched "do not disturb" on and have to switch it off again
    property bool dndWasOn: false

    // ---- focus mode: notifications are silent during a running focus phase; what was there before is restored, a "do not disturb" the user set is never lifted
    readonly property bool wantDnd: loaded && focusMode && st.running && st.phase === "focus" && dndBackend0 !== "" && dndBackend0 !== "none"
    property bool dndBusy: false
    onWantDndChanged: syncDnd(null)
    function syncDnd(was) {
        if (!loaded || detected === "") return;
        if (wantDnd && !dndOwned && !dndBusy) engageDnd();
        else if (!wantDnd && dndOwned && !dndBusy) releaseDnd();
    }
    function dndGet(cb) {
        var b = dndBackend0;
        if (b === "widgetdeck") { cb(notifyItem && notifyItem.dnd ? "on" : "off"); return; }
        dndRun(["get", b], function (out) { cb(out.trim()); });
    }
    function dndSet(on, cb) {
        var b = dndBackend !== "" ? dndBackend : dndBackend0;
        if (b === "widgetdeck") { if (notifyItem) notifyItem.dnd = on; if (cb) cb(); return; }
        dndRun(["set", b, on ? "on" : "off"], function () { if (cb) cb(); });
    }
    function engageDnd() {
        dndBusy = true;
        dndGet(function (cur) {
            if (cur === "on" || cur === "unknown") { dndBusy = false; return; }          // already silent (the user's own): not ours, never touched
            dndBackend = dndBackend0; dndOwned = true; persist();
            dndSet(true, function () { dndBusy = false; syncDnd(null); });
        });
    }
    function releaseDnd() {
        dndBusy = true;
        dndGet(function (cur) {
            var b = dndBackend;
            dndOwned = false; dndBackend = ""; persist();
            if (cur === "on") dndSet(false, function () { dndBusy = false; syncDnd(null); });          // still our silence: lift it. Already off (the user lifted it): leave it
            else { dndBusy = false; syncDnd(null); }
            void b;
        });
    }
    // on exit: no async chain is possible any more
    function releaseDndNow() {
        if (!dndOwned) return;
        if (dndBackend === "widgetdeck") { if (notifyItem) notifyItem.dnd = false; return; }
        Quickshell.execDetached(["sh", here + "dnd.sh", "set", dndBackend, "off"]);
    }
    property var dndQueue: []
    function dndRun(args, cb) { dndQueue.push({ a: args, cb: cb }); if (!dndProc.running) dndNext(); }
    function dndNext() { if (dndQueue.length === 0) return; dndCur = dndQueue.shift(); dndProc.command = ["sh", here + "dnd.sh"].concat(dndCur.a); dndProc.running = true; }
    property var dndCur: null
    Process {
        id: dndProc
        stdout: StdioCollector { onStreamFinished: { var c = svc.dndCur; svc.dndCur = null; if (c && c.cb) c.cb(text); svc.dndNext(); } }
    }
}
