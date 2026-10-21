// The data of the F1 widget: ONE shared model for every widget instance on every monitor (one helper call, one cache, one set of requests).
// The helper (f1.py) decides by itself when the network is needed (calendar once a day, results / standings every few hours); this singleton
// only asks it every 15 minutes while at least one instance is watching, and keeps the answer for all of them.
// NOTE: no curly braces in the comment lines above "pragma Singleton" (Quickshell's scanner stops at the first one).
pragma Singleton
import QtQuick
import Quickshell
import "../../core"
import "circuits.js" as C

Singleton {
    id: hub
    property var d: null                          // the parsed answer of f1.py fetch
    property int watchers: 0                      // instances that are visible (or have reminders on)
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("./").toString().replace("file://", ""))
    property var notified: []                     // reminder ids already announced (this session of the shell)

    function watch(on) { watchers = Math.max(0, watchers + (on ? 1 : -1)); }
    function refresh() { feed.refresh(); }
    property var missingLogged: ({})
    // the outline of a circuit, or null: the card then shows no outline (calmly) and the shell log names the circuit once
    function circuit(id) {
        var c = C.CIRCUITS[id] || null;
        if (!c && id && !missingLogged[id]) { missingLogged[id] = true; console.warn("F1 widget: no track outline for circuit '" + id + "' (add it to tools/f1/circuit-map.json and run tools/f1/build_circuits.py)"); }
        return c;
    }

    Feed {
        id: feed
        key: "f1:fetch"
        command: ["python3", "-I", hub.dir + "f1.py", "fetch"]
        interval: 900000                          // 15 min: the helper answers from its cache unless a source is due
        active: hub.watchers > 0
        onGot: text => { try { var o = JSON.parse(text); if (o && o.state) hub.d = o; } catch (e) { if (!hub.d) hub.d = { state: "error", errors: ["parse"], fetched: 0 }; } }
    }
}
