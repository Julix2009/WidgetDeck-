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

    readonly property var cfg: { store.geomRev; store.mons; return store.cfgFor(wid, monKey) || ({ id: wid, type: "blank", x: 0, y: 0, w: 10, h: 10, style: {}, props: {} }); }
    readonly property real pad: 56

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
