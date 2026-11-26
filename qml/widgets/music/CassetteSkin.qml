// A cassette: the label carries cover, title and artist, the two reels turn while the song plays and the tape moves from
// the left reel to the right one. Under the cassette: progress, time and the controls.
import QtQuick
import "../../core"

Item {
    id: c
    required property var host
    readonly property real w: Math.min(width, height * 1.3)
    readonly property real u: w / 100                       // the cassette is 100 x 63 units
    readonly property bool controls: host.props.show_controls !== false
    readonly property bool progress: host.props.show_progress !== false
    readonly property color accent: host.accent
    readonly property string ff: Fonts.resolve(host.style.font)
    property real turn: 0
    NumberAnimation on turn { running: c.host.live; paused: !c.host.playing; from: 0; to: 360; duration: 2800; loops: Animation.Infinite }

    component T: Text { font.family: c.ff; renderType: Text.QtRendering; elide: Text.ElideRight }

    component Screw: Rectangle {
        width: c.u * 3; height: width; radius: width / 2
        color: "#171717"; border.width: 1; border.color: "#40ffffff"
        Rectangle { anchors.centerIn: parent; width: parent.width * 0.62; height: Math.max(1, parent.width * 0.13); color: "#70ffffff"; rotation: 45 }
    }

    component Reel: Item {
        id: reel
        property real tape: 0.5                             // 0..1 of the tape on this reel
        width: c.u * 15; height: width
        Rectangle {                                         // wound tape
            anchors.centerIn: parent; width: c.u * (11 + 8 * reel.tape); height: width; radius: width / 2
            color: "#2b1d17"; border.width: Math.max(1, c.u * 0.3); border.color: "#4a342a"
        }
        Item {                                              // hub with six teeth
            anchors.centerIn: parent; width: c.u * 10; height: width; rotation: c.turn
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#eef0f4" }
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.64; height: width; radius: width / 2; color: "#161616" }
            Repeater {
                model: 6
                delegate: Item {
                    required property int index
                    anchors.fill: parent; rotation: index * 60
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.17; width: parent.width * 0.11; height: parent.height * 0.16; radius: width / 3; color: "#eef0f4" }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: c.w
        spacing: c.u * 3

        // ── the cassette ──
        Rectangle {
            width: c.w; height: c.u * 63; radius: c.u * 5
            gradient: Gradient { GradientStop { position: 0; color: "#f2373737" } GradientStop { position: 1; color: "#f2181818" } }
            border.width: 1; border.color: "#30ffffff"

            Screw { x: c.u * 2; y: c.u * 2 }
            Screw { x: parent.width - width - c.u * 2; y: c.u * 2 }
            Screw { x: c.u * 2; y: parent.height - height - c.u * 2 }
            Screw { x: parent.width - width - c.u * 2; y: parent.height - height - c.u * 2 }

            // label
            Rectangle {
                x: c.u * 6.5; y: c.u * 4.5; width: c.u * 87; height: c.u * 45; radius: c.u * 3
                color: "#f3eee3"; clip: true

                // stripes in three shades of the accent colour
                Column {
                    y: c.u * 18; width: parent.width
                    Repeater {
                        model: [1.0, 0.72, 0.45]
                        delegate: Rectangle { required property real modelData; width: c.u * 87; height: c.u * 6.2; color: Qt.tint("#f3eee3", Qt.alpha(c.accent, modelData)) }
                    }
                }

                RoundCover { x: c.u * 3; y: c.u * 3; width: c.u * 12.5; height: width; radius: c.u * 2; source: c.host.artText; tint: "#505563" }
                Column {
                    x: c.u * 18; y: c.u * 3.2; width: parent.width - x - c.u * 11
                    T { width: parent.width; text: c.host.titleText; color: "#181818"; font.weight: Font.Black; font.pixelSize: c.u * 5.6 }
                    T { width: parent.width; text: c.host.artistText; color: "#5d606a"; font.weight: Font.DemiBold; font.pixelSize: c.u * 3.9 }
                }
                T { anchors { right: parent.right; rightMargin: c.u * 3; top: parent.top; topMargin: c.u * 3 } text: "A"; color: "#181818"; font.weight: Font.Black; font.pixelSize: c.u * 8 }

                // window with the two reels and the tape between them
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter; y: c.u * 19.5
                    width: c.u * 60; height: c.u * 21; radius: height / 2
                    color: "#161616"; border.width: Math.max(1, c.u * 0.5); border.color: "#3e3e3e"
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; width: c.u * 16; height: c.u * 9; radius: c.u * 1.5; color: "#2affffff"
                        Row {                                // scale marks
                            anchors.centerIn: parent; spacing: c.u * 1.7
                            Repeater { model: 5; delegate: Rectangle { required property int index; width: Math.max(1, c.u * 0.45); height: c.u * (index === 2 ? 5 : 3); anchors.verticalCenter: parent.verticalCenter; color: "#90ffffff" } }
                        }
                    }
                    Reel { x: c.u * 3; anchors.verticalCenter: parent.verticalCenter; tape: 1 - c.host.prog }
                    Reel { x: parent.width - width - c.u * 3; anchors.verticalCenter: parent.verticalCenter; tape: c.host.prog }
                }
            }

            // lower edge: the raised part with the holes for the tape heads
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                width: c.u * 62; height: c.u * 10.5; topLeftRadius: c.u * 4; topRightRadius: c.u * 4
                color: "#20ffffff"
                Row {
                    anchors.centerIn: parent; spacing: c.u * 7
                    Repeater {
                        model: [2.6, 4, 4, 2.6]
                        delegate: Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: c.u * modelData; height: width; radius: width / 2; color: "#0c0c0c"; border.width: 1; border.color: "#30ffffff" }
                    }
                }
            }
        }

        // ── progress, time, controls ──
        Rectangle {
            visible: c.controls || c.progress
            width: c.w; height: c.u * 13; radius: height / 2
            color: "#f2181818"; border.width: 1; border.color: "#24ffffff"
            WaveProgress {
                visible: c.progress
                x: c.u * 6; anchors.verticalCenter: parent.verticalCenter
                width: (c.controls ? buttons.x : parent.width - c.u * 4) - x - time.width - c.u * 4; height: c.u * 5
                value: c.host.prog; played: c.accent; thickness: Math.max(2, c.u * 0.9)
            }
            T {
                id: time
                visible: c.progress
                anchors { right: c.controls ? buttons.left : parent.right; rightMargin: c.controls ? c.u * 2 : c.u * 6; verticalCenter: parent.verticalCenter }
                elide: Text.ElideNone; text: c.host.timeText; color: "#a8abb5"; font.pixelSize: c.u * 3.4; font.features: ({ "tnum": 1 })
            }
            SkinControls {
                id: buttons
                visible: c.controls
                x: c.progress ? parent.width - width - c.u * 2 : (parent.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                host: c.host; size: c.u * 9.5; fg: "#f2f4f8"
            }
        }
    }
}
