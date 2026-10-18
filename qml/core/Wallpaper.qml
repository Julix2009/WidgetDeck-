// Finds the current wallpaper file: manual path (settings) -> awww / swww -> hyprpaper -> swaybg -> wpaperd (core/wallpaper.sh).
// Liquid Glass needs the file (it refracts the picture), so `usable` tells the shell whether Liquid may be used at all.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property string override: ""          // "wallpaperPath" from widgets.json
    property bool wanted: true            // poll only while something needs it
    property string detected: ""
    property string tool: ""              // which tool the detection found it in (empty = manual / none)
    property bool overrideExists: false
    readonly property string path: override !== "" ? expand(override) : detected
    readonly property url url: fileUrl(path)
    // a picture exists: nothing found / a manual path that does not exist means "no wallpaper" -> Liquid falls back to Frosted
    readonly property bool usable: override !== "" ? overrideExists : detected !== ""
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("wallpaper.sh").toString().replace("file://", ""))

    function expand(p) { return p.indexOf("~/") === 0 ? Quickshell.env("HOME") + p.substring(1) : p; }
    function fileUrl(p) {
        if (!p) return "";
        if (p.indexOf("file://") === 0) return p;
        return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }
    function refresh() { if (!proc.running) proc.running = true; if (override !== "" && !chk.running) chk.running = true; }
    Component.onCompleted: if (wanted) refresh()
    onWantedChanged: if (wanted) refresh()
    onOverrideChanged: { overrideExists = false; if (wanted) refresh(); }
    onPathChanged: console.log("[widgetdeck-wallpaper]", path === "" ? "(none found)" : (tool !== "" && override === "" ? tool + ": " : "") + path)

    Process {
        id: proc
        command: ["bash", root.script, "--verbose"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim(), i = t.indexOf("\t");
                root.tool = i > 0 ? t.substring(0, i) : "";
                root.detected = i > 0 ? t.substring(i + 1) : "";
            }
        }
    }
    Process {
        id: chk
        command: ["test", "-f", root.path]
        onExited: (code, status) => root.overrideExists = code === 0
    }
    Timer { interval: 5000; repeat: true; running: root.wanted && root.override === ""; onTriggered: root.refresh() }
}
