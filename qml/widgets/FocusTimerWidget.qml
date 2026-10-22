// Focus timer (Pomodoro): a ring with the time that is left, the phase, today's sessions and the controls. The timer itself lives in
// focustimer/FocusTimerService.qml (ONE for all instances and monitors, independent of this window); this item only shows it. Logic: focustimer/Model.js.
// Look: the shared glass panel only - this item draws NO fill, NO tint on the glass: ring (content, drawn once per second at most), text, glass pills.
// The phases differ by text, icon and Matugen colour (primary / secondary / tertiary), never by a fill. Small: ring + time + phase, the controls appear
// on hover, a click on the ring starts / pauses. Large: header, ring, session dots, today's focus time, Start / Pause - Skip - Reset.
import QtQuick
import QtQuick.Window
import "../core"
import "focustimer"
import "focustimer/Model.js" as M
import "music"

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})

    readonly property var svc: FocusTimerService
    readonly property real fs: style.font_size || 16
    function s(v) { return v * fs / 16; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: palette.primary || style.accent || "#8ab4ff"
    readonly property bool liquid: style.mode === "liquid"
    readonly property bool live: Window.window !== null && Window.window.visible
    // 0 = small layout, 1 = large layout, continuous while the size animates (everything below interpolates: no layout jumps, no scale transform)
    readonly property real u: Math.max(0, Math.min(1, (height - s(176)) / s(150)))
    readonly property real f: Math.max(0, Math.min(1, (u - 0.5) / 0.5))          // the large extras (dots, today, buttons)
    function lerp(a, b) { return a + (b - a) * u; }

    // ---- the time: the service holds the end time; here only a one-second tick while this window is visible AND a phase runs
    property real now: Date.now()
    Timer { interval: 1000; repeat: true; running: w.live && w.svc.running; onTriggered: { w.now = Date.now(); w.svc.check(); } }
    Connections { target: w.svc; function onRevChanged() { w.now = Date.now(); } }
    onLiveChanged: if (live) now = Date.now()
    readonly property real rem: svc.running ? Math.max(0, svc.endsAt - now) : Math.max(0, svc.remainingMs)
    readonly property real full: M.durationMs(svc.settings, svc.phase)
    readonly property real frac: full > 0 ? Math.max(0, Math.min(1, rem / full)) : 0
    readonly property string phase: svc.phase
    readonly property color phaseTarget: phase === "short" ? (palette.tertiary || Qt.lighter(cAcc, 1.25)) : phase === "long" ? (palette.secondary || Qt.darker(cAcc, 1.25)) : cAcc
    property color phaseColor: phaseTarget
    Behavior on phaseColor { ColorAnimation { duration: 320 } }
    readonly property string phaseName: phase === "short" ? I18n.tr("Short break") : phase === "long" ? I18n.tr("Long break") : I18n.tr("Focus")
    readonly property string phaseIcon: phase === "short" ? "leaf" : phase === "long" ? "moon" : "hourglass"
    readonly property bool hot: hov.hovered

    HoverHandler { id: hov }

    // ---- geometry
    readonly property real cw: width
    readonly property real ch: height
    readonly property real headH: s(24) * f
    readonly property real btnH: s(34)
    readonly property real dia: lerp(Math.min(cw, ch), Math.max(s(90), Math.min(cw, ch - s(128))))
    readonly property real ringY: lerp((ch - dia) / 2, s(28))

    // ---- header (large): phase icon and name
    Row {
        x: 0; y: 0; height: w.s(22); spacing: w.s(7); opacity: w.f; visible: opacity > 0.02
        Icon { anchors.verticalCenter: parent.verticalCenter; width: w.s(17); height: width; name: w.phaseIcon; color: w.phaseColor; stroke: 2 }
        GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.letterSpacing: 1.4; font.pixelSize: w.fs * 0.68; opacity: 0.9; text: w.phaseName.toUpperCase() }
    }
    GText {
        visible: opacity > 0.02; opacity: w.f * 0.8
        anchors { right: parent.right } y: 0; height: w.s(22); verticalAlignment: Text.AlignVCenter
        wstyle: w.style; font.pixelSize: w.fs * 0.68; font.bold: true; font.letterSpacing: 1.2
        text: !svc.running && (w.rem < w.full || svc.cycle > 0) ? I18n.tr("Paused").toUpperCase() : ""
    }

    // ---- the ring with the time in it (a click starts / pauses)
    Item {
        id: ringBox
        x: (w.cw - w.dia) / 2; y: w.ringY; width: w.dia; height: w.dia
        Ring {
            anchors.fill: parent
            value: w.frac
            barColor: w.phaseColor
            trackColor: Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.14)
            thickness: w.dia * 0.075
            opacity: svc.running || w.frac >= 0.999 ? 1 : 0.8
        }
        GText {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - height / 2 - w.s(9) * w.hotMix
            wstyle: w.style; font.weight: Font.Light; font.pixelSize: w.dia * 0.25; font.features: { "tnum": 1 }
            opacity: svc.running ? 1 : 0.7
            text: M.clock(w.rem)
        }
        // small layout: the phase name under the time; on hover it gives way to the controls
        GText {
            x: (parent.width - width) / 2
            y: parent.height / 2 + timeText.height * 0.34
            visible: opacity > 0.02; opacity: (1 - w.f) * (1 - w.hotMix) * 0.9
            width: w.dia * 0.62; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            wstyle: w.style; font.bold: true; font.letterSpacing: 1.2; font.pixelSize: w.fs * 0.66
            color: w.phaseColor
            text: w.phaseName.toUpperCase()
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: w.svc.toggle()
        }
    }
    property real hotMix: hot ? (1 - f) : 0                 // 0..1, eases in / out on hover (160 ms), only small layout
    Behavior on hotMix { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    // small layout, on hover: the controls inside the ring, below the time
    Row {
        id: hoverRow
        x: (w.cw - width) / 2; y: w.ringY + w.dia / 2 + w.dia * 0.045
        spacing: w.s(7); opacity: w.hotMix; visible: opacity > 0.02
        MButton { width: w.s(28); height: w.s(28); animate: false; hoverColor: w.phaseColor; strong: true; onClicked: w.svc.toggle()
            Glyph { anchors.centerIn: parent; width: w.s(12); height: width; kind: w.svc.running ? "pause" : "play"; color: w.cFg } }
        MButton { width: w.s(28); height: w.s(28); animate: false; hoverColor: w.phaseColor; onClicked: w.svc.skip()
            Glyph { anchors.centerIn: parent; width: w.s(13); height: width; kind: "next"; color: w.cFg } }
        MButton { width: w.s(28); height: w.s(28); animate: false; hoverColor: w.phaseColor; onClicked: w.svc.reset()
            Icon { anchors.centerIn: parent; width: w.s(15); height: width; name: "refresh"; color: w.cFg; stroke: 2 } }
    }

    // ---- large layout: session dots, today, the controls (anchored to the bottom, so they do not move while the ring grows)
    Row {
        id: dots
        x: (w.cw - width) / 2; y: stats.y - w.s(10) - height; height: w.s(12); spacing: w.s(9)
        opacity: w.f; visible: opacity > 0.02
        Repeater {
            model: svc.settings.cycles
            delegate: Rectangle {
                required property int index
                readonly property bool done: index < svc.cycle || (svc.phase === "long" && svc.cycle >= svc.settings.cycles)
                readonly property bool current: !done && svc.phase === "focus" && index === svc.cycle
                width: w.s(12); height: width; radius: width / 2
                color: done ? w.phaseColor : "transparent"
                border.width: done ? 0 : (current ? 2 : 1.5)
                border.color: current ? w.phaseColor : Qt.rgba(w.cFg.r, w.cFg.g, w.cFg.b, 0.4)
                Behavior on color { ColorAnimation { duration: 240 } }
            }
        }
    }
    GText {
        id: stats
        x: 0; width: parent.width; y: pills.y - w.s(12) - height
        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        opacity: w.f * 0.85; visible: opacity > 0.02
        wstyle: w.style; font.pixelSize: w.fs * 0.8
        readonly property int n: svc.today.sessions
        text: I18n.tr("Today") + ": " + (n === 1 ? I18n.tr("1 session") : I18n.trf("%1 sessions", n)) + " · " + I18n.trf("%1 min focus", svc.today.minutes)
    }
    // the label widths decide whether the pills carry text (English fits) or only icons (long translations): measured, never clipped
    GText { id: mStart; visible: false; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.85; text: I18n.tr("Start") }
    GText { id: mPause; visible: false; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.85; text: I18n.tr("Pause") }
    GText { id: mSkip; visible: false; wstyle: w.style; font.pixelSize: w.fs * 0.82; text: I18n.tr("Skip") }
    GText { id: mReset; visible: false; wstyle: w.style; font.pixelSize: w.fs * 0.82; text: I18n.tr("Reset") }
    readonly property real pillPad: s(26)
    readonly property real wToggle: Math.max(mStart.implicitWidth, mPause.implicitWidth) + s(13) + s(7) + pillPad
    readonly property real wSkipT: mSkip.implicitWidth + s(12) + s(6) + pillPad
    readonly property real wResetT: mReset.implicitWidth + s(14) + s(6) + pillPad
    readonly property bool compact: wToggle + wSkipT + wResetT + 2 * s(8) > cw
    Row {
        id: pills
        x: (w.cw - width) / 2; y: w.ch - w.btnH; height: w.btnH; spacing: w.s(8)
        opacity: w.f; visible: opacity > 0.02
        MButton { id: bToggle; height: w.btnH; width: w.wToggle; animate: false; hoverColor: w.phaseColor; strong: true; onClicked: w.svc.toggle()
            Row { anchors.centerIn: parent; spacing: w.s(7)
                Glyph { anchors.verticalCenter: parent.verticalCenter; width: w.s(13); height: width; kind: w.svc.running ? "pause" : "play"; color: w.cFg }
                GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.pixelSize: w.fs * 0.85; text: w.svc.running ? I18n.tr("Pause") : I18n.tr("Start") } } }
        MButton { height: w.btnH; width: w.compact ? w.btnH : w.wSkipT; animate: false; hoverColor: w.phaseColor; onClicked: w.svc.skip()
            Row { anchors.centerIn: parent; spacing: w.s(6)
                Glyph { anchors.verticalCenter: parent.verticalCenter; width: w.s(12); height: width; kind: "next"; color: w.cFg }
                GText { visible: !w.compact; anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.pixelSize: w.fs * 0.82; text: I18n.tr("Skip") } } }
        MButton { height: w.btnH; width: w.compact ? w.btnH : w.wResetT; animate: false; hoverColor: w.phaseColor; onClicked: w.svc.reset()
            Row { anchors.centerIn: parent; spacing: w.s(6)
                Icon { anchors.verticalCenter: parent.verticalCenter; width: w.s(14); height: width; name: "refresh"; color: w.cFg; stroke: 2 }
                GText { visible: !w.compact; anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.pixelSize: w.fs * 0.82; text: I18n.tr("Reset") } } }
    }
}
