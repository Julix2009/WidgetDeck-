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
    required property string wid
    required property var store
    required property var theme
    required property var backend
    required property var wall
    required property var screenObj
    required property size screenSize
    property string ns: "widgetdeck"

    readonly property var cfg: { store.geomRev; return store.cfg(wid) || ({ id: wid, type: "blank", x: 0, y: 0, w: 10, h: 10, style: {}, props: {} }); }
    readonly property real pad: 56

    screen: screenObj
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
        backend: win.backend; wall: win.wall
        screenSize: win.screenSize
        padPx: win.pad
    }
}
