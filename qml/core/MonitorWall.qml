// The wallpaper of ONE monitor, with the properties the glass reads from a `wall` (url, usable, path): a drop-in for Wallpaper.qml.
// Glass on monitor A must refract A's picture, never B's, so every monitor's widgets get their own MonitorWall.
import QtQuick

QtObject {
    id: mw
    required property var wall                 // Wallpaper.qml (all monitors)
    property string key: ""                    // stable monitor key
    property string name: ""                   // connector (DP-1), what awww / hyprpaper call it
    readonly property string path: { wall.outputs; wall.extra; wall.detected; wall.override; return wall.override !== "" && !wall.extra[key] ? wall.pathFor("", "__none__") : wall.pathFor(key, name); }
    readonly property bool usable: { wall.outputs; wall.extra; wall.extraOk; wall.detected; wall.overrideExists; return wall.extra[key] ? wall.usableFor(key, name) : (wall.override !== "" ? wall.usable : wall.usableFor(key, name)); }
    readonly property url url: wall.fileUrl(path)
    readonly property string tool: wall.toolFor(key, name)
    readonly property string override: wall.override
}
