// Song lyrics of the playing track, in sync: the line that is being sung is bright, the others are dim, and the text scrolls along (like Spotify).
// Source: LRCLIB (lyrics/lyrics.sh, one request per song, cached on disk). Needs an MPRIS player; the position comes from the player.
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.Mpris
import "../core"

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})

    readonly property real fs: (style.font_size || 16) * Math.max(0.6, Number(props.text_size || 1.3))
    function s(v) { return v * (style.font_size || 16) / 16; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: style.accent || "#8ab4ff"
    readonly property bool live: Window.window !== null && Window.window.visible
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("lyrics/").toString().replace("file://", ""))
    readonly property bool centered: props.align === "center"

    // ───────────── player (same rule as the music widget) ─────────────
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
    readonly property string title: player ? String(player.trackTitle || "") : ""
    readonly property string artist: player ? String(player.trackArtist || "") : ""
    readonly property string album: player ? String(player.trackAlbum || "") : ""
    readonly property int secs: (player && player.lengthSupported && player.length > 0) ? Math.round(player.length) : 0
    readonly property string liveKey: title === "" ? "" : (artist + "|" + title + "|" + album + "|" + secs)
    // A player fills in title, artist, album and length one after the other: ask for the lyrics only once the data has stayed the same for a moment
    property string trackKey: ""
    onLiveKeyChanged: { if (liveKey === "") trackKey = ""; else keyTimer.restart(); }
    Timer { id: keyTimer; interval: 700; onTriggered: w.trackKey = w.liveKey }
    Component.onCompleted: trackKey = liveKey

    // ───────────── lyrics ─────────────
    property var d: ({ state: "", synced: "", plain: "", instrumental: false })
    property string dKey: ""                                   // the track the data belongs to (a new song clears the old text at once)
    readonly property bool mine: dKey === trackKey && trackKey === liveKey
    Feed {
        key: "lyrics:" + w.trackKey
        command: ["bash", w.dir + "lyrics.sh", w.artist, w.title, w.album, String(w.secs)]
        interval: 6 * 3600 * 1000
        active: w.live && w.trackKey !== ""
        onGot: text => {
            try { var o = JSON.parse(text); if (o && o.state) { w.d = o; w.dKey = w.trackKey; } } catch (e) { }
        }
    }
    readonly property string state: !player || liveKey === "" ? "idle" : (!mine ? "loading" : (d.state || "loading"))

    // "[mm:ss.xx] text" -> [{ t: seconds, text }] sorted by time; a line with several time tags counts for each; an empty text is an instrumental break
    readonly property var lines: {
        if (!mine || !d.synced) return [];
        var out = [], rows = String(d.synced).split("\n");
        for (var i = 0; i < rows.length; i++) {
            var m = /^((?:\[\d+:\d+(?:[.:]\d+)?\])+)\s*(.*)$/.exec(rows[i]);
            if (!m) continue;
            var tags = m[1].match(/\[\d+:\d+(?:[.:]\d+)?\]/g), text = m[2].trim();
            for (var k = 0; k < tags.length; k++) {
                var t = /\[(\d+):(\d+)(?:[.:](\d+))?\]/.exec(tags[k]);
                out.push({ t: Number(t[1]) * 60 + Number(t[2]) + (t[3] ? Number("0." + t[3]) : 0), text: text });
            }
        }
        out.sort(function (a, b) { return a.t - b.t; });
        return out;
    }

    property real pos: 0                                        // seconds into the song
    Timer {
        interval: 200; repeat: true; running: w.live && w.playing && w.lines.length > 0
        onTriggered: { try { w.player.positionChanged(); } catch (e) { } w.pos = w.player.positionSupported ? w.player.position : 0; }
    }
    onLinesChanged: pos = (player && player.positionSupported) ? player.position : 0
    // the line being sung: the last one that has started (a small head start, so the light comes on as the singer begins)
    readonly property int cur: {
        var l = lines, p = pos + 0.3, lo = 0, hi = l.length - 1, r = -1;
        while (lo <= hi) { var mid = (lo + hi) >> 1; if (l[mid].t <= p) { r = mid; lo = mid + 1; } else hi = mid - 1; }
        return r;
    }

    // ───────────── drawing ─────────────
    Item {
        id: view
        anchors.fill: parent
        clip: true
        visible: w.lines.length > 0

        Column {
            id: col
            width: parent.width
            spacing: w.s(14)
            // keep the current line in the vertical middle (a little above it: the lines to come matter more)
            readonly property Item curItem: rep.count > 0 && w.cur >= 0 ? rep.itemAt(Math.min(w.cur, rep.count - 1)) : null
            y: curItem ? Math.round(view.height * 0.42 - (curItem.y + curItem.height / 2)) : Math.round(view.height * 0.42)
            Behavior on y { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }

            Repeater {
                id: rep
                model: w.lines
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: col.width; height: lineT.implicitHeight
                    readonly property int dist: Math.abs(index - w.cur)
                    readonly property bool on: index === w.cur
                    GText {
                        id: lineT
                        width: parent.width; wrapMode: Text.WordWrap
                        horizontalAlignment: w.centered ? Text.AlignHCenter : Text.AlignLeft
                        wstyle: w.style; font.bold: true; font.pixelSize: w.fs
                        text: modelData.text === "" ? "♪" : modelData.text
                        color: parent.on && w.props.accent_current === true ? w.cAcc : w.cFg
                        opacity: parent.on ? 1.0 : Math.max(0.1, 0.5 - 0.1 * (parent.dist - 1))
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }
    }

    // the title above the text (optional)
    GText {
        visible: w.props.show_title === true && w.title !== ""
        anchors { left: parent.left; right: parent.right; top: parent.top }
        elide: Text.ElideRight; wstyle: w.style; opacity: 0.6; font.pixelSize: (w.style.font_size || 16) * 0.8
        horizontalAlignment: w.centered ? Text.AlignHCenter : Text.AlignLeft
        text: w.artist !== "" ? w.title + " – " + w.artist : w.title
    }

    // no lyrics to show: say why
    Column {
        visible: w.lines.length === 0
        anchors.centerIn: parent
        width: parent.width
        spacing: w.s(6)
        GText {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            wstyle: w.style; font.bold: true; font.pixelSize: (w.style.font_size || 16) * 1.05; opacity: 0.8
            text: w.state === "idle" ? I18n.tr("Nothing is playing") : w.title
        }
        GText {
            visible: w.state !== "idle"
            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            wstyle: w.style; opacity: 0.55; font.pixelSize: (w.style.font_size || 16) * 0.85
            text: w.state === "loading" ? I18n.tr("Searching lyrics ...")
                : (w.state === "error" ? I18n.tr("The lyrics service cannot be reached")
                : (w.d.instrumental ? I18n.tr("Instrumental") : I18n.tr("No synchronised lyrics found for this song")))
        }
    }
}
