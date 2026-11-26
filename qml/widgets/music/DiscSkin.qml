// A round cover that turns while the song plays, with the progress as a ring around it; title below.
import QtQuick
import QtQuick.Shapes
import "../../core"

Item {
    id: d
    required property var host
    readonly property bool labels: height > width * 1.1                      // tall widget: title and artist under the disc
    readonly property bool beside: width > height * 1.55                     // wide widget: title, artist and controls to the right of the disc
    readonly property real side: Math.max(10, Math.min(width, labels ? height - width * 0.32 : height))
    readonly property real ring: Math.max(3, side * 0.03)

    Item {
        id: disc
        width: d.side; height: d.side
        x: d.beside ? 0 : (d.width - width) / 2
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
        visible: d.beside
        anchors { left: disc.right; leftMargin: d.side * 0.12; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: d.side * 0.03
        GText { width: parent.width; elide: Text.ElideRight; wstyle: d.host.tstyle; font.bold: true; font.pixelSize: Math.max(11, Math.min(d.side * 0.16, d.width * 0.055)); text: d.host.titleText }
        GText { width: parent.width; elide: Text.ElideRight; wstyle: d.host.tstyle; opacity: 0.75; font.pixelSize: Math.max(10, Math.min(d.side * 0.11, d.width * 0.038)); text: d.host.artistText }
        SkinControls { visible: d.host.props.show_controls !== false; host: d.host; size: Math.max(20, d.side * 0.18); fg: d.host.tstyle.fg || "#ffffff" }
    }
    Column {
        visible: d.labels
        anchors { top: disc.bottom; topMargin: d.side * 0.04; left: parent.left; right: parent.right }
        spacing: 2
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: d.host.tstyle; font.bold: true; font.pixelSize: Math.max(12, d.side * 0.08); text: d.host.titleText }
        GText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wstyle: d.host.tstyle; opacity: 0.7; font.pixelSize: Math.max(10, d.side * 0.058); text: d.host.artistText }
    }
}
