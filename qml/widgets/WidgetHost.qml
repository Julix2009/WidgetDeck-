// A widget = glass panel + the widget's QML content. Used by the desktop layer AND by the builder preview.
import QtQuick
import "../core"

GlassPanel {
    id: host
    required property var store
    required property var theme              // ThemeStore (Matugen palette, colour sources)
    required property var cfg                // layout entry {id,type,x,y,w,h,style,props}
    property alias contentItem: ld.item

    // stable per-widget keys: the cfg object is replaced on every geometry change, these strings do not change - so the style / props /
    // peers bindings below are NOT re-evaluated while the widget is dragged
    readonly property string wid: cfg.id
    readonly property string wtype: cfg.type
    readonly property var noPeers: []
    readonly property var tinfo: { store.rev; return store.typeInfo(wtype); }
    // colours: "theme:<role>" follows the Matugen palette (animated), "#rrggbb" stays as chosen
    style: {
        store.rev;
        var s = theme.resolveStyle(store.styleOf(wid));
        var o = ld.item ? ld.item.tintOverride : undefined;     // a widget may tint the glass (music: cover colours)
        if (o !== undefined) { s.tint_color = o; s.bg = o; }
        return s;
    }
    lightPulse: ld.item && ld.item.lightPulse !== undefined ? ld.item.lightPulse : 0
    readonly property var wprops: { store.rev; return theme.resolveProps(tinfo ? tinfo.props : null, store.propsOf(wid)); }
    peers: { store.rev; if (!(style.merge > 0)) return noPeers; store.geomRev; return store.peers(wid); }
    width: cfg.w
    height: cfg.h
    screenX: cfg.x
    screenY: cfg.y

    Loader {
        id: ld
        anchors.fill: parent
        anchors.margins: host.contentPad
        opacity: host.panelReady ? 1 : 0           // content appears together with its glass
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        source: host.tinfo ? (host.tinfo.url ? host.tinfo.url : Qt.resolvedUrl(host.tinfo.file)) : ""
    }
    // widgets that declare `particleKind` ("rain" | "snow" | "") get the drops overlay: above the glass, below their content
    overlay: [
        Loader {
            anchors.fill: parent
            active: ld.item !== null && ld.item.particleKind !== undefined && host.liquid
            sourceComponent: GlassDrops { panel: host; kind: ld.item ? ld.item.particleKind : ""; density: ld.item ? ld.item.particleDensity : 1.0 }
        }
    ]
    Binding { target: ld.item; property: "style"; value: host.style; when: ld.item !== null }
    Binding { target: ld.item; property: "props"; value: host.wprops; when: ld.item !== null }
    Binding { target: ld.item; property: "innerRadius"; value: host.innerRadius; when: ld.item !== null }
    // widgets that depend on config.json (location, units) re-fetch when it changes
    Binding { target: ld.item; property: "configRev"; value: host.store.configRev; when: ld.item !== null && ld.item.configRev !== undefined }
    // plugin widgets: every Material role as hex, so no colour codes are needed (property var palette)
    Binding { target: ld.item; property: "palette"; value: host.theme.palette_(); when: ld.item !== null && ld.item.palette !== undefined }
}
