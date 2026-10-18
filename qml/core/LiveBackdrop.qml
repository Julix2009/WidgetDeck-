// EXPERIMENTAL live backdrop for the builder window: wallpaper + the other windows, captured one by one
// with ScreencopyView and stacked at their Hyprland geometry (the builder itself is excluded).
//
// Known risk: many windows opening/closing quickly while captures are in flight can
// make the compositor drop the Wayland connection ("invalid object NNN"). Mitigations used here:
//   * while windows open/close nothing new is captured (hold), 0.5 s later the captures are released (cut)
//   * captures run at ~15 fps, one frame request per window, never `live: true`
//   * off by default; Settings -> "Live-Capture" switches it on/off at any time
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: lb
    required property var wall
    property size screenSize: Qt.size(2560, 1600)
    property string excludeTitle: "WidgetDeck"
    property bool capturing: true
    signal frame()

    width: screenSize.width; height: screenSize.height

    property var wins: []
    property bool hold: false
    property bool cut: false

    Image {
        anchors.fill: parent
        source: lb.wall.url
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: lb.screenSize.width
    }

    function refresh() {
        var ts = Hyprland.toplevels.values, ms = Hyprland.monitors.values, mon = null, out = [], i;
        for (i = 0; i < ms.length; i++) { var m = ms[i].lastIpcObject; if (m && m.focused) mon = m; }
        if (!mon && ms.length > 0) mon = ms[0].lastIpcObject;
        if (!mon) return;
        var ws = mon.activeWorkspace ? mon.activeWorkspace.id : -999;
        for (i = 0; i < ts.length; i++) {
            var o = ts[i].lastIpcObject;
            if (!o || o.address === undefined || o.title === lb.excludeTitle) continue;
            if (!o.mapped || o.hidden || !o.workspace || o.workspace.id !== ws) continue;
            out.push({ addr: o.address, x: o.at[0] - mon.x, y: o.at[1] - mon.y, w: o.size[0], h: o.size[1],
                       z: o.floating ? 100 - Math.min(o.focusHistoryID, 90) : 0, tl: ts[i].wayland });
        }
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
        wins = out;
    }
    Timer { interval: 120; repeat: true; running: lb.capturing; triggeredOnStart: true; onTriggered: lb.refresh() }
    Timer { interval: 66; repeat: true; running: lb.capturing && !lb.hold; onTriggered: lb.frame() }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "openwindow" || ev.name === "closewindow") { lb.hold = true; cutTimer.restart(); calm.restart(); }
        }
    }
    Timer { id: cutTimer; interval: 500; onTriggered: lb.cut = true }
    Timer { id: calm; interval: 1300; onTriggered: { lb.cut = false; lb.hold = false; } }

    Repeater {
        model: lb.cut ? [] : lb.wins
        delegate: Item {
            required property var modelData
            x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h; z: modelData.z
            ScreencopyView {
                id: sc
                anchors.fill: parent
                captureSource: modelData.tl
                live: false
                Timer {
                    interval: 66; repeat: true
                    running: lb.capturing && !lb.hold && sc.captureSource !== null
                    onTriggered: if (typeof sc.captureFrame === "function") sc.captureFrame()
                }
                onCaptureSourceChanged: if (captureSource !== null) first.restart()
                Timer { id: first; interval: 120; onTriggered: if (!lb.hold && typeof sc.captureFrame === "function") sc.captureFrame() }
            }
        }
    }
}
