// Weather card: current weather with a 3D icon, the next hours and the next days. Shares its data with the weather widget: the same script
// (sysmon/weather.sh: one Open-Meteo request per 10 minutes, cached on disk), the same location and units (config.json) - nothing is requested twice.
// Look: the glass behind is the shared GlassPanel only; this item draws NO fill / tint / shapes on the glass. Only in milk-glass mode there is an
// optional faint sky gradient (switch "Sky gradient"). The icons are baked sprite layers (weathercard/icons, made by tools/weather-icons/render.sh).
// Logic without UI: weathercard/Model.js (tested by tools/weathercard-test.js).
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../core"
import "weathercard"
import "weathercard/Model.js" as M

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})
    property int configRev: 0
    property var appConfig: ({})

    readonly property real fs: style.font_size || 16
    function s(v) { return v * fs / 16; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: style.accent || "#8ab4ff"
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("sysmon/").toString().replace("file://", ""))
    // 0 = small layout, 1 = large layout, continuous while the size animates (everything below interpolates: no layout jumps)
    readonly property real u: Math.max(0, Math.min(1, (width - s(344)) / s(140)))      // content width: small card 344, large 484 (sizes minus the glass padding)
    function lerp(a, b) { return a + (b - a) * u; }
    readonly property bool liquid: style.mode === "liquid"
    readonly property string family: Fonts.has(props.font) ? props.font : (Fonts.has("Inter") ? "Inter" : Fonts.ui)

    // ---- data (shared script) ---------------------------------------------------------------------------------------------
    property var d: null
    property string err: ""
    Process {
        id: poll
        command: ["bash", w.dir + "weather.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    if (o && o.current_temp !== undefined) { w.d = o; w.err = ""; }
                    else if (o && o.error) w.err = o.error;
                } catch (e) { w.err = "offline"; }
            }
        }
    }
    onConfigRevChanged: if (live && !poll.running) poll.running = true
    Timer { interval: 600000; repeat: true; running: w.live; triggeredOnStart: true; onTriggered: if (!poll.running) poll.running = true }

    // ---- what is shown ---------------------------------------------------------------------------------------------------
    readonly property int hourProp: Math.max(4, Math.min(8, props.hours !== undefined ? Number(props.hours) : 6))
    readonly property int hourCount: hourProp          // entries that exist; entries 5..8 fade with u (small layout shows 4)
    readonly property real hourShown: 4 + (hourProp - 4) * u
    readonly property int dayCount: Math.max(3, Math.min(7, props.days !== undefined ? Number(props.days) : 3))
    readonly property string dbgKind: props.debug_kind && props.debug_kind !== "auto" && M.isKind(props.debug_kind) ? props.debug_kind : ""
    readonly property var real_: M.model(d, hourCount, dayCount)
    // test switch: with a forced weather type the card also works without data (invented demo values), so every icon can be checked offline
    readonly property var m: {
        var r = real_;
        if (dbgKind === "") return r;
        var cycle = M.KINDS, hrs = [], dys = [], i;
        for (i = 0; i < hourCount; i++) hrs.push({ t: ((14 + i) % 24) + ":00", temp: 20 - i, kind: cycle[(M.KINDS.indexOf(dbgKind) + i) % cycle.length], day: true });
        for (i = 0; i < dayCount; i++) dys.push({ date: "2026-10-" + (19 + i), max: 21 - i, min: 12 - i, kind: cycle[(M.KINDS.indexOf(dbgKind) + i * 2) % cycle.length] });
        var base = r || { place: "Demo", unit: "°C", temp: 21, feels: 20, hi: 21, lo: 12, pop: 0, desc: "", hours: hrs, days: dys, stale: false, fetched: 0, day: true };
        return { place: base.place, unit: base.unit, temp: base.temp, feels: base.feels, hi: base.hi, lo: base.lo, pop: base.pop, desc: "", hours: hrs, days: dys, stale: base.stale, fetched: base.fetched, kind: dbgKind, day: base.day };
    }
    readonly property bool has: m !== null
    readonly property string kind: has ? (dbgKind !== "" ? dbgKind : m.kind) : "unknown"
    readonly property bool isDay: props.debug_time === "day" ? true : (props.debug_time === "night" ? false : (has ? m.day : true))
    readonly property string descText: {
        if (!has) return "";
        if (kind === "clear" && isDay) return I18n.tr("Sunny");
        if (kind === "mostly_clear" && isDay) return I18n.tr("Mostly sunny");
        if (m.desc !== "") return m.desc;
        var names = { clear: I18n.tr("Clear"), mostly_clear: I18n.tr("Mostly clear"), partly: I18n.tr("Partly cloudy"), cloudy: I18n.tr("Cloudy"), fog: I18n.tr("Fog"), drizzle: I18n.tr("Drizzle"),
                      rain: I18n.tr("Rain"), heavy_rain: I18n.tr("Heavy rain"), thunder: I18n.tr("Thunderstorm"), snow: I18n.tr("Snow"), sleet: I18n.tr("Sleet"), hail: I18n.tr("Hail"), unknown: I18n.tr("Unknown code") };
        return names[kind] || "";
    }
    readonly property bool twelve: M.use12h(appConfig && appConfig.time_format, Qt.locale().timeFormat(Locale.ShortFormat))
    readonly property string unitSign: "°"
    function dayName(date, i) {
        if (i === 0) return I18n.tr("Today");
        var n = [I18n.tr("Sunday"), I18n.tr("Monday"), I18n.tr("Tuesday"), I18n.tr("Wednesday"), I18n.tr("Thursday"), I18n.tr("Friday"), I18n.tr("Saturday")][M.weekday(date)];
        return n ? n : date;
    }
    readonly property string asOf: has && m.stale && m.fetched > 0 ? Qt.formatTime(new Date(m.fetched * 1000), twelve ? "h:mm AP" : "HH:mm") : ""

    // ---- animation clock: runs only while the card is visible, animations are on and there is something to show --------------
    readonly property int level: props.animations === "off" ? 0 : (props.animations === "full" ? 2 : 1)
    property real clock: 0
    Timer { interval: w.level >= 2 ? 33 : 66; repeat: true; running: w.level > 0 && w.live && w.has; onTriggered: w.clock += interval / 1000 }

    // ---- sky gradient (milk glass only) ---------------------------------------------------------------------------------------
    Rectangle {
        id: sky
        visible: !w.liquid && w.props.sky_gradient !== false && w.has
        readonly property real pad: Math.round(1.1 * w.fs)
        x: -pad; y: -pad; width: parent.width + 2 * pad; height: parent.height + 2 * pad
        radius: w.innerRadius + pad
        readonly property var cols: M.skyColors(w.kind, w.isDay)
        property color cTop: Qt.rgba(Qt.color(cols[0]).r, Qt.color(cols[0]).g, Qt.color(cols[0]).b, 0.40)
        property color cBottom: Qt.rgba(Qt.color(cols[1]).r, Qt.color(cols[1]).g, Qt.color(cols[1]).b, 0.10)
        Behavior on cTop { ColorAnimation { duration: 700 } }
        Behavior on cBottom { ColorAnimation { duration: 700 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: sky.cTop }
            GradientStop { position: 1.0; color: sky.cBottom }
        }
    }

    // ---- header -------------------------------------------------------------------------------------------------------------
    GText {
        id: head
        x: 0; y: 0; wstyle: w.style; font.family: w.family; font.bold: true; font.letterSpacing: 1.4; font.pixelSize: w.fs * 0.68; opacity: 0.8
        text: I18n.tr("Weather").toUpperCase()
    }
    GText {
        visible: w.asOf !== ""
        anchors { right: parent.right; verticalCenter: head.verticalCenter }
        wstyle: w.style; font.family: w.family; font.pixelSize: w.fs * 0.66; opacity: 0.7
        text: I18n.tr("As of") + " " + w.asOf
    }

    // ---- top block: icon, place / description / rain, temperature ----------------------------------------------------
    readonly property real iconSize: lerp(s(64), s(84))
    readonly property real topY: s(22)
    Item {
        id: iconBox
        x: 0; y: w.topY; width: w.iconSize; height: w.iconSize
        visible: w.has
        // two slots: a new weather blends in (opacity + a small move) over the old one - no flash
        property int act: 0
        property string curKey: ""
        function show(k, day) {
            var key = k + "|" + day;
            if (key === curKey) return;
            var first = curKey === "";
            curKey = key;
            var n = first ? 0 : 1 - act, inc = n === 0 ? slot0 : slot1, out = n === 0 ? slot1 : slot0;
            inc.instant = first; inc.kind = k; inc.day = day; inc.yoff = first ? 0 : s(6); inc.shown = true; inc.instant = false;
            inc.yoff = 0;
            if (!first) out.shown = false;
            act = n;
        }
        Connections { target: w; function onKindChanged() { iconBox.show(w.kind, w.isDay); } function onIsDayChanged() { iconBox.show(w.kind, w.isDay); } function onHasChanged() { if (w.has) iconBox.show(w.kind, w.isDay); } }
        Component.onCompleted: if (w.has) show(w.kind, w.isDay)
        component Slot: Item {
            id: sl
            property alias kind: icn.kind
            property alias day: icn.day
            property bool shown: false
            property bool instant: false
            property real yoff: 0
            width: iconBox.width; height: iconBox.height
            opacity: shown ? 1 : 0
            y: yoff
            visible: opacity > 0.01
            Behavior on opacity { enabled: !sl.instant; NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !sl.instant; NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            WeatherIcon { id: icn; anchors.fill: parent; t: w.clock; level: w.level; tilt: iconHover.tx; tiltY: iconHover.ty }
        }
        Slot { id: slot0 }
        Slot { id: slot1 }
        HoverHandler {
            id: iconHover
            enabled: w.level > 0
            property real tx: hovered ? Math.max(-1, Math.min(1, point.position.x / iconBox.width * 2 - 1)) : 0
            property real ty: hovered ? Math.max(-1, Math.min(1, point.position.y / iconBox.height * 2 - 1)) : 0
        }
    }

    Item {
        id: infoCol
        x: w.iconSize + w.s(14); y: w.topY
        width: Math.max(0, tempCol.x - x - w.s(10)); height: w.iconSize
        visible: w.has
        readonly property real placeH: w.fs * 1.4
        readonly property real descH: w.fs * 1.25
        readonly property real popH: w.fs * 1.05
        readonly property real blockH: placeH + w.u * (descH + popH + w.s(4))
        readonly property real y0: (height - blockH) / 2
        GText { y: infoCol.y0; width: parent.width; elide: Text.ElideRight; wstyle: w.style; font.family: w.family; font.bold: true; font.pixelSize: w.fs * w.lerp(1.0, 1.08); text: w.has ? (w.m.place !== "" ? w.m.place : w.descText) : "" }      // no place known: the description takes its line
        GText { y: infoCol.y0 + infoCol.placeH + w.s(2); width: parent.width; elide: Text.ElideRight; opacity: 0.82 * w.u; visible: w.u > 0.02 && w.has && w.m.place !== ""; wstyle: w.style; font.family: w.family; font.pixelSize: w.fs * 0.92; text: w.descText }
        GText { y: infoCol.y0 + infoCol.placeH + infoCol.descH + w.s(3); width: parent.width; elide: Text.ElideRight; opacity: 0.76 * w.u; visible: w.u > 0.02 && w.has && w.m.pop !== null; wstyle: w.style; font.family: w.family; font.pixelSize: w.fs * 0.78
                text: w.has && w.m.pop !== null ? I18n.trf("Chance of rain: %1 %", w.m.pop) : "" }
    }
    Column {
        id: tempCol
        anchors { right: parent.right }
        y: w.topY + (w.iconSize - height) / 2
        visible: w.has && w.m.temp !== null
        spacing: w.s(1)
        Row {
            anchors.right: parent.right
            spacing: -w.fs * 0.12
            GText { id: bigTemp; wstyle: w.style; font.family: w.family; font.weight: Font.Light; font.pixelSize: w.fs * w.lerp(2.7, 3.4); text: w.has && w.m.temp !== null ? String(w.m.temp) : "" }
            GText { anchors.top: parent.top; anchors.topMargin: w.fs * w.lerp(0.2, 0.3); wstyle: w.style; font.family: w.family; font.weight: Font.Light; font.pixelSize: w.fs * w.lerp(1.2, 1.5); text: w.unitSign }
        }
        Row {
            anchors.right: parent.right
            spacing: w.s(5)
            visible: w.has && w.m.hi !== null && w.m.lo !== null
            GText { wstyle: w.style; font.family: w.family; font.pixelSize: w.fs * 0.86; text: w.has && w.m.hi !== null ? w.m.hi + "°" : "" }
            GText { wstyle: w.style; font.family: w.family; font.pixelSize: w.fs * 0.86; opacity: 0.65; text: "/" }
            GText { wstyle: w.style; font.family: w.family; font.pixelSize: w.fs * 0.86; opacity: 0.76; text: w.has && w.m.lo !== null ? w.m.lo + "°" : "" }
        }
        GText {
            anchors.right: parent.right
            visible: w.props.show_feels === true && w.has && w.m.feels !== null
            wstyle: w.style; font.family: w.family; opacity: 0.6; font.pixelSize: w.fs * 0.7
            text: w.has && w.m.feels !== null ? I18n.tr("feels like") + " " + w.m.feels + "°" : ""
        }
    }

    // ---- hourly strip -------------------------------------------------------------------------------------------------------
    readonly property real hourY: topY + iconSize + s(12)
    readonly property real hourH: lerp(s(66), s(78))
    Rectangle { visible: w.has && w.m.hours.length > 0; x: 0; y: w.hourY - w.s(6); width: parent.width; height: 1; color: Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.16) }
    Row {
        id: hourRow
        x: 0; y: w.hourY; width: parent.width; height: w.hourH
        clip: true                       // while the size animates, the entries that are fading out never stick out of the card
        visible: w.has && w.m.hours.length > 0
        Repeater {
            model: w.has ? w.m.hours : []
            delegate: Item {
                id: hcell
                required property var modelData
                required property int index
                width: hourRow.width / Math.max(1, Math.min(w.hourShown, w.m.hours.length)); height: w.hourH
                opacity: index < 4 ? 1 : w.u
                visible: opacity > 0.02
                readonly property real isz: w.lerp(w.s(30), w.s(36))
                property real frozen: 0
                property real off: 0
                HoverHandler {
                    id: hh
                    enabled: w.level > 0
                    onHoveredChanged: { if (hovered) hcell.off = hcell.frozen - w.clock; else hcell.frozen = w.clock + hcell.off; }
                }
                WeatherIcon {
                    x: (parent.width - isz) / 2; y: 0; width: isz; height: isz
                    kind: modelData.kind; day: modelData.day; shadowOn: true
                    level: hh.hovered ? w.level : 0
                    t: hh.hovered ? w.clock + hcell.off : hcell.frozen
                    tilt: hh.hovered ? Math.max(-1, Math.min(1, hh.point.position.x / hcell.width * 2 - 1)) : 0
                    tiltY: hh.hovered ? Math.max(-1, Math.min(1, hh.point.position.y / isz * 2 - 1)) : 0
                }
                GText { x: 0; width: parent.width; y: isz + w.s(3); horizontalAlignment: Text.AlignHCenter; wstyle: w.style; font.family: w.family; opacity: 0.82; font.pixelSize: w.fs * 0.7
                        text: index === 0 ? I18n.tr("Now") : M.hourLabel(modelData.t, w.twelve) }
                GText { x: 0; width: parent.width; y: isz + w.s(3) + w.fs * 0.95; horizontalAlignment: Text.AlignHCenter; visible: modelData.temp !== null; wstyle: w.style; font.family: w.family; font.weight: Font.DemiBold; font.pixelSize: w.fs * 0.82
                        text: modelData.temp !== null ? modelData.temp + "°" : "" }
            }
        }
    }

    // ---- day list (large size only) -----------------------------------------------------------------------------------------
    readonly property real dayY: hourY + hourH + s(8)
    readonly property real rowH: s(30)
    readonly property int shownDays: u < 0.02 || !has ? 0 : Math.max(0, Math.min(m.days.length, Math.floor((height - dayY) / rowH)))
    readonly property var range_: has ? M.dayRange(m.days) : { lo: null, hi: null }
    Column {
        id: dayCol
        x: 0; y: w.dayY; width: parent.width
        visible: w.shownDays > 0
        opacity: w.u
        Repeater {
            model: w.shownDays > 0 ? w.m.days.slice(0, w.shownDays) : []
            delegate: Item {
                id: drow
                required property var modelData
                required property int index
                width: dayCol.width; height: w.rowH
                Rectangle { x: 0; y: 0; width: parent.width; height: 1; color: Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.16) }
                GText { x: 0; anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.family: w.family; font.pixelSize: w.fs * 0.92; text: w.dayName(modelData.date, index) }
                // thin temperature bar: where this day's range lies within the shown days
                Item {
                    visible: w.props.day_bars !== false && modelData.min !== null && modelData.max !== null && w.range_.hi !== null && w.range_.hi > w.range_.lo
                    x: parent.width * 0.40; width: parent.width * 0.30 - w.s(6); height: w.s(4); anchors.verticalCenter: parent.verticalCenter
                    Rectangle { anchors.fill: parent; radius: height / 2; color: Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.16) }
                    Rectangle {
                        readonly property real span: Math.max(1, w.range_.hi - w.range_.lo)
                        x: parent.width * Math.max(0, (modelData.min - w.range_.lo) / span)
                        width: Math.max(parent.height, parent.width * Math.max(0, (modelData.max - modelData.min) / span))
                        height: parent.height; radius: height / 2; color: w.cAcc
                    }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: w.s(10)
                    GText { wstyle: w.style; font.family: w.family; font.weight: Font.DemiBold; font.pixelSize: w.fs * 0.92; text: modelData.max !== null ? modelData.max + "°" : "" }
                    GText { wstyle: w.style; font.family: w.family; opacity: 0.7; font.pixelSize: w.fs * 0.92; text: modelData.min !== null ? modelData.min + "°" : "" }
                }
            }
        }
    }

    // ---- no data ----------------------------------------------------------------------------------------------------------------
    GText {
        anchors.centerIn: parent; visible: !w.has; wstyle: w.style; font.family: w.family; opacity: 0.65
        horizontalAlignment: Text.AlignHCenter; width: parent.width - w.s(20); wrapMode: Text.WordWrap
        text: w.err === "no-location" ? I18n.tr("No location known.") + "\n" + I18n.tr("Builder → Settings → Location & units") : (poll.running ? I18n.tr("Loading …") : (w.err === "offline" ? I18n.tr("No connection") : I18n.tr("No weather data")))
    }
}
