// A live, non-interactive picture of a widget type (library cards, design tiles, presets): the real widget component,
// scaled down to fit. It is not part of the layout.
import QtQuick
import "../core"
import "../widgets"

Item {
    id: pt
    required property var store
    required property var theme               // ThemeStore
    required property var backend
    required property var wall
    required property string type
    property var previewProps: ({})
    property var look: ({ mode: "solid" })    // style keys of the preview
    property var size: null                   // [w, h]; default = the size of the type
    readonly property var ti: { store.rev; return store.typeInfo(type); }
    readonly property var sz: size ? size : (ti ? ti.size : [320, 160])
    readonly property real k: Math.min(1, width / sz[0], height / sz[1])
    clip: true

    // demo data where a widget would otherwise need an account
    readonly property var demo: type === "timetable" ? ({ source: "demo" }) : ({})

    Item {
        x: (pt.width - width * pt.k) / 2
        y: (pt.height - height * pt.k) / 2
        width: pt.sz[0]; height: pt.sz[1]
        scale: pt.k; transformOrigin: Item.TopLeft
        WidgetHost {
            store: pt.store; theme: pt.theme; backend: pt.backend; wall: pt.wall
            cfg: ({ id: "preview-" + pt.type, type: pt.type, x: 0, y: 0, w: pt.sz[0], h: pt.sz[1],
                    style: pt.look, props: Object.assign({}, pt.demo, pt.previewProps), preview: true })
            screenX: 0; screenY: 0
            screenSize: pt.store.screen
            padPx: 0
            interactive: false
        }
    }
}
