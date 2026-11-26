// The album cover cut to a rounded shape (radius = half the width makes it a circle); a note sign while there is no picture.
import QtQuick
import QtQuick.Effects
import "../../core"

Item {
    id: c
    property string source: ""
    property real radius: 12
    property color tint: "#8ab4ff"
    Rectangle { anchors.fill: parent; radius: c.radius; color: Qt.alpha(c.tint, 0.28); visible: img.status !== Image.Ready }
    Text { anchors.centerIn: parent; visible: img.status !== Image.Ready; text: "♪"; color: "#ccffffff"; font.pixelSize: c.height * 0.42; renderType: Text.QtRendering }
    Image {
        id: img
        anchors.fill: parent; source: c.source; asynchronous: true; fillMode: Image.PreserveAspectCrop
        sourceSize.width: 480; visible: false
    }
    Rectangle { id: msk; anchors.fill: parent; radius: c.radius; visible: false; layer.enabled: true; layer.smooth: true }
    MultiEffect { anchors.fill: parent; source: img; maskEnabled: true; maskSource: msk; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0; visible: img.status === Image.Ready }
}
