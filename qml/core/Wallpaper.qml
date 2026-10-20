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
    property var outputs: ({})            // output name -> picture, when the tool tells per monitor (awww / swww / hyprpaper / swaybg / wpaperd)
    property var tools: ({})              // output name -> tool
    property var extra: ({})              // manual pictures per monitor (key -> path), set by the shell from widgets.json
    property var extraOk: ({})            // key -> the file exists
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
    // the picture of one monitor: its own manual path, else the tool's answer for that output, else the generic one (same picture everywhere)
    function pathFor(key, name) {
        var m = extra[key];
        if (m) return expand(m);
        if (outputs[name]) return outputs[name];
        return path;
    }
    function usableFor(key, name) {
        var m = extra[key];
        if (m) return extraOk[key] === true;
        return outputs[name] ? true : usable;
    }
    function toolFor(key, name) { return extra[key] ? "" : (tools[name] || tool); }
    onExtraChanged: Qt.callLater(checkExtra)
    function checkExtra() {
        var keys = Object.keys(extra).filter(function (k) { return extra[k]; });
        if (keys.length === 0) { extraOk = ({}); return; }
        var args = ["sh", "-c", "for p in \"$@\"; do [ -f \"$p\" ] && printf '%s\\n' \"$p\"; done; exit 0", "sh"];
        for (var i = 0; i < keys.length; i++) args.push(expand(extra[keys[i]]));
        xchk.command = args; xchk.running = true;
    }
    Process {
        id: xchk
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var have = {}, lines = text.split("\n"), ok = {};
                for (var i = 0; i < lines.length; i++) if (lines[i] !== "") have[lines[i]] = true;
                for (var k in root.extra) if (root.extra[k]) ok[k] = have[root.expand(root.extra[k])] === true;
                root.extraOk = ok;
            }
        }
    }
    function refresh() {
        if (!proc.running) proc.running = true;
        if (override !== "") { chk.running = false; chk.command = ["test", "-f", expand(override)]; chk.running = true; }
    }
    Component.onCompleted: if (wanted) refresh()
    onWantedChanged: if (wanted) refresh()
    onOverrideChanged: { overrideExists = false; if (wanted) Qt.callLater(refresh); }
    onPathChanged: console.log("[widgetdeck-wallpaper]", path === "" ? "(none found)" : (tool !== "" && override === "" ? tool + ": " : "") + path)

    Process {
        id: proc
        command: ["bash", root.script, "--all"]
        stdout: StdioCollector {
            onStreamFinished: {
                // lines "<output>\t<tool>\t<path>"; "*" = the same picture on every output
                var lines = text.split("\n"), out = {}, tl = {}, gen = "", gtool = "", first = "", ftool = "";
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t"); if (p.length < 3) continue;
                    if (p[0] === "*") { if (gen === "") { gen = p[2]; gtool = p[1]; } }
                    else { out[p[0]] = p[2]; tl[p[0]] = p[1]; }
                    if (first === "") { first = p[2]; ftool = p[1]; }
                }
                root.outputs = out; root.tools = tl;
                root.tool = gen !== "" ? gtool : ftool;
                root.detected = gen !== "" ? gen : first;
            }
        }
    }
    Process {
        id: chk
        command: ["true"]
        onExited: (code, status) => root.overrideExists = code === 0
    }
    Timer { interval: 5000; repeat: true; running: root.wanted && root.override === ""; onTriggered: root.refresh() }
}
