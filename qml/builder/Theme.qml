// Look of the builder UI: opaque, floating cards on a fixed neutral background (a near-black grey without any colour cast,
// a light grey set in light mode). Only the accent follows the theme (ThemeStore), so a new wallpaper or
// shell colour changes the highlights, never the surfaces. The builder itself uses no glass.
import QtQuick
import "../core"

QtObject {
    id: th
    required property var themeStore
    readonly property var pal: themeStore.pal
    readonly property color accent: pal.primary
    readonly property color onAccent: pal.on_primary
    readonly property bool dark: themeStore.dark
    readonly property color fg: dark ? "#ededed" : "#181818"
    readonly property color dim: dark ? "#a6a6a6" : "#5a5a5a"
    readonly property color bg: dark ? "#121212" : "#f2f2f2"
    readonly property color card: dark ? "#1a1a1a" : "#ffffff"
    readonly property color well: dark ? "#0d0d0d" : "#e9e9e9"
    readonly property color selected: dark ? "#2d2d2d" : "#e1e1e1"
    readonly property color field: dark ? Qt.rgba(1, 1, 1, 0.065) : Qt.rgba(0, 0, 0, 0.055)
    readonly property color fieldHover: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.11)
    readonly property color line: dark ? "#2e2e2e" : "#d6d6d6"
    readonly property color popup: dark ? "#202020" : "#ffffff"
    readonly property color danger: pal.error
    readonly property real ctlRadius: 11
    readonly property real cardRadius: 18
    readonly property string font: Fonts.ui
    readonly property int spring: 420
    // popups live in the builder root so panels cannot clip them
    property var pickColor: function (item, hex, cb) { }
    property var pickList: function (item, items, current, cb) { }
}
