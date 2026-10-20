// Monitor discovery: every connected, active, non-mirrored monitor with a STABLE key.
//   key  = make + model + serial (when the monitor reports a serial), else its description, else the connector name; two monitors that would get
//          the same key (identical models without serial) are told apart by the connector ("<key>@dp-1"). The connector alone is never the identity:
//          DP-1 can be another monitor after a restart.
//   data = Quickshell.screens (live, logical size) + `hyprctl -j monitors` (make, model, serial, position, scale, rotation, refresh rate,
//          reserved areas). Plug / unplug is noticed through Quickshell.screens and Hyprland's monitor events, debounced, no restart needed.
// Mirrored monitors count as one (the mirror is left out); disabled monitors do not exist for Hyprland and are therefore ignored.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQml
import "MonitorModel.js" as MM

Scope {
    id: mon
    property string preferredPrimary: ""          // config "monitors.primary" (a key); empty = automatic
    property var list: []                         // records, see rebuild()
    readonly property string primaryKey: {
        for (var i = 0; i < list.length; i++) if (list[i].key === preferredPrimary) return list[i].key;
        for (var j = 0; j < list.length; j++) if (list[j].x === 0 && list[j].y === 0) return list[j].key;
        return list.length > 0 ? list[0].key : "";
    }
    readonly property bool multi: list.length > 1
    property bool ready: false                    // the first hyprctl answer (or a timeout) has been processed
    property var hypr: []                         // last parsed `hyprctl -j monitors`
    property int rev: 0

    function byKey(k) { for (var i = 0; i < list.length; i++) if (list[i].key === k) return list[i]; return null; }
    function byName(n) { for (var i = 0; i < list.length; i++) if (list[i].name === n) return list[i]; return null; }
    function focused() { var f = Hyprland.focusedMonitor; return f ? byName(f.name) : null; }
    function at(x, y) { for (var i = 0; i < list.length; i++) { var m = list[i]; if (x >= m.x && x < m.x + m.w && y >= m.y && y < m.y + m.h) return m; } return null; }

    function rebuild() {
        var screens = Quickshell.screens, out = [], i, j;
        for (i = 0; i < screens.length; i++) {
            var s = screens[i], h = null;
            for (j = 0; j < hypr.length; j++) if (hypr[j].name === s.name) h = hypr[j];
            if (h && h.mirrorOf && h.mirrorOf !== "none" && String(h.mirrorOf) !== "-1") continue;      // a mirror shows what another monitor shows
            if (h && h.disabled) continue;
            var res = (h && h.reserved) ? h.reserved : [0, 0, 0, 0];                                     // left, top, right, bottom
            var W = s.width, H = s.height;
            var r = {
                key: "", base: MM.baseKey(h, s.name), name: s.name, screen: s, hyprId: h ? h.id : -1,
                make: h ? (h.make || "") : "", model: h ? (h.model || "") : (s.model || ""), serialKnown: !!(h && h.serial && String(h.serial) !== "0"),
                description: h ? (h.description || "") : "",
                x: h ? h.x : s.x, y: h ? h.y : s.y, w: W, h: H,
                pw: h ? h.width : W, ph: h ? h.height : H, scale: h ? h.scale : 1, refresh: h ? Math.round(h.refreshRate * 100) / 100 : 0,
                transform: h ? (h.transform || 0) : 0, vertical: H > W,
                reserved: res, area: Qt.rect(res[0], res[1], Math.max(100, W - res[0] - res[2]), Math.max(100, H - res[1] - res[3]))
            };
            out.push(r);
        }
        var keys = MM.uniqueKeys(out);
        for (i = 0; i < out.length; i++) out[i].key = keys[i];
        out.sort(function (a, b) { return a.x !== b.x ? a.x - b.x : a.y - b.y; });
        list = out;
        rev++;
    }

    function refresh() { debounce.restart(); }
    Timer { id: debounce; interval: 250; onTriggered: { if (!proc.running) proc.running = true; else again.restart(); } }
    Timer { id: again; interval: 400; onTriggered: debounce.restart() }
    Process {
        id: proc
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { var a = JSON.parse(text); if (Array.isArray(a)) mon.hypr = a; } catch (e) { }
                mon.ready = true;
                mon.rebuild();
            }
        }
        onExited: (code, status) => { if (code !== 0) { mon.ready = true; mon.rebuild(); } }      // no hyprctl: Quickshell's own data is all there is
    }
    // a mode / scale / position change of a monitor that stays connected: its screen object changes (and hyprctl is asked again)
    Instantiator {
        model: Quickshell.screens
        delegate: QtObject {
            required property var modelData
            property var conn: Connections {
                target: modelData
                function onWidthChanged() { mon.refresh(); }
                function onHeightChanged() { mon.refresh(); }
                function onXChanged() { mon.refresh(); }
                function onYChanged() { mon.refresh(); }
                function onDevicePixelRatioChanged() { mon.refresh(); }
            }
        }
    }
    Timer { interval: 15000; repeat: true; running: true; onTriggered: mon.refresh() }          // safety net: rotation / refresh rate changes carry no event
    // plug / unplug / mode change
    Connections { target: Quickshell; function onScreensChanged() { mon.rebuild(); mon.refresh(); } }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            var n = ev.name;
            if (n === "monitoradded" || n === "monitoraddedv2" || n === "monitorremoved" || n === "monitorremovedv2" || n === "configreloaded") mon.refresh();
        }
    }
    Component.onCompleted: { rebuild(); refresh(); }
    Timer { interval: 1500; running: !mon.ready; onTriggered: { mon.ready = true; mon.rebuild(); } }
}
