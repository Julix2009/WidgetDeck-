import QtQuick
import "../core"
import "clock/WorldClock.js" as WC

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property date now: new Date()
    property var appConfig: ({})          // config.json (WidgetHost): time_format auto|24h|12h
    property var palette: ({})
    // ───────────── clock styles ─────────────
    // "digital" is the glass card; every other style is a free shape or free text on the wallpaper (no container, unless "Glass behind it" is on)
    readonly property string face: w.props.clock_style || "digital"
    readonly property bool forcePlain: face !== "digital" && w.props.clock_glass !== true       // WidgetHost: draw no glass
    // free on the wallpaper: the fine dark shadow of Liquid Glass keeps the text readable on any picture
    readonly property var tstyle: forcePlain ? Object.assign({}, style, { mode: "liquid" }) : style
    readonly property var faces: ({ flower: "FlowerClock.qml", poster: "PosterClock.qml", card: "CardClock.qml", stacked: "StackedClock.qml", ring: "DayRingClock.qml", pixel: "PixelClock.qml" })
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

    Timer { interval: 500; running: true; repeat: true; onTriggered: { w.now = new Date(); w.checkWorld(); } }

    // ───────────── world clock (digital style) ─────────────
    // other time zones in one line under the date; the offsets come from the system's tzdata (clock/worldclock.sh)
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("clock/").toString().replace("file://", ""))
    readonly property var worldZones: w.face === "digital" ? WC.parseZones(w.props.world_zones) : []
    property var worldOffsets: ({})
    property real worldAsked: 0
    readonly property string worldText: w.worldZones.length === 0 ? "" : WC.line(w.worldZones, w.worldOffsets, w.now, function (d) { return w.fmt(d, w.use12h ? "%I:%M %p" : "%H:%M"); })
    // after standby the samples may no longer reach "now" (a daylight saving change in between): ask again, at most once a minute
    // (zones without samples yet are left to the feed itself: it runs as soon as it is acquired)
    function checkWorld() {
        if (w.worldZones.length === 0 || Date.now() - w.worldAsked < 60000) return;
        var ms = w.now.getTime();
        for (var i = 0; i < w.worldZones.length; i++) {
            var s = w.worldOffsets[w.worldZones[i].zone];
            if (s && WC.stale(s, ms)) { w.worldAsked = Date.now(); worldFeed.refresh(); return; }
        }
    }
    Feed {
        id: worldFeed
        key: "worldclock:" + w.worldZones.map(function (z) { return z.zone; }).join(",")
        command: ["bash", w.dir + "worldclock.sh"].concat(w.worldZones.map(function (z) { return z.zone; }))
        interval: 900000
        active: w.worldZones.length > 0
        onGot: text => { w.worldOffsets = WC.parseOffsets(text); }
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
        GText {
            width: parent.width
            visible: w.worldText !== ""
            wstyle: w.style
            opacity: 0.8
            topPadding: 4
            text: w.worldText
            font.pixelSize: Math.max(10, Math.round((w.style.font_size || 16) * 0.9))
            wrapMode: Text.Wrap                 // between entries; a single entry wider than the widget breaks anywhere
            maximumLineCount: 2
            elide: Text.ElideRight
            horizontalAlignment: w.hAlign(w.props.align)
        }
    }
}
