// A round cover that turns while the song plays, with the progress as a ring around it; title below.
import QtQuick
import QtQuick.Shapes
import "../../core"

Item {
    id: d
    required property var host
    readonly property bool labels: height > width * 1.1                      // tall widget: title and artist under the disc
    readonly property real side: Math.min(width, labels ? height - width * 0.32 : height)
    readonly property real ring: Math.max(3, side * 0.03)

    Item {
        id: disc
        width: d.side; height: d.side
        anchors.horizontalCenter: parent.horizontalCenter
        y: d.labels ? 0 : (d.height - height) / 2
        Shape {
            anchors.fill: parent; layer.enabled: true; layer.samples: 4
            ShapePath {
                strokeColor: "#33ffffff"; strokeWidth: d.ring; fillColor: "transparent"
                PathAngleArc { centerX: disc.width / 2; centerY: disc.height / 2; radiusX: disc.width / 2 - d.ring; radiusY: radiusX; startAngle: -90; sweepAngle: 359.9 }
            }
            ShapePath {
                strokeColor: d.host.accent; strokeWidth: d.ring; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: disc.width / 2; centerY: disc.height / 2; radiusX: disc.width / 2 - d.ring; radiusY: radiusX; startAngle: -90; sweepAngle: Math.max(0.1, d.host.prog * 360) }
            }
        }
        RoundCover {
            id: art
            anchors.centerIn: parent; width: parent.width - d.ring * 5; height: width; radius: width / 2
            source: d.host.artText; tint: d.host.accent
            // 6 revolutions a minute; stands still while paused or hidden
            NumberAnimation on rotation { running: d.host.live; paused: !d.host.playing; from: 0; to: 360; duration: 10000; loops: Animation.Infinite }
        }
        Rectangle { anchors.centerIn: parent; width: parent.width * 0.11; height: width; radius: width / 2; color: "#e6111318"; border.width: 2; border.color: d.host.accent }
        MouseArea { anchors.fill: art; cursorShape: Qt.PointingHandCursor; onClicked: d.host.togglePlay() }
    }
    Column {
        visible: d.labels
        anchors { top: disc.bottom; topMargin: d.side * 0.05; left: parent.left; right: parent.right }
        spacing: 2
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: d.host.tstyle; font.bold: true; font.pixelSize: Math.max(12, d.side * 0.08); text: d.host.titleText }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: d.host.tstyle; opacity: 0.7; font.pixelSize: Math.max(10, d.side * 0.058); text: d.host.artistText }
    }
}
