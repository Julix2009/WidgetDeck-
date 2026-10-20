import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import "../core"
import "../core/Defaults.js" as D

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var levels: []                 // 0..1 per bar
    readonly property int n: Math.max(2, Math.round(props.bars))

    function mix(c1, c2, t) {
        var a = D.hexRgb(c1), b = D.hexRgb(c2);
        return Qt.rgba(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, 1);
    }
    function colorAt(i) { return props.gradient ? mix(style.accent, props.color2, i / Math.max(1, n - 1)) : style.accent; }

    // cava prints one line per frame: "12;40;7;..." (0..1000)
    readonly property string conf: "[general]\nbars = " + n + "\nframerate = 45\n[input]\nmethod = pipewire\nsource = " + (props.source || "auto")
        + "\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\n[smoothing]\nnoise_reduction = 70\n"
    Feed {                                                  // one cava for every visualizer with the same settings
        id: cava
        key: "cava:" + w.conf
        command: ["sh", "-c", "f=$(mktemp /tmp/widgetdeck-cava.XXXXXX); printf '%s' \"$1\" > \"$f\"; trap 'rm -f \"$f\"' EXIT; cava -p \"$f\"", "sh", w.conf]
        interval: 0
        active: true
        onGot: line => {
            var a = line.split(";"), out = [], changed = false;
            for (var i = 0; i < a.length; i++) { if (a[i] === "") continue; out.push(parseInt(a[i]) / 1000); }
            var old = w.levels;
            if (out.length === old.length) { for (var j = 0; j < out.length; j++) if (out[j] !== old[j]) { changed = true; break; } }
            else changed = true;
            if (changed) w.levels = out;       // silence = identical frames: nothing to redraw
        }
    }

    readonly property real slot: width / n
    readonly property real barW: slot * (1 - props.gap)

    // bars / mirrored bars
    Item {
        anchors.fill: parent
        visible: w.props.mode !== "line"
        Repeater {
            model: w.n
            delegate: Rectangle {
                required property int index
                readonly property real v: Math.max(0, Math.min(1, w.levels[index] || 0))
                readonly property real bh: Math.max(w.barW, v * w.height)
                x: index * w.slot + (w.slot - w.barW) / 2
                width: w.barW; height: bh; radius: w.barW / 2
                y: w.props.mode === "mirror" ? (w.height - bh) / 2 : w.height - bh
                color: w.colorAt(index)
            }
        }
    }
    // line
    Shape {
        anchors.fill: parent
        visible: w.props.mode === "line"
        layer.enabled: visible
        layer.samples: 4
        ShapePath {
            strokeColor: w.style.accent
            strokeWidth: Math.max(2, w.style.font_size * 0.2)
            fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathPolyline {
                path: {
                    var pts = [], step = w.width / Math.max(1, w.n - 1);
                    for (var i = 0; i < w.n; i++) pts.push(Qt.point(i * step, w.height - Math.max(0.02, w.levels[i] || 0) * (w.height - 4) - 2));
                    return pts;
                }
            }
        }
    }
}
