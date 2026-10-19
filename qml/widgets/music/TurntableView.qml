// Music style "Turntable": record with grooves, tonearm, title / artist / time and the buttons. The glass behind it is the shared GlassPanel
// (this item draws no glass, no fill, no tint). State and logic (player, track, progress) come from the MusicWidget (`host`) - this file only draws.
//   - only the record item spins (RotationAnimator = render thread); speed ramps are two animators with InQuad / OutQuad easing
//   - the arm swings with short GUI-thread animations (< 1 s) and then follows the progress once a second; nothing runs while paused / hidden
import QtQuick
import "../../core"

Item {
    id: tt
    required property var host
    readonly property var pr: host.props
    readonly property real fs: host.style.font_size
    readonly property bool wide: width >= height * 1.25
    readonly property real gap: 14
    readonly property bool live: host.live
    readonly property string shownTitle: host.idle ? I18n.tr("No playback") : host.titleText
    readonly property string shownArtist: host.idle ? "" : host.artistText
    opacity: host.contentOpacity

    // ───────────── geometry: everything is a fraction of the deck square sq ─────────────
    readonly property real sq: wide ? height : Math.max(60, Math.min(width, height - titleT.height - artistT.height - 4))
    readonly property real cx: 0.44 * sq
    readonly property real cy: 0.55 * sq
    readonly property real rr: 0.43 * sq
    readonly property real px: 0.89 * sq
    readonly property real py: 0.11 * sq
    readonly property real armL: 0.62 * sq
    readonly property real dist: Math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy))
    readonly property real theta0: Math.atan2(px - cx, cy - py) * 180 / Math.PI
    function angleFor(rho) {      // arm angle at which the needle is `rho` from the record centre (law of cosines)
        var c = (dist * dist + armL * armL - rho * rho) / (2 * dist * armL);
        return theta0 - Math.acos(Math.max(-1, Math.min(1, c))) * 180 / Math.PI;
    }
    readonly property real aStart: angleFor(0.93 * rr)
    readonly property real aEnd: angleFor(0.50 * rr)
    readonly property real aPark: aStart - 24
    readonly property bool follow: host.hasLen && pr.arm_follows !== false
    readonly property real followAngle: aStart + (aEnd - aStart) * (follow ? Math.max(0, Math.min(1, host.prog)) : 0.3)

    // ───────────── record ─────────────
    CoverColor { id: cc; source: pr.vinyl_color === "cover" ? platter.shownUrl : ""; lightBackground: false }
    Item {
        id: deck
        width: tt.sq; height: tt.sq
        x: tt.wide ? 0 : (tt.width - tt.sq) / 2
        // platter rim
        Rectangle { x: tt.cx - tt.rr * 1.045; y: tt.cy - tt.rr * 1.045; width: tt.rr * 2.09; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14) }
        VinylDisc {
            id: platter
            layer.enabled: true; layer.smooth: true        // the whole record is one cached texture: spinning only draws a rotated quad
            layer.textureSize: Qt.size(Math.ceil(width * 2), Math.ceil(width * 2))
            x: tt.cx - tt.rr; y: tt.cy - tt.rr; width: tt.rr * 2; height: width
            vinyl: (pr.vinyl_color === "cover" && cc.valid) ? Qt.tint("#0e0e10", Qt.rgba(cc.color.r, cc.color.g, cc.color.b, 0.28)) : "#0e0e10"
            accent: host.style.accent
            cover: host.artText
            started: host.started
            dur: host.animDur
        }
        // light reflection: stays where it is while the record turns underneath (it is NOT a child of the record)
        Canvas {
            visible: pr.glare !== false
            x: tt.cx - tt.rr; y: tt.cy - tt.rr; width: 512; height: 512
            transformOrigin: Item.TopLeft; scale: platter.width / 512
            renderTarget: Canvas.Image
            onPaint: {
                var c = getContext("2d"), r = 256, tp = Math.PI * 2;
                c.reset();
                var g = c.createConicalGradient(r, r, -0.95);
                g.addColorStop(0.00, "rgba(255,255,255,0)"); g.addColorStop(0.035, "rgba(255,255,255,0.20)"); g.addColorStop(0.085, "rgba(255,255,255,0)");
                g.addColorStop(0.50, "rgba(255,255,255,0)"); g.addColorStop(0.535, "rgba(255,255,255,0.13)"); g.addColorStop(0.585, "rgba(255,255,255,0)");
                g.addColorStop(1.00, "rgba(255,255,255,0)");
                c.fillStyle = g;
                c.beginPath(); c.arc(r, r, r * 0.975, 0, tp, false); c.moveTo(r + r * 0.42, r); c.arc(r, r, r * 0.42, 0, tp, true); c.fill();
            }
            Component.onCompleted: requestPaint()
        }
        Tonearm { id: arm; x: tt.px; y: tt.py; unit: tt.sq; armLength: tt.armL; angle: tt.armAngle; lift: tt.lift; accent: host.style.accent }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: host.togglePlay() }     // record or arm: play / pause
    }

    // ───────────── text and buttons ─────────────
    HoverHandler { id: hov }
    Column {
        id: textCol
        x: tt.wide ? tt.sq + tt.gap : 0
        y: tt.wide ? (tt.height - height) / 2 : tt.sq + 2
        width: tt.wide ? tt.width - tt.sq - tt.gap : tt.width
        spacing: 0
        SwapText {
            id: titleT
            width: parent.width
            family: Fonts.resolve(host.style.font); pixelSize: host.style.font_size * 1.2; bold: true; color: host.style.fg
            stagger: 0; animate: host.animOn; dur: host.animDur; started: host.started
        }
        SwapText {
            id: artistT
            width: parent.width
            family: Fonts.resolve(host.style.font); pixelSize: host.style.font_size; color: host.style.fg; textOpacity: 0.62
            stagger: 70; animate: host.animOn; dur: host.animDur; started: host.started
        }
        Text {
            visible: tt.wide && !host.idle && host.timeText !== ""
            topPadding: 2; width: parent.width; elide: Text.ElideRight
            font.family: Fonts.resolve(host.style.font); font.pixelSize: host.style.font_size * 0.9; color: host.style.fg; opacity: 0.74; renderType: Text.QtRendering
            text: host.timeText
        }
        ControlRow { host: tt.host; visible: tt.wide; topPadding: 6 }
    }
    // small layout: the buttons appear on hover, over the lower edge of the record
    ControlRow {
        host: tt.host
        visible: !tt.wide && opacity > 0.01
        opacity: hov.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        x: (tt.width - width) / 2; y: deck.y + tt.sq - height - 4
    }
    onShownTitleChanged: { titleT.dir = host.currentDir(); titleT.setText(shownTitle); }
    onShownArtistChanged: { artistT.dir = host.currentDir(); artistT.setText(shownArtist); }

    // ───────────── record spin: speed ramps with inertia, only while playing and visible ─────────────
    readonly property real revMs: pr.rpm === "45" ? 60000 / 45 : 60000 / 33.3333
    readonly property real omega: 360 / revMs                       // degrees per ms
    property string spinState: "stopped"                            // stopped | up | steady | down
    readonly property bool spinWanted: host.playing && live
    function ang() { var r = platter.rotation % 360; return r < 0 ? r + 360 : r; }
    function stopSpin() { upAnim.stop(); steadyAnim.stop(); downAnim.stop(); }
    function spinUp() {
        stopSpin(); var r = ang(); platter.rotation = r;
        upAnim.from = r; upAnim.to = r + omega * upAnim.duration / 2;       // linear speed ramp 0 -> omega = quadratic angle
        spinState = "up"; upAnim.start();
    }
    function startSteady() {
        if (spinState !== "up" && spinState !== "steady") return;
        stopSpin(); var r = ang(); platter.rotation = r;
        steadyAnim.from = r; steadyAnim.to = r + 360; steadyAnim.duration = revMs;
        spinState = "steady"; steadyAnim.start();
    }
    function spinDown() {
        stopSpin(); var r = ang(); platter.rotation = r;
        downAnim.from = r; downAnim.to = r + omega * downAnim.duration / 2;
        spinState = "down"; downAnim.start();
    }
    function syncSpin() {
        if (spinWanted) { if (spinState === "stopped" || spinState === "down") spinUp(); }
        else if (spinState === "up" || spinState === "steady") { if (live) spinDown(); else { stopSpin(); platter.rotation = ang(); spinState = "stopped"; } }
        else if (!live && spinState === "down") { stopSpin(); platter.rotation = ang(); spinState = "stopped"; }
    }
    onSpinWantedChanged: syncSpin()
    onRevMsChanged: if (spinState === "steady") startSteady()
    RotationAnimator { id: upAnim; target: platter; duration: 800; easing.type: Easing.InQuad; onFinished: tt.startSteady() }
    RotationAnimator { id: steadyAnim; target: platter; loops: Animation.Infinite; easing.type: Easing.Linear }
    RotationAnimator { id: downAnim; target: platter; duration: 1000; easing.type: Easing.OutQuad; onFinished: { tt.spinState = "stopped"; platter.rotation = tt.ang(); } }

    // ───────────── tonearm: park <-> record, follows the progress ─────────────
    property real armAngle: aPark
    property real lift: 0
    property bool onRecord: false
    property var steps: []
    property int stepIdx: 0
    function runSteps(list) { stepAnim.stop(); steps = list; stepIdx = -1; nextStep(); }
    function nextStep() {
        stepIdx++;
        if (stepIdx >= steps.length) return;
        var s = steps[stepIdx];
        liftA.to = s.lift; liftA.duration = Math.max(1, s.lms); liftA.easing.type = s.lease !== undefined ? s.lease : Easing.OutCubic;
        angA.to = s.angle === "target" ? followAngle : (s.angle !== undefined ? s.angle : armAngle); angA.duration = Math.max(1, s.ams || 1);
        stepAnim.start();
    }
    ParallelAnimation {
        id: stepAnim
        NumberAnimation { id: liftA; target: tt; property: "lift" }
        NumberAnimation { id: angA; target: tt; property: "armAngle"; easing.type: Easing.InOutCubic }
        onFinished: tt.nextStep()
    }
    function dropArm() { return [{ lift: 1, lms: 130 }, { lift: 1, lms: 1, angle: "target", ams: 620 }, { lift: 0, lms: 380, lease: Easing.OutBounce, angle: "target", ams: 380 }]; }
    function syncArm(reason) {
        var wantOn = host.playing && live;
        if (!live) { stepAnim.stop(); lift = 0; armAngle = wantOn ? followAngle : aPark; onRecord = wantOn; return; }
        if (!wantOn) {
            onRecord = false;
            if (armAngle !== aPark || lift !== 0 || stepAnim.running)
                runSteps([{ lift: 1, lms: 140 }, { lift: 1, lms: 1, angle: aPark, ams: 620 }, { lift: 0, lms: 260, angle: aPark, ams: 260 }]);
        } else if (!onRecord) { onRecord = true; runSteps(dropArm()); }
        else if (reason === "track") {       // skip: lift, swing back to the outer groove, set down again (a running move is retargeted from where it is)
            runSteps([{ lift: 1, lms: 130 }, { lift: 1, lms: 1, angle: aStart, ams: 380 }, { lift: 1, lms: 1, ams: 160 }, { lift: 0, lms: 380, lease: Easing.OutBounce, angle: "target", ams: 380 }]);
        }
    }
    readonly property bool playingNow: host.playing
    onPlayingNowChanged: syncArm("state")
    onLiveChanged: { syncArm("state"); syncSpin(); }
    readonly property string trackKey: host.trackKey
    onTrackKeyChanged: if (host.started) syncArm("track")
    // follow the progress: one small step per second (seek: the host glides its progress value)
    onFollowAngleChanged: if (onRecord && !stepAnim.running && live && host.playing) armAngle = followAngle
    Component.onCompleted: { armAngle = aPark; syncSpin(); syncArm("state"); }
}
