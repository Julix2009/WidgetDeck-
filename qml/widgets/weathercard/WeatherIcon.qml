// One weather icon. Big: aligned layers (sun, cloud, drops, ... and the soft drop shadow) from the Blender renders, each blended between neighbouring
// view angles (TiltLayer) so the object turns towards the mouse in real 3D, plus a gentle idle motion per layer and a light reflection that follows the
// mouse. Small: one merged image with a soft contact shadow. Layers move by position, opacity and the baked angle only - nothing here touches the glass.
// `t` is a clock in seconds that the card advances while it is visible and animations are on; a frozen `t` (level 0) means everything stands still.
import QtQuick
import QtQuick.Effects
import "Model.js" as M

Item {
    id: ic
    property string kind: "unknown"
    property bool day: true
    property real t: 0
    property int level: 0                       // 0 = still, 1 = subtle, 2 = full
    property real tilt: 0                       // hover direction -1 .. 1 (set by the card)
    property real tiltY: 0
    property bool hovering: false
    property bool big: true
    property bool shadowOn: true
    property real shadowStrength: 0.85          // lower on Liquid Glass (a fine dark gradient only)
    readonly property string ext: M.ICON_EXT
    readonly property string root: Qt.resolvedUrl("icons3d/")
    readonly property string vkey: M.variantKey(kind, day)
    readonly property var layers: M.layersFor(kind, day)
    readonly property real amp: Math.max(0.5, width / 118)
    readonly property real gain: level >= 2 ? 1.8 : 1
    readonly property bool moving: level > 0
    readonly property int px: Math.min(512, Math.max(96, Math.ceil(width * Screen.devicePixelRatio / 32) * 32))
    property real stx: tilt
    property real sty: tiltY
    Behavior on stx { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on sty { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // ---- small icon: merged image + contact shadow -----------------------------------------------------------------------------
    Image {
        visible: !ic.big && ic.shadowOn
        source: ic.root + "shadow_small." + ic.ext
        smooth: true; mipmap: true; cache: true
        sourceSize: Qt.size(Math.max(32, ic.px), Math.max(32, ic.px / 3))
        width: ic.width * 0.78; height: width / 3
        x: (ic.width - width) / 2 - ic.stx * 2; y: ic.height * 0.92 - height / 2
        opacity: ic.shadowStrength * 0.9
    }
    Image {
        visible: !ic.big
        source: ic.root + ic.vkey + "/small." + ic.ext
        smooth: true; mipmap: true; cache: true
        sourceSize: Qt.size(ic.px, ic.px)
        width: ic.width; height: ic.height
        x: ic.stx * 2; y: ic.sty * 1.2
    }

    // ---- big icon: shadow layer + body layers + highlight -----------------------------------------------------------------
    TiltLayer {
        visible: ic.big && ic.shadowOn
        base: ic.root + ic.vkey + "/shadow"; ext: ic.ext; px: ic.px
        yaw: ic.stx; pitch: ic.sty
        width: ic.width; height: ic.height
        x: 0; y: ic.moving ? Math.sin(ic.t * 1.35) * 0.8 * ic.amp * ic.gain : 0
        opacity: ic.shadowStrength * (ic.moving ? 0.9 + 0.08 * Math.sin(ic.t * 1.35 + 3.14) : 0.92)         // the shadow grows a little when the icon floats up
    }
    Item {                                                  // warm glow behind the sun (not part of the highlight mask)
        visible: ic.big
        width: ic.width; height: ic.height
        y: ic.moving ? Math.sin(ic.t * 1.35) * 2.6 * ic.amp * ic.gain : 0
        Image {
            readonly property var g: M.GLOWS[ic.vkey]
            visible: ic.big && !!g
            source: ic.root + "glow." + ic.ext; cache: true; smooth: true
            width: g ? g[2] / 2.25 * ic.width : 0; height: width
            x: g ? (0.5 + g[0] / 2.25) * ic.width - width / 2 + ic.stx * 3 * ic.amp : 0
            y: g ? (0.5 - g[1] / 2.25) * ic.height - height / 2 + ic.sty * 2 * ic.amp : 0
            opacity: 0.55 + (ic.moving ? 0.1 * Math.sin(ic.t * 1.3) : 0)
        }
    }
    Item {
        id: body
        visible: ic.big
        width: ic.width; height: ic.height
        y: ic.moving ? Math.sin(ic.t * 1.35) * 2.6 * ic.amp * ic.gain : 0                  // the whole icon floats
        Repeater {
            model: ic.big ? ic.layers : []
            delegate: TiltLayer {
                id: lay
                required property var modelData
                readonly property real ph: modelData.p * 1.9
                readonly property string m: ic.moving ? modelData.m : "none"
                readonly property real fall: (ic.t * 0.5 + modelData.p * 0.17) % 1
                base: ic.root + modelData.key + "/" + modelData.id; ext: ic.ext; px: ic.px
                yaw: ic.stx; pitch: ic.sty
                width: ic.width; height: ic.height
                x: m === "drift" ? Math.sin(ic.t * 0.8 + ph) * 2.4 * ic.amp * ic.gain : (m === "sway" ? Math.sin(ic.t * 1.1 + ph) * 1.8 * ic.amp * ic.gain : 0)
                y: m === "fall" ? lay.fall * 0.08 * ic.height * ic.gain : (m === "sway" ? Math.sin(ic.t * 0.7 + ph) * 1.5 * ic.amp * ic.gain : 0)
                scale: m === "breathe" ? 1 + 0.03 * ic.gain * Math.sin(ic.t * 1.3) : 1
                transformOrigin: Item.Center
                opacity: m === "fall" ? Math.pow(Math.sin(Math.PI * lay.fall), 0.5)
                       : (m === "twinkle" ? 0.65 + 0.35 * Math.sin(ic.t * 2.1 + ph * 2) : (m === "flicker" && ic.level >= 2 ? (((ic.t * 0.42 + ph) % 1) > 0.9 ? 0.5 : 1) : 1))
            }
        }
    }
    // light reflection: a soft white spot that follows the mouse, clipped to the shape of the icon
    ShaderEffectSource { id: bodySrc; sourceItem: body; live: ic.hovering && ic.big; hideSource: false; visible: false; width: ic.width; height: ic.height }
    Item {
        id: spotHolder
        width: ic.width; height: ic.height
        Image { source: ic.root + "spot." + ic.ext; width: ic.width * 0.9; height: width; cache: true; smooth: true
                x: (ic.width - width) / 2 + ic.stx * ic.width * 0.28; y: (ic.height - height) / 2 + ic.sty * ic.height * 0.28 }
    }
    ShaderEffectSource { id: spotSrc; sourceItem: spotHolder; hideSource: true; live: ic.hovering && ic.big; visible: false; width: ic.width; height: ic.height }
    MultiEffect {
        visible: ic.big && ic.hovering
        anchors.fill: parent
        source: spotSrc
        maskEnabled: true; maskSource: bodySrc
        opacity: 0.38 * Math.min(1, Math.abs(ic.stx) + Math.abs(ic.sty) + 0.25)
    }
}
