// Shared data feeds: ONE process per feed, however many widget instances (on however many monitors) read it.
// A widget uses the Feed component (Feed.qml) with a key, a command and an interval: interval > 0 = one-shot every interval ms (the output is
// delivered whole), interval = 0 = long-running stream (one line at a time).
// A feed runs while at least one active reader exists; a new reader gets the last value at once. Readers with the same key share the process
// (the key must therefore contain everything that changes the command).
// NOTE: keep curly braces out of the comment lines above "pragma Singleton": Quickshell's scanner stops at the first line with a brace.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: feeds
    property var entries: ({})                      // key -> { key, command, interval, stream, clients, last, hasLast, stamp, node }
    property int running: 0                         // number of live feed processes (doctor / tests)
    function keys() { return Object.keys(entries).filter(function (k) { return entries[k].node && entries[k].node.active; }); }

    Component {
        id: nodeC
        Scope {
            id: nd
            property string fkey: ""                    // the entry is looked up by key (a JS object passed to createObject would be copied)
            readonly property var entry: feeds.entries[fkey]
            property bool active: false
            property var command: []
            function start() { active = true; if (entry.stream) { proc.running = true; } else tick.restart(); runOnce(); }
            function stop() { active = false; tick.stop(); proc.running = false; sproc.running = false; }
            function runOnce() { if (!entry.stream && !sproc.running) sproc.running = true; }
            Timer { id: tick; interval: Math.max(1000, nd.entry ? nd.entry.interval : 60000); repeat: true; onTriggered: nd.runOnce() }
            Process {                                                  // stream
                id: proc
                command: nd.command
                stdout: SplitParser { onRead: line => feeds.deliver(feeds.entries[nd.fkey], line) }
                onRunningChanged: if (!running && nd.active && nd.entry.stream) restart.start()          // the stream ended: start it again after a pause
            }
            Timer { id: restart; interval: 3000; onTriggered: if (nd.active && nd.entry.stream) proc.running = true }
            Process {                                                  // one-shot
                id: sproc
                command: nd.command
                stdout: StdioCollector { onStreamFinished: feeds.deliver(feeds.entries[nd.fkey], text) }
            }
            onActiveChanged: feeds.running = Object.keys(feeds.entries).filter(function (k) { return feeds.entries[k].node && feeds.entries[k].node.active; }).length
        }
    }

    function deliver(e, text) {
        if (!e) return;
        e.last = text; e.hasLast = true; e.stamp = Date.now();
        var dead = [];
        for (var i = 0; i < e.clients.length; i++) { try { e.clients[i].got(text); } catch (x) { dead.push(e.clients[i]); } }
        // a reader that is already destroyed (its window went away) throws: forget it; a feed nobody reads any more stops
        if (dead.length > 0) {
            e.clients = e.clients.filter(function (c) { return dead.indexOf(c) < 0; });
            if (e.clients.length === 0 && e.node) e.node.stop();
        }
    }
    function acquire(client) {
        var k = client.key, e = entries[k];
        if (!e) {
            e = { key: k, command: client.command, interval: client.interval, stream: client.interval <= 0, clients: [], last: "", hasLast: false, stamp: 0, node: null };
            entries[k] = e;
        }
        if (e.clients.indexOf(client) < 0) e.clients.push(client);
        if (!e.node) { e.node = nodeC.createObject(feeds, { fkey: e.key, command: e.command }); }
        if (!e.node.active) e.node.start();
        else if (e.hasLast) Qt.callLater(function () { if (e.clients.indexOf(client) >= 0) { try { client.got(e.last); } catch (x) { console.log("[widgetdeck] feed reader failed:", x); } } });     // late reader: the last value now
        // a reader that appears long after the last run: refresh
        if (!e.stream && e.hasLast && Date.now() - e.stamp > e.interval) e.node.runOnce();
    }
    function release(client, key) {
        var e = entries[key || client.key]; if (!e) return;
        var i = e.clients.indexOf(client); if (i >= 0) e.clients.splice(i, 1);
        if (e.clients.length === 0 && e.node) e.node.stop();
    }
    function refresh(key) { var e = entries[key]; if (e && e.node && e.node.active && !e.stream) e.node.runOnce(); }
    function lastOf(key) { var e = entries[key]; return e && e.hasLast ? e.last : ""; }
    function info() { var o = {}; for (var k in entries) o[k] = { clients: entries[k].clients.length, active: !!(entries[k].node && entries[k].node.active), stream: entries[k].stream }; return o; }
}
