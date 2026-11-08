// System info in the style of fastfetch: user@host, a small logo, key / value rows (system, hardware, software), memory and disk bars, colour blocks.
// Feed: sysmon/fastfetch.sh (needs `fastfetch`) about once a minute while the widget is on screen; the run time keeps counting locally in between.
import QtQuick
import QtQuick.Window
import Quickshell
import "../core"

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})

    readonly property real fs: style.font_size || 16
    function s(v) { return v * fs / 16; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: style.accent || "#8ab4ff"
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("sysmon/").toString().replace("file://", ""))
    readonly property bool showLogo: w.props.show_logo !== false
    readonly property real poll: Math.max(10, Number(w.props.poll_s || 60))

    property var d: ({ info: {}, logo: "" })
    property bool missing: false
    property bool loaded: false
    property double sampleMs: Date.now()
    property double nowMs: Date.now()
    readonly property var info: d.info || ({})

    Feed {                                                          // shared by all instances with the same settings
        key: "fastfetch:" + w.poll + ":" + (w.showLogo ? "logo" : "plain")
        command: w.showLogo ? ["bash", w.dir + "fastfetch.sh", "logo"] : ["bash", w.dir + "fastfetch.sh"]
        interval: w.poll * 1000
        active: w.live
        onGot: text => {
            try {
                var o = JSON.parse(text);
                w.missing = o.missing === true;
                if (!w.missing) { w.d = o; w.sampleMs = Date.now(); w.nowMs = w.sampleMs; }
                w.loaded = true;
            } catch (e) { }
        }
    }
    Timer { interval: 10000; repeat: true; running: w.live; onTriggered: w.nowMs = Date.now() }     // the run time counts locally

    // ───────────── formatting ─────────────
    function gib(b) { return (b / 1073741824).toFixed(1) + " GiB"; }
    function clean(t) { return String(t || "").replace(/\((R|TM|tm|r)\)/g, "").replace(/\s+/g, " ").trim(); }
    function upText() {
        var u = info.Uptime;
        if (!u) return "";
        var sec = Math.floor(u.uptime / 1000 + Math.max(0, w.nowMs - w.sampleMs) / 1000);
        var dd = Math.floor(sec / 86400), hh = Math.floor(sec % 86400 / 3600), mm = Math.floor(sec % 3600 / 60);
        return (dd > 0 ? dd + " " + (dd === 1 ? I18n.tr("day") : I18n.tr("days")) + " " : "") + (dd > 0 || hh > 0 ? hh + " " + I18n.tr("h") + " " : "") + mm + " " + I18n.tr("min");
    }
    function packText() {
        var p = info.Packages, out = {}, names = [];
        if (!p) return "";
        for (var k in p) {
            if (k === "all" || !(p[k] > 0)) continue;
            var n = k.replace(/(System|User)$/, "");
            if (!(n in out)) { out[n] = 0; names.push(n); }
            out[n] += p[k];
        }
        return names.map(function (n) { return out[n] + " (" + n + ")"; }).join(", ");
    }
    function gpuText() {
        var g = info.GPU;
        if (!g || !g.length) return "";
        return g.slice(0, 2).map(function (x) { return w.clean(x.name); }).join(", ");
    }
    function rootDisk() {
        var dk = info.Disk;
        if (!dk || !dk.length) return null;
        for (var i = 0; i < dk.length; i++) if (dk[i].mountpoint === "/") return dk[i];
        return dk[0];
    }
    // one row: { k: key, v: text, f: bar fraction (-1 = none) }
    readonly property var rows: {
        w.nowMs; w.d;
        var r = [], i = w.info;
        function add(k, v, f) { if (v !== undefined && v !== null && String(v) !== "") r.push({ k: k, v: String(v), f: f === undefined ? -1 : f }); }
        add(I18n.tr("OS"), i.OS ? i.OS.prettyName : "");
        if (w.props.show_hardware !== false) add(I18n.tr("Host"), i.Host ? w.clean(i.Host.name) : "");
        add(I18n.tr("Kernel"), i.Kernel ? i.Kernel.release : "");
        add(I18n.tr("Uptime"), w.upText());
        if (w.props.show_software !== false) {
            add(I18n.tr("Packages"), w.packText());
            add(I18n.tr("Shell"), i.Shell ? (i.Shell.prettyName + " " + (i.Shell.version || "")).trim() : "");
            add(I18n.tr("WM"), i.WM ? (i.WM.prettyName + " " + (i.WM.version || "")).trim() : "");
        }
        if (w.props.show_hardware !== false) {
            add(I18n.tr("CPU"), i.CPU ? w.clean(i.CPU.cpu) + (i.CPU.cores && i.CPU.cores.logical ? " (" + i.CPU.cores.logical + ")" : "") : "");
            add(I18n.tr("GPU"), w.gpuText());
        }
        if (i.Memory && i.Memory.total > 0) add(I18n.tr("Memory"), w.gib(i.Memory.used) + " / " + w.gib(i.Memory.total), i.Memory.used / i.Memory.total);
        var dk = w.rootDisk();
        if (dk && dk.bytes && dk.bytes.total > 0) {
            var used = dk.bytes.total - dk.bytes.free;
            add(I18n.tr("Disk"), w.gib(used) + " / " + w.gib(dk.bytes.total) + (dk.filesystem ? " (" + dk.filesystem + ")" : ""), used / dk.bytes.total);
        }
        return r;
    }
    readonly property string title: info.Title ? info.Title.userName + "@" + info.Title.hostName : ""
    readonly property var swatch: [palette.primary, palette.secondary, palette.tertiary, palette.error, palette.primary_container, palette.surface_container_high, palette.outline]

    // ───────────── layout ─────────────
    Row {
        anchors.fill: parent
        spacing: w.s(18)

        Text {                                                      // small ASCII logo
            id: logo
            visible: w.showLogo && String(w.d.logo || "") !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: w.d.logo || ""
            color: w.cAcc
            font.family: "monospace"; font.pixelSize: w.fs * 0.86; font.bold: true
            lineHeight: 0.95
            renderType: Text.QtRendering
            opacity: 0.95
        }

        Column {
            width: parent.width - (logo.visible ? logo.width + w.s(18) : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: w.s(5)

            GText {
                visible: w.props.show_title !== false && w.title !== ""
                width: parent.width; elide: Text.ElideRight; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 1.1
                color: w.cAcc; text: w.title
            }
            Rectangle {
                visible: w.props.show_title !== false && w.title !== ""
                width: parent.width; height: 1; color: Qt.alpha(w.cFg, 0.14)
            }

            GText {                                                 // fastfetch missing
                visible: w.missing
                width: parent.width; wrapMode: Text.WordWrap; wstyle: w.style; opacity: 0.7; font.pixelSize: w.fs * 0.9
                text: I18n.tr("fastfetch is not installed. Install it with: sudo pacman -S fastfetch")
            }
            GText {
                visible: !w.missing && !w.loaded
                wstyle: w.style; opacity: 0.5; font.pixelSize: w.fs * 0.9; text: I18n.tr("Reading system info ...")
            }

            Repeater {
                model: w.rows
                delegate: Item {
                    required property var modelData
                    width: parent.width; height: Math.max(keyT.implicitHeight, valT.implicitHeight) + (modelData.f >= 0 ? w.s(5) : 0)
                    GText {
                        id: keyT
                        width: w.s(78); elide: Text.ElideRight; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.86
                        color: w.cAcc; text: modelData.k
                    }
                    GText {
                        id: valT
                        x: w.s(84); width: parent.width - w.s(84); elide: Text.ElideRight; wstyle: w.style; font.pixelSize: w.fs * 0.86
                        text: modelData.v
                    }
                    Rectangle {                                     // memory / disk: thin usage bar under the value
                        visible: modelData.f >= 0
                        x: w.s(84); y: parent.height - height; width: parent.width - w.s(84); height: Math.max(2, Math.round(w.s(3))); radius: height / 2
                        color: Qt.alpha(w.cFg, 0.14)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, modelData.f)); height: parent.height; radius: height / 2
                            color: modelData.f > 0.9 ? (w.palette.error || "#ff8a80") : w.cAcc
                        }
                    }
                }
            }

            Row {                                                   // the classic colour blocks
                visible: w.props.show_colors !== false && !w.missing
                spacing: w.s(4)
                topPadding: w.s(3)
                Repeater {
                    model: w.swatch
                    delegate: Rectangle {
                        required property var modelData
                        width: w.s(22); height: w.s(12); radius: w.s(3)
                        color: modelData || "transparent"
                        visible: !!modelData
                    }
                }
            }
        }
    }
}
