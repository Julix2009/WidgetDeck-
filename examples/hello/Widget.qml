// Example user widget. Copy this folder to ~/.config/widgetdeck/widgets/<name>/ and run `widgetdeck restart`.
//
// Contract - a root Item with these properties; the builder fills them in:
//   style        resolved style: fg, accent, font, font_size, mode ... (colours already follow the Matugen theme,
//                or the fixed colour the user picked in the builder - you never have to care which)
//   props        your own props from widget.json (colour props of kind "color" arrive resolved, too)
//   innerRadius  corner radius for rounded children (outer radius minus padding)
//   palette      every Material role as hex (primary, secondary, tertiary, surface_container, outline, ...)
//
// Do NOT name the root's properties like built-ins of the items you put inside (Text has its own `style`):
// give the root an id and read `w.style` / `w.palette`.
import QtQuick

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})

    Text {
        anchors.fill: parent
        text: w.props.text !== undefined ? w.props.text : ""
        color: w.style.accent || "#8ab4ff"                    // theme "primary" unless the user chose an own colour
        font.family: w.style.font || "sans"
        font.pixelSize: (w.style.font_size || 16) * (w.props.scale || 1.4)
        font.bold: true
        wrapMode: Text.WordWrap
        verticalAlignment: Text.AlignVCenter
        renderType: Text.QtRendering
    }
    Rectangle {                                               // palette example: a thin bar in the theme's tertiary colour
        anchors.bottom: parent.bottom
        width: parent.width * 0.3; height: 3; radius: 2
        color: w.palette.tertiary || "#e2bada"
        Behavior on color { ColorAnimation { duration: 600 } }
    }
}
