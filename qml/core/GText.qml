// Text that follows the widget style; on liquid glass it gets a fine dark shadow so it stays legible.
import QtQuick

Text {
    property var wstyle: ({})
    color: wstyle.fg || "#f2f4f8"
    font.family: wstyle.font || "Adwaita Sans"
    font.pixelSize: wstyle.font_size || 16
    renderType: Text.QtRendering
    style: wstyle.mode === "liquid" ? Text.Raised : Text.Normal
    styleColor: "#73000000"
}
