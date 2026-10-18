// Finds the current wallpaper file: override path -> awww / swww -> hyprpaper -> swaybg.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property string override: ""          // "wallpaperPath" from widgets.json
    property bool wanted: true            // poll only while something needs it
    property string detected: ""
    readonly property string path: override !== "" ? override : detected
    readonly property url url: fileUrl(path)

    function fileUrl(p) {
        if (!p) return "";
        if (p.indexOf("~/") === 0) p = Quickshell.env("HOME") + p.substring(1);
        if (p.indexOf("file://") === 0) return p;
        return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }
    function refresh() { if (!proc.running) proc.running = true; }
    Component.onCompleted: if (wanted) refresh()
    onWantedChanged: if (wanted) refresh()
    onPathChanged: console.log("[widgetdeck-wallpaper]", path === "" ? "(none found)" : path)

    Process {
        id: proc
        command: ["sh", "-c",
            "p=$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1)\n"
            + "[ -z \"$p\" ] && p=$(swww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1)\n"
            + "[ -z \"$p\" ] && p=$(hyprctl hyprpaper listactive 2>/dev/null | head -n1 | sed 's/.*= //')\n"
            + "if [ -z \"$p\" ]; then f=\"$HOME/.config/hypr/hyprpaper.conf\"\n"
            + "  [ -f \"$f\" ] && p=$(grep -E '^[[:space:]]*(path|wallpaper)[[:space:]]*=' \"$f\" | head -n1 | sed -E 's/^[^=]*=[[:space:]]*//; s/^[^,\\/]*,//')\n"
            + "fi\n"
            + "[ -z \"$p\" ] && p=$(pgrep -a swaybg 2>/dev/null | sed -n 's/.* -i \\([^ ]*\\).*/\\1/p' | head -n1)\n"
            + "printf '%s' \"$p\" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'"]
        stdout: StdioCollector { onStreamFinished: root.detected = text.trim() }
    }
    Timer { interval: 5000; repeat: true; running: root.wanted && root.override === ""; onTriggered: root.refresh() }
}
