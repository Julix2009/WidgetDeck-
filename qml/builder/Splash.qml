// Start animation of the builder: a single "W" appears, unfolds into "WidgetDeck", then the whole layer zooms away and
// the builder (built underneath in the meantime) is there. A click or a key skips it. Switched off in the settings.
import QtQuick

Rectangle {
    id: sp
    required property var th
    property bool ready: true             // the intro waits at the full name until the builder has its data
    property real slow: 1                 // development: stretches the animation
    property real reveal: 0               // 0 = only the W, 1 = the whole name
    property real tint: 0                 // 0 = the W in the accent colour, 1 = in the text colour
    signal finished()

    color: th.bg
    function start() { intro.start(); }
    function skip() { if (!outro.running) { intro.stop(); outro.start(); } }

    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: sp.skip(); onWheel: wheel => wheel.accepted = true }

    Row {
        id: word
        anchors.centerIn: parent
        opacity: 0
        scale: 0.6
        Text {
            id: w
            text: "W"; font.family: sp.th.font; font.pixelSize: 96; font.weight: Font.Black; renderType: Text.QtRendering
            color: Qt.tint(sp.th.accent, Qt.alpha(sp.th.fg, sp.tint))
        }
        Item {                            // the rest unfolds to the right, which pushes the W to the left
            width: rest.implicitWidth * sp.reveal; height: rest.implicitHeight; clip: true
            Row {
                id: rest
                opacity: sp.reveal
                Text { text: "idget"; font: w.font; color: sp.th.fg; renderType: Text.QtRendering }
                Text { text: "Deck"; font: w.font; color: sp.th.accent; renderType: Text.QtRendering }
            }
        }
    }
    Rectangle {                           // a line that draws itself under the name
        anchors { top: word.bottom; topMargin: 10; horizontalCenter: parent.horizontalCenter }
        width: word.width * sp.reveal; height: 4; radius: 2; color: sp.th.accent; opacity: sp.reveal * word.opacity
    }

    SequentialAnimation {
        id: intro
        ParallelAnimation {
            NumberAnimation { target: word; property: "opacity"; to: 1; duration: 260 * sp.slow; easing.type: Easing.OutCubic }
            NumberAnimation { target: word; property: "scale"; to: 1; duration: 480 * sp.slow; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
        PauseAnimation { duration: 160 * sp.slow }
        ParallelAnimation {
            NumberAnimation { target: sp; property: "reveal"; to: 1; duration: 520 * sp.slow; easing.type: Easing.InOutCubic }
            NumberAnimation { target: sp; property: "tint"; to: 1; duration: 520 * sp.slow }
        }
        PauseAnimation { duration: 420 * sp.slow }
        ScriptAction { script: if (sp.ready) outro.start(); else waiting.start() }
    }
    Timer { id: waiting; interval: 100; repeat: true; property int n: 0; onTriggered: if (sp.ready || ++n > 30) { stop(); outro.start(); } }

    ParallelAnimation {
        id: outro
        NumberAnimation { target: word; property: "scale"; to: 1.35; duration: 380 * sp.slow; easing.type: Easing.InCubic }
        NumberAnimation { target: sp; property: "opacity"; to: 0; duration: 380 * sp.slow; easing.type: Easing.InQuad }
        onFinished: { sp.visible = false; sp.finished(); }
    }
}
