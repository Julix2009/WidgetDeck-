// Compiles glass.frag with qsb and exposes the result.
//   state: idle -> building -> ready | failed        ("failed" = panels fall back to the frosted look)
// The .qsb lands in ~/.cache/widgetdeck/; if qsb is missing or fails, the prebuilt glass.frag.qsb shipped
// next to the source is used instead.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property string state: "idle"
    readonly property string src: decodeURIComponent(Qt.resolvedUrl("glass.frag").toString().replace("file://", ""))
    property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/widgetdeck"
    readonly property string out: cacheDir + "/glass.frag.qsb"
    readonly property url shaderUrl: "file://" + out
    readonly property bool ready: state === "ready"
    // second, tiny shader: weather drops (drops.frag). Optional - without it only the drops are missing.
    readonly property string dropsSrc: decodeURIComponent(Qt.resolvedUrl("drops.frag").toString().replace("file://", ""))
    readonly property string dropsOut: cacheDir + "/drops.frag.qsb"
    readonly property url dropsUrl: "file://" + dropsOut
    property bool dropsReady: false

    function start() {
        if (state === "ready" || state === "building") return;
        if (Quickshell.env("GLASS_FORCE_FAIL") === "1") { state = "failed"; return; }       // test hook: pretend the shader cannot be built
        state = "building";
        proc.running = true;
        dropsProc.running = true;
    }
    property bool autoStart: true               // hosts that only need the shader on demand (dotfiles) switch this off
    Component.onCompleted: if (autoStart) start()
    onStateChanged: console.log("[widgetdeck-glass] state:", state)

    Process {
        id: proc
        command: ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\"; "
            + "for q in qsb qsb6 qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb /usr/lib/qt/bin/qsb; do "
            + "  if command -v \"$q\" >/dev/null 2>&1; then \"$q\" --qt6 -o \"$2\" \"$1\" && exit 0; fi; "
            + "done; "
            + "[ -f \"$1.qsb\" ] && cp \"$1.qsb\" \"$2\" && exit 0; "
            + "exit 1",
            "sh", root.src, root.out]
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[widgetdeck-glass] qsb:", text.trim()) }
        onExited: (code, status) => root.state = (code === 0 ? "ready" : "failed")
    }

    Process {
        id: dropsProc
        command: ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\"; "
            + "for q in qsb qsb6 qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb /usr/lib/qt/bin/qsb; do "
            + "  if command -v \"$q\" >/dev/null 2>&1; then \"$q\" --qt6 -o \"$2\" \"$1\" && exit 0; fi; "
            + "done; "
            + "[ -f \"$1.qsb\" ] && cp \"$1.qsb\" \"$2\" && exit 0; "
            + "exit 1",
            "sh", root.dropsSrc, root.dropsOut]
        onExited: (code, status) => root.dropsReady = (code === 0)
    }
}
