// Look of the builder UI. Colours come from the Matugen palette (ThemeStore), so the builder follows the wallpaper
// with the same smooth fade as the widgets. The glass mode comes from builder.json ("glass": frosted | liquid).
import QtQuick
import "../core"

QtObject {
    id: th
    required property var themeStore
    property bool liquid: false
    readonly property var pal: themeStore.pal
    readonly property color accent: pal.primary
    readonly property color onAccent: pal.on_primary
    readonly property color fg: pal.on_surface
    readonly property color dim: Qt.rgba(pal.on_surface_variant.r, pal.on_surface_variant.g, pal.on_surface_variant.b, 0.92)
    readonly property color field: Qt.rgba(pal.on_surface.r, pal.on_surface.g, pal.on_surface.b, 0.075)
    readonly property color fieldHover: Qt.rgba(pal.on_surface.r, pal.on_surface.g, pal.on_surface.b, 0.14)
    readonly property color line: Qt.rgba(pal.outline.r, pal.outline.g, pal.outline.b, 0.50)
    readonly property color popup: Qt.rgba(pal.surface.r, pal.surface.g, pal.surface.b, 0.97)
    readonly property color danger: pal.error
    readonly property real ctlRadius: liquid ? 99 : 10
    readonly property string font: Fonts.ui
    readonly property int spring: 420
    // popups live in the builder root so panels cannot clip them
    property var pickColor: function (item, hex, cb) { }
    property var pickList: function (item, items, current, cb) { }
}
