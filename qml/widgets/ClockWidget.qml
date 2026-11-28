import QtQuick
import "../core"
import "../core/Defaults.js" as D

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property date now: new Date()
    property var appConfig: ({})          // config.json (WidgetHost): time_format auto|24h|12h
    property var palette: ({})
    // ───────────── clock styles ─────────────
    // the card styles (Defaults.CARD_CLOCKS) sit on glass; every other style is a free shape or free text on the wallpaper (no container, unless "Glass behind it" is on)
    readonly property string face: w.props.clock_style || "digital"
    readonly property bool forcePlain: !D.isCardClock(face) && w.props.clock_glass !== true       // WidgetHost: draw no glass
    // free on the wallpaper: the fine dark shadow of Liquid Glass keeps the text readable on any picture
    readonly property var tstyle: forcePlain ? Object.assign({}, style, { mode: "liquid" }) : style
    readonly property var faces: ({ flower: "FlowerClock.qml", poster: "PosterClock.qml", card: "CardClock.qml", stacked: "StackedClock.qml", ring: "DayRingClock.qml", pixel: "PixelClock.qml",
        split: "SplitClock.qml", chip: "ChipClock.qml", hands: "HandsClock.qml", minimal: "MinimalClock.qml", material: "MaterialClock.qml", material_hands: "MaterialHandsClock.qml" })
    // empty format in the widget props = follow the global setting (24 h / 12 h / the system locale)
    readonly property bool use12h: {
        var t = appConfig && appConfig.time_format ? appConfig.time_format : "auto";
        if (t === "12h") return true;
        if (t === "24h") return false;
        return /[aA]/.test(Qt.locale().timeFormat(Locale.ShortFormat).replace(/'[^']*'/g, ""));
    }
    readonly property string timeFmt: w.props.time_format ? w.props.time_format : (use12h ? "%I:%M %p" : "%H:%M")
    function dateText(d) { return w.props.date_format ? fmt(d, w.props.date_format) : Qt.locale().toString(d, Qt.locale().dateFormat(Locale.LongFormat)); }

    // strftime subset: %H %M %S %I %p %d %e %m %y %Y %A %a %B %b %j %%
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function fmt(d, f) {
        var L = Qt.locale();
        return String(f).replace(/%([HMSIpdemyYAaBbj%])/g, function (m, c) {
            switch (c) {
            case "H": return pad(d.getHours());
            case "M": return pad(d.getMinutes());
            case "S": return pad(d.getSeconds());
            case "I": return pad(d.getHours() % 12 === 0 ? 12 : d.getHours() % 12);
            case "p": return d.getHours() < 12 ? "AM" : "PM";
            case "d": return pad(d.getDate());
            case "e": return String(d.getDate());
            case "m": return pad(d.getMonth() + 1);
            case "y": return pad(d.getFullYear() % 100);
            case "Y": return String(d.getFullYear());
            case "A": return L.dayName(d.getDay(), Locale.LongFormat);
            case "a": return L.dayName(d.getDay(), Locale.ShortFormat);
            case "B": return L.monthName(d.getMonth(), Locale.LongFormat);
            case "b": return L.monthName(d.getMonth(), Locale.ShortFormat);
            case "j": return String(Math.round((Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) - Date.UTC(d.getFullYear(), 0, 0)) / 86400000));
            default: return "%";
            }
        });
    }
    function hAlign(a) { return a === "center" ? Text.AlignHCenter : (a === "end" ? Text.AlignRight : Text.AlignLeft); }

    // redraw only when something shown can change: every second with seconds, else when the minute turns. The timer itself stays short, so the
    // time is right again at once after standby (a timer does not run while the computer sleeps)
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property bool needsSeconds: (timeFmt + (props.date_format || "")).indexOf("%S") >= 0
        || (face === "flower" && (props.show_seconds !== false || props.spin === true)) || (["pixel", "chip", "hands", "minimal", "material_hands"].indexOf(face) >= 0 && props.show_seconds !== false)
    Timer {
        interval: w.needsSeconds ? 500 : 1000; running: w.live; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            if (w.needsSeconds || Math.floor(d.getTime() / 60000) !== Math.floor(w.now.getTime() / 60000)) w.now = d;
        }
    }

    Loader {
        id: faceLoader
        anchors.fill: parent
        function load() {
            var file = w.faces[w.face];
            if (file === undefined) source = "";
            else setSource("clock/" + file, { w: w });
        }
        Component.onCompleted: load()
        Connections { target: w; function onFaceChanged() { faceLoader.load(); } }
    }
    Column {
        visible: w.face === "digital" || w.faces[w.face] === undefined
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        GText {
            width: parent.width
            wstyle: w.style
            text: w.timeFmt === "" ? "" : w.fmt(w.now, w.timeFmt)
            font.pixelSize: w.style.font_size * w.props.time_scale
            font.bold: true
            horizontalAlignment: w.hAlign(w.props.align)
        }
        GText {
            width: parent.width
            visible: w.props.show_date
            wstyle: w.style
            opacity: 0.65
            text: w.dateText(w.now)
            horizontalAlignment: w.hAlign(w.props.align)
        }
    }
}
