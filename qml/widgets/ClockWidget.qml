import QtQuick
import "../core"

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property date now: new Date()
    property var appConfig: ({})          // config.json (WidgetHost): time_format auto|24h|12h
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
            case "j": return String(Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 86400000));
            default: return "%";
            }
        });
    }
    function hAlign(a) { return a === "center" ? Text.AlignHCenter : (a === "end" ? Text.AlignRight : Text.AlignLeft); }

    Timer { interval: 500; running: true; repeat: true; onTriggered: w.now = new Date() }

    Column {
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
