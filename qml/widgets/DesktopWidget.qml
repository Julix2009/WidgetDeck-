// One desktop widget as a layer-shell surface BELOW all windows.
// Namespaces: "widgetdeck" (frosted: Hyprland blurs it through the layerrule) and "widgetdeck-liquid"
// (liquid glass draws its own blur; like the MacShell widget layer it needs no layerrule - a blur rule would
// also blur the soft shadow band around the glass).
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

PanelWindow {
    id: win
    required property string inst                 // "<widget id>|<monitor key>": one window per widget AND monitor it is shown on
    required property var store
    required property var theme
    required property var backend
    required property var wall                    // Wallpaper.qml (all monitors)
    required property var mons                    // Monitors.qml
    property string ns: "widgetdeck"

    readonly property string wid: inst.split("|")[0]
    readonly property string monKey: inst.substring(inst.indexOf("|") + 1)
    readonly property var rec: mons.byKey(monKey)          // null once the monitor is gone: the shell destroys this window in the same moment
    readonly property size screenSize: rec ? Qt.size(rec.w, rec.h) : Qt.size(2560, 1600)
    // the glass of this widget refracts the picture of ITS monitor
    MonitorWall { id: monWall; wall: win.wall; key: win.monKey; name: win.rec ? win.rec.name : "" }

    // Sharp on every scale: with a fractional scale (1.25, 1.5 ...) a window whose position or size is not a whole number of PHYSICAL pixels is
    // resampled by the compositor and looks soft. So the geometry used for drawing is rounded to the smallest logical step that is a whole number
    // of physical pixels (1.25 -> 4, 1.5 -> 2, 1.75 -> 4, whole scales -> 1). The stored layout is not changed; the shift is at most half a step.
    readonly property real monScale: rec && rec.scale > 0 ? rec.scale : 1
    readonly property int snapStep: {
        for (var n = 1; n <= 6; n++) { var v = n * win.monScale; if (Math.abs(v - Math.round(v)) < 0.03) return n; }
        return 1;
    }
    function snap(v) { return Math.round(v / win.snapStep) * win.snapStep; }
    readonly property var cfg: {
        store.geomRev; store.mons;
        var c = store.cfgFor(wid, monKey) || ({ id: wid, type: "blank", x: 0, y: 0, w: 10, h: 10, style: {}, props: {} });
        if (win.snapStep === 1) return c;
        return Object.assign({}, c, { x: win.snap(c.x), y: win.snap(c.y), w: Math.max(win.snapStep, win.snap(c.w)), h: Math.max(win.snapStep, win.snap(c.h)) });
    }
    readonly property real pad: Math.max(win.snapStep, win.snap(56))

    screen: rec ? rec.screen : null
    visible: rec !== null
    color: "transparent"
    anchors { left: true; top: true }
    margins { left: win.cfg.x - win.pad; top: win.cfg.y - win.pad }
    implicitWidth: win.cfg.w + 2 * win.pad
    implicitHeight: win.cfg.h + 2 * win.pad
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: win.ns
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: host }

    WidgetHost {
        id: host
        x: win.pad; y: win.pad
        store: win.store; theme: win.theme; cfg: win.cfg
        backend: win.backend; wall: monWall
        screenSize: win.screenSize
        padPx: win.pad
    }
}
