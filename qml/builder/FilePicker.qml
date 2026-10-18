// A small image file chooser (no portal, no external dialog): folders + thumbnails. Emits picked(path) or canceled().
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../core"

Rectangle {
    id: fp
    required property var th
    property string startPath: ""
    signal picked(string path)
    signal canceled()
    color: th.popup
    radius: 18
    border.width: 1; border.color: th.line

    readonly property string home: Quickshell.env("HOME")
    property string path: ""
    function open() { path = startPath !== "" ? startPath : (home + "/Pictures"); visible = true; }
    function up() { var i = path.lastIndexOf("/"); path = i > 0 ? path.substring(0, i) : "/"; }
    function norm(p) { return p.replace(/^file:\/\//, ""); }

    FolderListModel {
        id: fm
        folder: fp.path !== "" ? "file://" + encodeURI(fp.path).replace(/#/g, "%23") : "file:///nonexistent-widgetdeck"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif", "*.avif", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        showDirs: true; showDotAndDotDot: false; showHidden: false
        sortField: FolderListModel.Name
    }
    Column {
        anchors { fill: parent; margins: 16 }
        spacing: 10
        Row {
            width: parent.width; spacing: 8
            GButton { th: fp.th; label: "↑"; pad: 12; onClicked: fp.up() }
            GButton { th: fp.th; label: I18n.tr("Home"); onClicked: fp.path = fp.home }
            GButton { th: fp.th; label: I18n.tr("Pictures"); onClicked: fp.path = fp.home + "/Pictures" }
            Text { width: parent.width - 330; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideMiddle; text: fp.path; color: fp.th.dim; font.family: fp.th.font; font.pixelSize: 12 }
            GButton { th: fp.th; label: I18n.tr("Cancel"); onClicked: { fp.visible = false; fp.canceled(); } }
        }
        GridView {
            id: grid
            width: parent.width; height: parent.height - 48
            cellWidth: 150; cellHeight: 120; clip: true
            model: fm
            delegate: Item {
                width: grid.cellWidth; height: grid.cellHeight
                required property string fileName
                required property string filePath
                required property bool fileIsDir
                Rectangle {
                    anchors { fill: parent; margins: 4 }
                    radius: 12; color: ma.containsMouse ? fp.th.fieldHover : fp.th.field; clip: true
                    Image {
                        visible: !fileIsDir
                        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: lab.top }
                        source: fileIsDir ? "" : "file://" + encodeURI(filePath).replace(/#/g, "%23")
                        sourceSize: Qt.size(220, 140); asynchronous: true; fillMode: Image.PreserveAspectCrop
                    }
                    Icon { visible: fileIsDir; anchors.centerIn: parent; anchors.verticalCenterOffset: -8; width: 36; height: 36; name: "folder"; color: fp.th.dim }
                    Text { id: lab; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4 } height: 18; elide: Text.ElideMiddle; horizontalAlignment: Text.AlignHCenter
                           text: fileName; color: fp.th.fg; font.family: fp.th.font; font.pixelSize: 11 }
                    MouseArea {
                        id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (fileIsDir) fp.path = fp.norm(filePath); else { fp.visible = false; fp.picked(fp.norm(filePath)); } }
                    }
                }
            }
            Text { visible: grid.count === 0; anchors.centerIn: parent; text: I18n.tr("No images in this folder"); color: fp.th.dim; font.family: fp.th.font; font.pixelSize: 13 }
        }
    }
}
