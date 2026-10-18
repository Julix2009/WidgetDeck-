// One cover image layer. Enter / exit are state changes that Behaviors animate, so a retarget in the middle of a
// transition continues from the CURRENT values (no restart, no jump).
import QtQuick
import QtQuick.Effects

Item {
    id: lyr
    required property var stack
    property string url: ""
    property bool pending: false        // url is being loaded for an upcoming enter
    property bool entered: false
    property bool moving: false         // true while a transition runs -> GPU layer + blur only then
    property real tx: 0
    property real sc: 1
    property bool animOn: true
    readonly property bool loaded: url === "" || img.status === Image.Ready || img.status === Image.Error
    property alias imgStatus: img.status
    signal freed()

    opacity: 0
    visible: opacity > 0.002
    layer.enabled: moving
    layer.smooth: true
    layer.effect: MultiEffect {
        blurEnabled: lyr.stack.blurAmount > 0
        blurMax: 20
        blur: Math.max(0, Math.min(1, (1 - lyr.opacity) * lyr.stack.blurAmount))
    }
    transform: [
        Scale { origin.x: lyr.width / 2; origin.y: lyr.height / 2; xScale: lyr.sc; yScale: lyr.sc },
        Translate { x: lyr.tx }
    ]

    // incoming fades out-cubic, outgoing stays opaque longer (in-cubic): the two never dip into the background
    Behavior on opacity { enabled: lyr.animOn; NumberAnimation { duration: lyr.entered ? lyr.stack.effDur : lyr.stack.effDur * 0.9; easing.type: lyr.entered ? Easing.OutCubic : Easing.InCubic } }
    Behavior on tx { enabled: lyr.animOn; NumberAnimation { duration: lyr.stack.effDur; easing.type: Easing.OutCubic } }
    Behavior on sc { enabled: lyr.animOn; NumberAnimation { duration: lyr.stack.effDur; easing.type: lyr.entered ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.1 } }

    Image {
        id: img
        anchors.fill: parent
        source: lyr.url
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        sourceSize.width: 360
        visible: status === Image.Ready
    }
    // fallback: accent gradient with a note (no cover / load error)
    Rectangle {
        anchors.fill: parent
        visible: lyr.url === "" || img.status === Image.Error
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(lyr.stack.accent, 1.15) }
            GradientStop { position: 1.0; color: Qt.darker(lyr.stack.accent, 1.9) }
        }
        Text { anchors.centerIn: parent; text: "♪"; color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: parent.height * 0.42; renderType: Text.QtRendering }
    }

    onLoadedChanged: if (loaded && pending) stack.layerLoaded(lyr)
    onOpacityChanged: if (opacity < 0.02 && !entered && !pending) freed()

    function enter(dx, s0) {
        animOn = false; opacity = 0; tx = dx; sc = s0; animOn = true;
        entered = true; moving = true; settle.restart();
        opacity = 1; tx = 0; sc = 1;
    }
    function exit(dx, s1) {
        entered = false; moving = true; settle.restart();
        opacity = 0; tx = dx; sc = s1;
    }
    Timer { id: settle; interval: lyr.stack.effDur + 90; onTriggered: lyr.moving = false }
}
