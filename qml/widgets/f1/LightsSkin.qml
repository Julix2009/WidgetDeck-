// The five start lights: one more column lights up for every day the race comes closer (all five on race day, out while
// the race runs). Under them the race and the countdown as three tiles.
import QtQuick
import "../../core"
import "Model.js" as M

Item {
    id: s
    required property var host
    readonly property var p: host.target ? M.parts(host.target, host.now) : null
    readonly property int lit: host.shown.kind === "running" ? 0 : (!p ? 0 : Math.max(0, Math.min(5, 5 - p.d)))
    readonly property real w0: Math.min(width, height * 1.38)     // the content is about 70 % as high as wide
    readonly property real u: w0 / 100                     // everything scales with the card width
    readonly property real d: u * 11                       // lamp diameter
    readonly property string ff: Fonts.resolve(host.style.font)
    readonly property var segs: !p ? [] : (p.total < 3600 ? [{ n: p.m, l: I18n.tr("min") }, { n: p.s, l: I18n.tr("s") }]
        : [{ n: p.d, l: I18n.tr("d") }, { n: p.h, l: I18n.tr("h") }, { n: p.m, l: I18n.tr("min") }])

    component T: Text { color: "#f4f5f8"; font.family: s.ff; renderType: Text.QtRendering }

    Rectangle {
        anchors.centerIn: parent
        width: s.w0
        height: col.height + s.u * 8
        radius: s.u * 5
        color: "#f2111111"
        border.width: 1; border.color: "#1fffffff"

        Column {
            id: col
            anchors.centerIn: parent
            width: parent.width - s.u * 8
            spacing: s.u * 3

            // gantry: a bar with five hanging pods of two lamps
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: s.d * 7.4; height: s.d * 2.75
                Rectangle { y: s.d * 0.2; width: parent.width; height: s.d * 0.22; radius: height / 2; color: "#2d2d2d" }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: s.d * 0.18
                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            id: pod
                            required property int index
                            readonly property bool on: index < s.lit
                            width: s.d * 1.32; height: s.d * 2.75; radius: s.d * 0.42
                            gradient: Gradient { GradientStop { position: 0; color: "#262626" } GradientStop { position: 1; color: "#090909" } }
                            border.width: 1; border.color: "#26ffffff"
                            Column {
                                anchors.centerIn: parent
                                spacing: s.d * 0.2
                                Repeater {
                                    model: 2
                                    delegate: Item {
                                        width: s.d; height: s.d
                                        // soft glow: stacked translucent discs
                                        Repeater {
                                            model: pod.on ? [1.55, 1.34, 1.16] : []
                                            delegate: Rectangle { required property real modelData; anchors.centerIn: parent; width: s.d * modelData; height: width; radius: width / 2; color: "#24ff1e12" }
                                        }
                                        Rectangle {
                                            anchors.fill: parent; radius: width / 2
                                            gradient: Gradient {
                                                GradientStop { position: 0; color: pod.on ? "#ff6a52" : "#1f1f1f" }
                                                GradientStop { position: 1; color: pod.on ? "#d50f06" : "#111111" }
                                            }
                                            border.width: Math.max(1, s.d * 0.06); border.color: pod.on ? "#ff3b2a" : "#2f2f2f"
                                            Rectangle { x: parent.width * 0.22; y: parent.height * 0.14; width: parent.width * 0.34; height: width * 0.62; radius: height / 2; color: pod.on ? "#80ffffff" : "#14ffffff"; rotation: -28 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            T { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: s.host.race ? M.raceName(s.host.race.name, s.host.lang) : ""; font.weight: Font.Black; font.pixelSize: s.u * 5.6 }

            Row {
                visible: s.segs.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: s.u * 2
                Repeater {
                    model: s.segs
                    delegate: Rectangle {
                        required property var modelData
                        width: s.u * 17; height: s.u * 11; radius: s.u * 2.6; color: "#12ffffff"
                        Row {
                            anchors.centerIn: parent; spacing: s.u * 0.8
                            T { id: num; text: modelData.n < 10 ? "0" + modelData.n : modelData.n; font.weight: Font.Black; font.pixelSize: s.u * 6.4; font.features: ({ "tnum": 1 }) }
                            T { anchors.baseline: num.baseline; text: modelData.l; color: "#8a8d96"; font.weight: Font.Bold; font.pixelSize: s.u * 3 }
                        }
                    }
                }
            }
            T { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: s.segs.length > 0 ? s.host.raceLine : (s.host.target ? s.host.remaining(s.host.target) : s.host.raceLine); color: "#9ea1ab"; font.pixelSize: s.u * 3.4 }
        }
    }
}
