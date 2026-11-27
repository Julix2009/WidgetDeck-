// The icon of a desktop entry; without one in the icon theme, the first letter of the name.
import QtQuick
import Quickshell
import "../../core"

Item {
    id: ai
    property string icon: ""                      // the Icon= value of the desktop entry
    property string name: ""
    property color fg: "#f2f4f8"
    readonly property string url: icon === "" ? "" : (icon.charAt(0) === "/" ? "file://" + icon : Quickshell.iconPath(icon, true))
    Image {
        id: img
        anchors.fill: parent
        source: ai.url
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectFit
        asynchronous: true; smooth: true; mipmap: true
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        visible: img.status !== Image.Ready && img.status !== Image.Loading
        radius: width * 0.28
        color: Qt.rgba(ai.fg.r, ai.fg.g, ai.fg.b, 0.14)
        Text { anchors.centerIn: parent; color: ai.fg; font.family: Fonts.ui; font.bold: true; font.pixelSize: parent.height * 0.5; text: ai.name.charAt(0).toUpperCase() }
    }
}
