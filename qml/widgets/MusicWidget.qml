import QtQuick
import QtQuick.Window
import Quickshell.Io
import Quickshell.Services.Mpris
import "../core"
import "music"

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8

    // handed to the glass panel (WidgetHost): subtle light movement while a song changes, tint from the cover
    property real lightPulse: 0
    readonly property var tintOverride: (props.cover_colors && !turntable && coverColor.valid) ? tintCol.toString() : undefined
    property color tintCol: coverColor.color
    Behavior on tintCol { ColorAnimation { duration: 650; easing.type: Easing.OutCubic } }

    // ───────────── player selection ─────────────
    readonly property var player: {
        var list = Mpris.players.values, want = String(props.player || "").toLowerCase(), best = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i], id = (p.identity + " " + p.dbusName).toLowerCase();
            if (id.indexOf("playerctld") >= 0) continue;
            if (want !== "") { if (id.indexOf(want) >= 0) return p; continue; }
            if (p.playbackState === MprisPlaybackState.Playing) return p;
            if (!best) best = p;
        }
        return best;
    }
    readonly property bool playing: player !== null && player.playbackState === MprisPlaybackState.Playing
    readonly property bool idle: player === null || player.playbackState === MprisPlaybackState.Stopped

    // ───────────── style: "normal" (cover + progress bar) or "turntable" (record + tonearm); both read the state below ─────────────
    readonly property bool turntable: props.skin === "turntable"
    readonly property bool live: Window.window !== null && Window.window.visible          // no animation work while the widget is not on screen
    function prevTrack() { noteSkip(-1); if (player) player.previous(); }
    function nextTrack() { noteSkip(1); if (player) player.next(); }
    function togglePlay() { if (player) player.togglePlaying(); }
    function fmt(sec) { sec = Math.max(0, Math.floor(sec)); var r = sec % 60; return Math.floor(sec / 60) + ":" + (r < 10 ? "0" : "") + r; }
    readonly property bool hasLen: player !== null && player.lengthSupported && player.length > 0
    readonly property string timeText: !player ? "" : ((player.positionSupported ? fmt(player.position) : "") + (hasLen ? " / " + fmt(player.length) : ""))

    // ───────────── animation settings ─────────────
    readonly property bool animOn: props.anim_enabled !== false
    readonly property string animStyle: props.anim_style || "slide"
    readonly property int animDur: props.anim_duration || 440
    readonly property real animZoom: props.anim_zoom !== undefined ? props.anim_zoom : 0.06

    // ───────────── direction of the last skip (widget buttons, playerctl, media keys: seen on the session bus) ─────────────
    property int dirHint: 0
    property double dirStamp: 0
    function noteSkip(d) { dirHint = d; dirStamp = Date.now(); }
    function currentDir() { return (Date.now() - dirStamp < 2500) ? dirHint : 0; }
    Process {
        running: w.animOn && w.animStyle !== "crossfade"
        command: ["dbus-monitor", "--session", "type='method_call',interface='org.mpris.MediaPlayer2.Player'"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("member=Next") >= 0) w.noteSkip(1);
                else if (line.indexOf("member=Previous") >= 0) w.noteSkip(-1);
            }
        }
    }

    // ───────────── track state -> transitions ─────────────
    readonly property string titleText: player ? (player.trackTitle || I18n.tr("Unknown title")) : I18n.tr("Nothing is playing")
    readonly property string artistText: player ? player.trackArtist : I18n.tr("No player active")
    readonly property string artText: player ? String(player.trackArtUrl || "") : ""
    readonly property string trackKey: (player ? player.dbusName : "none") + "|" + titleText + "|" + artistText + "|" + artText
    property bool started: false
    property real contentOpacity: 0
    Behavior on contentOpacity { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }

    // wait a moment so the player list is filled before the first picture is shown (no empty-state flash), then fade in
    Timer { interval: 420; running: true; onTriggered: { w.applyTrack(true); w.started = true; w.contentOpacity = 1; } }
    onTrackKeyChanged: if (started) applyTrack(false)

    function applyTrack(initial) {
        var d = initial ? 0 : currentDir();
        cover.dir = d; titleT.dir = d; artistT.dir = d;
        cover.source = artText;
        cover.sourceKnown = true;
        titleT.setText(titleText);
        artistT.setText(artistText);
        if (!initial) {
            kick.stop();
            kickUp.to = d !== 0 ? -d * 15 : 11;
            kick.start();
        }
    }
    // the specular highlight travels a little with the change, then settles back (liquid glass only has an effect there)
    SequentialAnimation {
        id: kick
        NumberAnimation { id: kickUp; target: w; property: "lightPulse"; duration: w.animDur * 0.45; easing.type: Easing.OutCubic }
        NumberAnimation { target: w; property: "lightPulse"; to: 0; duration: w.animDur * 0.9; easing.type: Easing.OutCubic }
    }

    // optional: accent from the album cover instead of the theme
    CoverColor { id: coverColor; source: w.props.cover_colors ? cover.shownUrl : ""; lightBackground: w.style.dark === false }
    property color accent: (w.props.cover_colors && coverColor.valid) ? coverColor.color : w.style.accent
    Behavior on accent { ColorAnimation { duration: 650; easing.type: Easing.OutCubic } }

    // ───────────── progress ─────────────
    readonly property real progTarget: (player && player.lengthSupported && player.length > 0 && player.positionSupported) ? Math.max(0, Math.min(1, player.position / player.length)) : 0
    property real prog: 0
    onProgTargetChanged: {
        if (Math.abs(progTarget - prog) > 0.03) { progAnim.to = progTarget; progAnim.restart(); }   // song change / seek: glide
        else if (!progAnim.running) prog = progTarget;                                              // normal 1 Hz tick: no animation
    }
    NumberAnimation { id: progAnim; target: w; property: "prog"; duration: 460; easing.type: Easing.OutCubic }
    Timer { interval: 1000; repeat: true; running: w.playing && (w.props.show_progress !== false || w.turntable); onTriggered: { try { w.player.positionChanged(); } catch (e) { } } }

    // ───────────── layout ─────────────
    // the style switch is a crossfade between the two views (the glass behind is not touched)
    Loader {
        id: ttLoader
        anchors.fill: parent
        opacity: w.turntable ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        active: w.turntable || opacity > 0.01
        visible: opacity > 0.01
        sourceComponent: TurntableView { host: w }
    }
    Item {
      id: normalView
      anchors.fill: parent
      opacity: w.turntable ? 0 : 1
      visible: opacity > 0.01
      Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    Row {
        anchors.fill: parent
        spacing: 14
        opacity: w.contentOpacity

        CoverStack {
            id: cover
            visible: w.props.show_cover
            height: parent.height; width: height
            radius: w.innerRadius
            accent: w.accent
            animate: w.animOn
            animStyle: w.animStyle
            dur: w.animDur
            zoom: w.animZoom
            playing: w.playing
            glowOn: w.props.cover_colors === true
            started: w.started
        }

        Column {
            width: parent.width - (cover.visible ? cover.width + 14 : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            SwapText {
                id: titleT
                width: parent.width
                family: Fonts.resolve(w.style.font); pixelSize: w.style.font_size * 1.2; bold: true; color: w.style.fg
                stagger: 0
                animate: w.animOn; dur: w.animDur; started: w.started
            }
            SwapText {
                id: artistT
                width: parent.width
                family: Fonts.resolve(w.style.font); pixelSize: w.style.font_size; color: w.style.fg; textOpacity: 0.62
                stagger: 70
                animate: w.animOn; dur: w.animDur; started: w.started
            }

            Item {
                visible: w.props.show_progress !== false
                width: parent.width; height: visible ? 14 : 0
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.16)
                    Rectangle { width: parent.width * w.prog; height: parent.height; radius: 2; color: w.accent }
                }
            }

            Row {
                visible: w.props.show_controls
                topPadding: 4
                spacing: 8
                MButton {
                    width: w.style.font_size * 2.3; height: w.style.font_size * 1.7
                    hoverColor: w.accent; animate: w.animOn
                    onClicked: { w.noteSkip(-1); if (w.player) w.player.previous(); }
                    Glyph { anchors.centerIn: parent; width: parent.height * 0.42; height: width; color: w.style.fg; kind: "prev" }
                }
                MButton {
                    width: w.style.font_size * 2.3; height: w.style.font_size * 1.7
                    hoverColor: w.accent; strong: true; animate: w.animOn
                    onClicked: if (w.player) w.player.togglePlaying()
                    // play <-> pause morph: crossfade with a little spring on the scale
                    Item {
                        anchors.centerIn: parent; width: parent.height * 0.42; height: width
                        Glyph {
                            anchors.fill: parent; color: w.style.fg; kind: "play"
                            opacity: w.playing ? 0 : 1; scale: w.playing ? 0.4 : 1
                            Behavior on opacity { NumberAnimation { duration: w.animOn ? 170 : 0 } }
                            Behavior on scale { enabled: w.animOn; SpringAnimation { spring: 5; damping: 0.28; epsilon: 0.002 } }
                        }
                        Glyph {
                            anchors.fill: parent; color: w.style.fg; kind: "pause"
                            opacity: w.playing ? 1 : 0; scale: w.playing ? 1 : 0.4
                            Behavior on opacity { NumberAnimation { duration: w.animOn ? 170 : 0 } }
                            Behavior on scale { enabled: w.animOn; SpringAnimation { spring: 5; damping: 0.28; epsilon: 0.002 } }
                        }
                    }
                }
                MButton {
                    width: w.style.font_size * 2.3; height: w.style.font_size * 1.7
                    hoverColor: w.accent; animate: w.animOn
                    onClicked: { w.noteSkip(1); if (w.player) w.player.next(); }
                    Glyph { anchors.centerIn: parent; width: parent.height * 0.42; height: width; color: w.style.fg; kind: "next" }
                }
            }
        }
    }
    }
}
